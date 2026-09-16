# Shipping Zoom as an on-demand module

> **Status: work in progress.** The `android/` loader / `android-impl/` split
> and `ZoomModule` exist, and the app's debug bundle builds with Zoom entirely
> in the on-demand `zoom` module (base per-device download 126.6–126.9 MB,
> debug, unminified). Not done yet: gating the join flow on `ZoomModule`,
> on-device install testing, a release-build size check, and bringing
> `armeabi-v7a` back.


Zoom is roughly 140 MB of an Android build: ~124 MB of compressed native
libraries for one ABI, plus its dex and resources. That alone puts a React
Native app over Google Play's 200 MB per-device download limit, which is why
`armeabi-v7a` had to be dropped — and with it, half the supported devices.

Play Feature Delivery fixes the size problem properly: an **on-demand** module
does not count toward the initial download, so Zoom stops competing for the
200 MB budget and 32-bit support can come back.

Install-time modules *do* count toward the limit, so `dist:on-demand` is not
optional here.

## Why "resource not found"

There are two separate causes, and the first is the one that actually shows up
at build time.

**1. Manifest-referenced resources must live in the base.** An app bundle merges
every feature module's manifest into the base manifest, and `:app` links that
merged manifest against the *base* resource table. So any resource the Zoom
AAR's manifest points at has to exist in the base module, even though the AAR
itself is in the feature:

```
AAPT: error: resource drawable/zm_launcher not found.
  task :app:processProductDebugResources
```

It is a short list, not Zoom's whole resource tree. On 7.1.6 the merged feature
manifest references exactly four:

| Resource | Used by | Handling |
| --- | --- | --- |
| `@string/module_zoom` | `dist:title` | base `strings.xml` |
| `@xml/file_provider_paths` | Zoom's `FileProvider` | copied to base `res/xml` |
| `@xml/msdk_network_security_config` | `<application networkSecurityConfig>` | copied to base `res/xml` |
| `@drawable/zm_launcher` | icon of a signature IPC permission | `tools:remove="android:icon"` |

`zm_launcher` is removed rather than copied because it is an adaptive icon that
would pull its foreground and background layers along, for a permission icon
nothing displays. The network security config applies app-wide, but so it did
before: with Zoom in the base, the AAR's manifest was already setting it.

The previous attempt (removed in `0d6b484a`) reacted to this by moving Zoom's
resources into the base (`mobilertc_nres.aar`, `zoomRes`). Only these four are
needed; recheck the list on every SDK upgrade with:

```
grep -oE '@(drawable|mipmap|style|string|xml|color)/[A-Za-z0-9_.]+' \
  android/zoom/build/intermediates/metadata_feature_manifest/*/*/AndroidManifest.xml
```

**2. `android.nonTransitiveRClass=false` and `android.nonFinalResIds=false`.**
Zoom's own `gradle.properties` sets both. AGP 8 defaults `nonTransitiveRClass`
to `true`, giving each library an R class with only its own resources, while
`mobilertc.aar` resolves resources through its own R. This one fails at runtime
rather than build time.

## Why the app restarts after installing

Zoom's official sample does **not** restart: it calls
`SplitCompat.installActivity` in its own activity and preloads ~76 native
libraries through ReLinker, then launches the meeting.

React Native needs the restart for a different reason. `getPackages()` runs once
when the React instance is created, so a module installed mid-session is never
registered and `NativeModules.RNZoomUs` stays undefined until the app starts
again. A full process restart also puts the split into
`ApplicationInfo.splitSourceDirs`, which makes the SplitCompat and ReLinker
steps unnecessary.

## The React Native problem

Autolinking compiles the Zoom bridge into the app module, and that bridge
references `us.zoom.sdk.*`. If Zoom lives in the feature module, the base app no
longer compiles.

So the library is split in two:

| | |
| --- | --- |
| `android/` | **Loader.** Autolinked into the app. Contains no Zoom references: it only asks `SplitInstallManager` whether the module is present, downloads it, reports progress, and restarts the process. |
| `android-impl/` | **Implementation.** The actual bridge — `RNZoomUsModule`, `RNZoomUsVideoView`, `RNZoomUsVideoViewManager`, `RNZoomUsPackage` — plus the Zoom AAR. Consumed by the app's feature module, never by the app. |

The loader's `RNZoomUsLoaderPackage` adds the real `ReactPackage` reflectively,
so nothing in the base needs the class at compile time and `MainApplication`
needs no change for it. When `SplitInstallManager` reports `zoom` as installed,
it instantiates `ch.milosz.reactnative.RNZoomUsPackage` and adds its native
modules and view managers next to its own.

