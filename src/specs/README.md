# Codegen specs

These describe the native surface for React Native's codegen. They are validated
(`generate-codegen-artifacts.js` produces artifacts for both platforms from
them, and the Java module compiles against the generated `NativeZoomUsSpec`),
but codegen is **not enabled yet**: `codegenConfig` is deliberately absent from
package.json.

Turning it on requires more than adding that block back:

- `android/build.gradle` must `apply plugin: 'com.facebook.react'` so codegen
  runs for this library, otherwise autolinking points the app at a
  `CMakeLists.txt` that is never generated and the build fails.
- Old-architecture consumers have no generated spec to extend, so the module
  needs the usual `src/newarch` + `src/oldarch` source-set split.
- The Fabric component additionally needs an `RCTViewComponentView` subclass on
  iOS; the JS side still uses `requireNativeComponent`, which goes through the
  interop layer.

Until then the specs serve as the checked-in, machine-verified description of
the native API.
