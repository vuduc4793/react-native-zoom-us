import type { ViewProps } from "react-native";
import type { HostComponent } from "react-native";
import type { Int32, WithDefault } from "react-native/Libraries/Types/CodegenTypes";
import codegenNativeComponent from "react-native/Libraries/Utilities/codegenNativeComponent";

/**
 * One video unit inside the Zoom surface.
 *
 * Coordinates are percentages of the surface (0-100), which is what Zoom's
 * MobileRTCVideoUnitRenderInfo takes. Callers do not compute these by hand:
 * <ZoomVideoView> measures its slot components and fills this in.
 */
export type ZoomLayoutUnit = Readonly<{
  /** "active" | "preview" | "share" | "attendee" | "active-share" */
  kind: string;
  x: Int32;
  y: Int32;
  width: Int32;
  height: Int32;
  border?: WithDefault<boolean, false>;
  showUsername?: WithDefault<boolean, true>;
  showAudioOff?: WithDefault<boolean, true>;
  aspectMode?: WithDefault<Int32, 0>;
  /** Packed RGB, as produced by the `color` package's rgbNumber(). */
  background?: WithDefault<Int32, 0>;
  /** Zoom user id. Takes precedence over userIndex. */
  userId?: WithDefault<Int32, -1>;
  userIndex?: WithDefault<Int32, 0>;
}>;

export interface NativeProps extends ViewProps {
  layout?: ReadonlyArray<ZoomLayoutUnit>;
  /**
   * Android only. How the GLSurfaceView is composited:
   * "mediaOverlay" (default) | "onTop" | "behind".
   */
  zOrder?: WithDefault<string, "mediaOverlay">;
}

export default codegenNativeComponent<NativeProps>("RNZoomUsVideoView", {
  // The view config comes from the existing RNZoomUsVideoViewManager rather
  // than being generated here. Without this, autolinking advertises an
  // RNZoomUsVideoViewComponentDescriptor that no native code provides.
  // Drop it once the manager implements the generated Fabric interface and the
  // iOS RCTViewComponentView exists -- see src/specs/README.md.
  interfaceOnly: true,
}) as HostComponent<NativeProps>;
