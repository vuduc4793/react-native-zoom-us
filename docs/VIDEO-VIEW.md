# Video Component for custom UI on react native MainActivity

*Currently only support for Android!*

*If use it with animate will blank view!*

1. Initialize with `enableCustomizedMeetingUI: true`
2. Use `ZoomUsVideoView` on anywhere
3. Define what video layout you want

## Example

```js
import React from 'react'
import { StyleSheet } from 'react-native'
import { ZoomUsVideoView } from 'react-native-zoom-us'

const App = (props) => {
  return (
    <>
      <ZoomUsVideoView
        style={StyleSheet.absoluteFillObject}
        layout={[
          // The active speaker
          { kind: 'active', x: 0, y: 0, width: 1, height: 1 },
          // Selfcamera preview
          {
            kind: 'preview',
            // The percent of video view (required)
            x: 0.73, y: 0.73, width: 0.25, height: 0.20,
            // Enable border (optional)
            border: true,
            // Disable show user name (optional)
            showUsername: false,
            // Show audio off (optional)
            showAudioOff: true,
            // Background color (optional)
            background: '#ccc'
          },
          // active speaker's share
          {
            kind: 'active-share',
            ...,
          },
          // share video
          {
            kind: 'share',
            ...,
            // The index of user list (required)
            userIndex: 0,
          },
          // Specify attendee
          {
            kind: 'attendee',
            ...,
            // The index of user list (required)
            userIndex: 0,
          },
          {
            kind: 'attendee',
            ...,
            userIndex: 1,
          },
        ]}
        />
    </>
  )
}
```

*(`share` or `active-share`) and `preview` limited once on the screen by Zoom SDK*