Because the process restarts after installing, by the time `getPackages()` runs
the class is genuinely loadable.

Autolinking caches its result. After switching an existing checkout to this
layout, delete `android/build/generated/autolinking` and
`android/app/build/generated/autolinking`, or `PackageList.java` keeps importing
the old `ch.milosz.reactnative` package and the build fails.

## App wiring

`android/settings.gradle`

```gradle
include ':zoom'
include ':react-native-zoom-us-impl'
project(':react-native-zoom-us-impl').projectDir =
    file('../node_modules/@vuduc4793/react-native-zoom-us/android-impl')
```

`android/zoom/build.gradle`

```gradle
apply plugin: 'com.android.dynamic-feature'
android {
    namespace 'com.minhtrithanh.zoom'
    compileSdk rootProject.ext.compileSdkVersion
    defaultConfig { minSdk 28 }   // mobilertc.aar 7.1.x requires 28
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    // The feature must declare the same productFlavors as :app.
    packaging {
        // The only .so both modules ship. Same NDK build, different stripping,
        // so bundletool rejects the bundle ("with different content").
        jniLibs { excludes += ['lib/**/libc++_shared.so'] }
    }
}
dependencies {
    implementation project(':app')
    api project(':react-native-zoom-us-impl')
}
```

`android/zoom/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
          xmlns:dist="http://schemas.android.com/apk/distribution">
    <dist:module dist:title="@string/module_zoom">
        <dist:delivery><dist:on-demand/></dist:delivery>
        <dist:fusing dist:include="false" />
    </dist:module>
</manifest>
```

`android/app/build.gradle`

```gradle
android {
    defaultConfig {
        ndk { abiFilters "arm64-v8a", "armeabi-v7a" }   // 32-bit comes back
    }
    dynamicFeatures = [':zoom']
}
dependencies {
    implementation 'com.google.android.play:feature-delivery:2.1.0'
}
// Same versions as the feature for everything Zoom pulls in. Without it the
// base resolves older lifecycle / compose / kotlin artifacts than the feature
// and bundletool fails with "Modules 'base' and 'zoom' contain entry ... with
// different content".
apply from: "../../node_modules/@vuduc4793/react-native-zoom-us/android-impl/zoom-deps.gradle"
```

`android/gradle.properties`

```properties
reactNativeArchitectures=armeabi-v7a,arm64-v8a
# Required by mobilertc.aar; AGP 8 defaults the first to true.
android.nonTransitiveRClass=false
android.nonFinalResIds=false
```

`MainApplication.kt` also needs

```kotlin
override fun attachBaseContext(base: Context) {
    super.attachBaseContext(base)
    SplitCompat.install(this)
}
```

## Using it from JavaScript

```tsx
import { ZoomModule } from '@vuduc4793/react-native-zoom-us'

if (!(await ZoomModule.isInstalled())) {
  await ZoomModule.install({ onProgress: (p) => setProgress(p) })
  // The process restarts here; the app relaunches with Zoom available.
}
```

On iOS `isInstalled()` always resolves true and `install()` is a no-op, so the
same code path works on both platforms.

Because installing ends in a process restart, the screen that needed Zoom has to
be reachable again after relaunch — deep link back into it, or persist enough
state to restore it.

## Size

Moving Zoom out of the base leaves roughly 110–130 MB for the base download,
against a 200 MB limit, with both ABIs shipping again.

A second, independent win is available on the app side: `res/drawable-mdpi-v4`
is ~28 MB of the current build, and it is the app's own PNG/JPG artwork, not
Zoom's. Converting it to WebP is worth another ~15–20 MB.

## This changes how you install builds

Today the app is installed by pushing an APK directly. That stops working for
the Zoom module: a sideloaded APK has no Play session behind it, so
`SplitInstallManager` has nothing to download from, and `assembleDebug` does not
put the feature module in the APK either.

Three ways to test, in increasing order of realism:

1. **bundletool with local testing** — builds every split and sideloads them
   together, so `startInstall` resolves against the local set instead of Play:

   ```
   ./gradlew :app:bundleProductDebug
   bundletool build-apks --local-testing \
       --bundle=app/build/outputs/bundle/productDebug/app-product-debug.aab \
       --output=/tmp/app.apks
   bundletool install-apks --apks=/tmp/app.apks
   ```

2. **Android Studio** — a normal Run does the same thing for you.

3. **Play internal testing track** — the only one that exercises the real
   download, including the confirmation dialog for large modules over mobile
   data.

Plain `./gradlew installProductDebug` no longer gives a working Zoom path, which
is worth knowing before wiring this into CI.
