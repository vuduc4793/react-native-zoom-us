# ZoomVideoView (v2)

`<ZoomUsVideoView>` is still exported and unchanged. `<ZoomVideoView>` is the
replacement; the two can coexist while you migrate screen by screen.

## Why v2 exists

Three things made v1 awkward:

1. **It had to sit at the top of the view tree.** On Android the native view is a
   `RelativeLayout` that Zoom fills with its own surfaces at runtime, and React
   Native never measured those children — so nested anywhere, it rendered blank.
   On iOS the meeting view controller was added as a subview but never as a
   *child view controller*, so it got no lifecycle, rotation or safe-area
   callbacks and only looked right when it happened to be full screen. Both are
   fixed, so v2 can be nested like any other view.
2. **Layout was a hand-computed array.** Callers wrote `layout={[{kind:'active',
   x:0, y:0, width: responsiveW(1), height: responsiveH(1)}]}` and the library
   multiplied by 100. Zoom positions video units in percentages, but you should
   not have to think in percentages.
3. **Event props only fired on iOS.** The Android view manager declared no
   events at all, so `onSinkMeetingUserJoin` and friends silently did nothing
   there and Android code had to subscribe to `ZoomEmitter` instead.

## Layout

Each video unit is its own component, positioned with ordinary React Native
layout. The component measures itself and the library converts the measured
frame into the percentages Zoom wants.

```tsx
import { ZoomVideoView } from '@vuduc4793/react-native-zoom-us'

<ZoomVideoView style={{ flex: 1 }}>
  <ZoomVideoView.ActiveSpeaker style={{ flex: 1 }} />
  <ZoomVideoView.Preview
    style={{ position: 'absolute', right: 16, bottom: 16, width: 110, height: 160 }}
  />
</ZoomVideoView>
```

Flexbox, absolute positioning, safe-area insets and orientation changes all work
normally, including for slots nested inside other views.

Available slots:

| Slot | Renders |
| --- | --- |
| `ZoomVideoView.ActiveSpeaker` | whoever Zoom considers the active speaker |
| `ZoomVideoView.Preview` | the local camera preview |
| `ZoomVideoView.Attendee` | one participant's camera — pass `userId` |
| `ZoomVideoView.Share` | one participant's screen share — pass `userId` |
| `ZoomVideoView.ActiveShare` | whoever is currently sharing |

Slot props: `border`, `showUsername`, `showAudioOff`, `aspectMode`,
`background`, `userId`.

Prefer `userId` over the old `userIndex`. An index points into the participant
list, which shifts as people join and leave, so a pinned tile quietly starts
showing somebody else. `userIndex` still works when no `userId` is given.

Anything you nest inside a slot is drawn on top of that video unit, which is the
easy way to add a name badge or a mute indicator.

## Compositing (Android)

`zOrder` controls how the video surface is composited:

- `"mediaOverlay"` (default) — above the window, below sibling React Native
  views, so your controls are visible on top of the video.
- `"onTop"` — above everything, including your controls.
- `"behind"` — the platform default, usually invisible.

## Events

Every SDK callback is forwarded on one channel on both platforms, including the
ones nothing consumes yet, so wiring up a new feature never means rebuilding the
native library. `src/events/generated.ts` is generated from the native emitters
by `scripts/generate-events.py`, so the payload types cannot drift.

```tsx
import { useZoomEvent, useZoomParticipantCount } from '@vuduc4793/react-native-zoom-us'

useZoomEvent('onUserNetworkStatusChanged', ({ quality, userId, isMyself }) => {
  // quality and userId are typed
})

const count = useZoomParticipantCount()
```

Also available: `useZoomAnyEvent`, `useZoomParticipants`, and the imperative
`addZoomListener` / `addZoomAnyListener`.

The older `MeetingEvent` / `MeetingStatus` / `AuthEvent` channels and
`ZoomUs.onMeetingStatusChange(...)` still work exactly as before; the unified
channel is an addition, not a replacement.

## Migrating

```diff
-<ZoomUsVideoView
-  style={layout.flex_1}
-  layout={[{ kind: 'active', x: 0, y: 0, width: responsiveW(1), height: responsiveH(1),
-             showUsername: false, showAudioOff: false }]}
-  onSinkMeetingUserJoin={p => increase(p.userList)}
-/>
+<ZoomVideoView style={layout.flex_1}>
+  <ZoomVideoView.ActiveSpeaker style={layout.flex_1} showUsername={false} showAudioOff={false} />
+</ZoomVideoView>
```

with the join handler moving to `useZoomEvent('userJoin', ...)`, which now
behaves the same on Android and iOS.
