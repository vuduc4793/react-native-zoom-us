import * as React from "react";
import {
  LayoutChangeEvent,
  StyleProp,
  StyleSheet,
  View,
  ViewStyle,
} from "react-native";
import Color from "color";
import { RNZoomUs, RNZoomUsVideoView, VideoAspectMode } from "../../native";

type UnitKind = "active" | "preview" | "share" | "attendee" | "active-share";

interface Frame {
  x: number;
  y: number;
  width: number;
  height: number;
}

interface SlotOptions {
  border?: boolean;
  showUsername?: boolean;
  showAudioOff?: boolean;
  aspectMode?: VideoAspectMode;
  background?: string;
  /** Zoom user id. Preferred over userIndex, which depends on list ordering. */
  userId?: number;
  userIndex?: number;
}

interface Registration extends SlotOptions {
  kind: UnitKind;
  frame: Frame | null;
}

interface ContextValue {
  register(id: string, registration: Registration): void;
  unregister(id: string): void;
  containerRef: React.RefObject<View | null>;
}

const ZoomVideoViewContext = React.createContext<ContextValue | null>(null);

export interface ZoomVideoViewProps {
  style?: StyleProp<ViewStyle>;
  /**
   * How the video surface is composited on Android.
   * - "mediaOverlay" (default): above the window, below sibling React Native
   *   views, so controls drawn on top of this component are visible.
   * - "onTop": above everything, including your own controls.
   * - "behind": platform default; usually invisible once anything paints a
   *   background above it.
   */
  zOrder?: "mediaOverlay" | "onTop" | "behind";
  children?: React.ReactNode;
}

/**
 * Hosts Zoom's video surface and positions video units from ordinary React
 * Native layout.
 *
 * Zoom places video units using percentages of the surface. Rather than making
 * callers compute those percentages by hand, each child slot measures itself
 * with onLayout and this component converts the measured frames. That means
 * flexbox, absolute positioning and safe-area insets all work normally:
 *
 *   <ZoomVideoView style={{ flex: 1 }}>
 *     <ZoomVideoView.ActiveSpeaker style={{ flex: 1 }} />
 *     <ZoomVideoView.Preview
 *       style={{ position: "absolute", right: 16, bottom: 16, width: 110, height: 160 }}
 *     />
 *   </ZoomVideoView>
 */
function ZoomVideoViewRoot({ style, zOrder = "mediaOverlay", children }: ZoomVideoViewProps) {
  const containerRef = React.useRef<View | null>(null);
  const nativeRef = React.useRef<any>(null);
  const registrations = React.useRef(new Map<string, Registration>());
  const [size, setSize] = React.useState<{ width: number; height: number } | null>(null);
  const [revision, setRevision] = React.useState(0);

  const bump = React.useCallback(() => setRevision((r) => r + 1), []);

  const context = React.useMemo<ContextValue>(
    () => ({
      containerRef,
      register(id, registration) {
        registrations.current.set(id, registration);
        bump();
      },
      unregister(id) {
        registrations.current.delete(id);
        bump();
      },
    }),
    [bump]
  );

  const onLayout = React.useCallback((event: LayoutChangeEvent) => {
    const { width, height } = event.nativeEvent.layout;
    setSize((previous) =>
      previous && previous.width === width && previous.height === height
        ? previous
        : { width, height }
    );
  }, []);

  const layout = React.useMemo(() => {
    if (!size || size.width <= 0 || size.height <= 0) return [];

    const toPercent = (value: number, total: number) =>
      Math.max(0, Math.min(100, Math.round((value / total) * 100)));

    const units: Record<string, unknown>[] = [];
    registrations.current.forEach((registration) => {
      const { frame, kind, background, ...rest } = registration;
      if (!frame) return;
      units.push({
        ...rest,
        kind,
        x: toPercent(frame.x, size.width),
        y: toPercent(frame.y, size.height),
        width: toPercent(frame.width, size.width),
        height: toPercent(frame.height, size.height),
        background: Color(background || "#000000").rgbNumber(),
      });
    });
    return units;
    // revision changes whenever a slot registers, moves or unmounts.
  }, [size, revision]);

  React.useEffect(() => {
    if (!RNZoomUs || !nativeRef.current) return;

    // Android keeps a registry of live video views in the native module so it
    // can refresh them when the participant list changes. iOS tracks its views
    // inside RNZoomUsVideoView itself and exports no such methods -- and calling
    // one that does not exist throws synchronously, before there is a promise
    // for .catch() to attach to, which took the whole component down on iOS.
    if (typeof RNZoomUs.addVideoView !== "function") return;

    // Resolve the handle once: by cleanup time the ref may already be cleared,
    // and removeVideoView needs the same tag that was registered.
    const handle = findNodeHandleSafe(nativeRef.current);
    if (handle == null) return;

    void RNZoomUs.addVideoView(handle).catch(() => {
      // The view can be torn down before the call lands; nothing to recover.
    });

    return () => {
      if (typeof RNZoomUs.removeVideoView !== "function") return;
      void RNZoomUs.removeVideoView(handle).catch(() => {
        // ignored, see above
      });
    };
  }, []);

  return (
    <View ref={containerRef} style={style} onLayout={onLayout} collapsable={false}>
      {RNZoomUsVideoView ? (
        <RNZoomUsVideoView
          ref={nativeRef}
          style={StyleSheet.absoluteFill}
          layout={layout as any}
          zOrder={zOrder}
        />
      ) : null}
      <View style={StyleSheet.absoluteFill} pointerEvents="box-none">
        <ZoomVideoViewContext.Provider value={context}>
          {children}
        </ZoomVideoViewContext.Provider>
      </View>
    </View>
  );
}

function findNodeHandleSafe(ref: unknown): number | null {
  // Imported lazily so this module can be used in tests without the RN
  // renderer being initialised.
  const { findNodeHandle } = require("react-native");
  return findNodeHandle(ref as never);
}

let nextSlotId = 0;

interface SlotProps extends SlotOptions {
  style?: StyleProp<ViewStyle>;
  /** Rendered on top of this video unit, e.g. a name badge. */
  children?: React.ReactNode;
}

function createSlot(kind: UnitKind, displayName: string) {
  function Slot({ style, children, ...options }: SlotProps) {
    const context = React.useContext(ZoomVideoViewContext);
    const id = React.useMemo(() => `${kind}-${nextSlotId++}`, []);
    const viewRef = React.useRef<View | null>(null);
    const frame = React.useRef<Frame | null>(null);

    // Re-register whenever an option changes so the native side picks it up.
    const optionsKey = JSON.stringify(options);

    const publish = React.useCallback(() => {
      if (!context) return;
      context.register(id, { kind, frame: frame.current, ...options });
      // optionsKey stands in for the option values; `options` is a fresh object
      // on every render and would defeat memoisation.
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [context, id, optionsKey]);

    const onLayout = React.useCallback(
      (event: LayoutChangeEvent) => {
        const fallback = event.nativeEvent.layout;
        const container = context?.containerRef.current;
        const self = viewRef.current as any;

        // onLayout reports coordinates relative to the immediate parent, which
        // is only the container when the slot is a direct child. Measuring
        // against the container keeps nested slots correct.
        if (container && self && typeof self.measureLayout === "function") {
          self.measureLayout(
            container,
            (x: number, y: number, width: number, height: number) => {
              frame.current = { x, y, width, height };
              publish();
            },
            () => {
              frame.current = fallback;
              publish();
            }
          );
        } else {
          frame.current = fallback;
          publish();
        }
      },
      [context, publish]
    );

    React.useEffect(() => {
      publish();
    }, [publish]);

    React.useEffect(() => {
      return () => context?.unregister(id);
    }, [context, id]);

    if (!context) {
      throw new Error(
        `<ZoomVideoView.${displayName}> must be rendered inside <ZoomVideoView>.`
      );
    }

    return (
      <View ref={viewRef} style={style} onLayout={onLayout} collapsable={false} pointerEvents="box-none">
        {children}
      </View>
    );
  }

  Slot.displayName = `ZoomVideoView.${displayName}`;
  return Slot;
}

export const ZoomVideoView = Object.assign(ZoomVideoViewRoot, {
  /** The participant Zoom currently considers the active speaker. */
  ActiveSpeaker: createSlot("active", "ActiveSpeaker"),
  /** The local camera preview. */
  Preview: createSlot("preview", "Preview"),
  /** Screen share from a specific participant (pass userId). */
  Share: createSlot("share", "Share"),
  /** Screen share from whoever is currently sharing. */
  ActiveShare: createSlot("active-share", "ActiveShare"),
  /** A specific participant's camera (pass userId). */
  Attendee: createSlot("attendee", "Attendee"),
});

export default ZoomVideoView;
