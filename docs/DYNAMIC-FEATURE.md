# Shipping Zoom as an on-demand module

> **Status: builds and measures as intended; not yet installed from Play.**
> The `android/` loader / `android-impl/` split, `ZoomModule`, the join-flow
> gate and both ABIs are in place, and a **release** bundle builds with Zoom
> entirely in the on-demand `zoom` module. Measured below. What is left is the
> one thing no local build can stand in for: installing from a Play track and
> watching the module actually download, including Play's own confirmation
> dialog on a metered connection.


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

There are three separate causes, and the first is the one that actually shows up
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

**3. A resource name the base already owns.** Resource names are global across
the base and its features. When something in the base defines the same name,
AAPT2 links the feature's copies against the base's id and leaves them out of
the *feature's* resource table — but still packages the files. bundletool then
rejects the bundle, in the very last task of a long build:

```
> Task :app:packageProductReleaseBundle FAILED
Module 'zoom' contains resource files that are not referenced from the resource
table: [res/drawable-anydpi-v24/ic_user.xml, res/drawable-xxhdpi-v4/ic_user.png]
```

Here `drawable/ic_user` is defined by **both** `mobilertc.aar` (anydpi-v24,
xxhdpi) and `sdk-auth`, the Zalo SDK that `react-native-zalo-kit` pulls into the
base (ldpi–xhdpi). The collision predates this work: in the single-APK build the
two merged into one resource, where `anydpi-v24` won on every device at this
minSdk — so Zalo's screens were already showing Zoom's icon.

`android/zoom/build.gradle` drops the orphaned files from the module zip after
`buildPreBundle`, listing the names in `ext.resourcesOwnedByBase`. Nothing
changes at runtime: Zoom's screens resolve the same name, now always to the
base's copy.

Do not rerun the full build to test a fix for this — it fails at the last task
after everything else has been done. The module zips Gradle already produced are
enough to reproduce and verify it in seconds:

```
bundletool build-bundle --output=/tmp/t.aab --modules=\
  app/build/intermediates/module_bundle/*/*/base.zip,\
  zoom/build/intermediates/module_bundle/*/*/zoom.zip
```

Find who contributes a colliding name with AGP's own blame file:

```
grep -o '[^"]*<name>[^"]*' \
  android/app/build/intermediates/incremental/*/mergeProductReleaseResources/merger.xml
```

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

Measured on `:app:bundleProductRelease` (minified, both ABIs), with
`bundletool get-size total --dimensions=ABI`. The per-device column counts only
the modules downloaded on first install, which is what Play's 200 MB limit
applies to; the on-demand `zoom` module is excluded by definition.

| | per-device download | if Zoom were install-time |
| --- | --- | --- |
| `arm64-v8a` | **94.4–94.6 MB** | 230.3–231.4 MB |
| `armeabi-v7a` | **89.1–89.3 MB** | 210.4–211.5 MB |

The right-hand column is the honest statement of the problem: both ABIs are over
the limit as a single download, and 230.3 MB matches the 241.5 MB release
baseline this started from. On demand, the base has ~105 MB of headroom and
32-bit ships again.

Checks worth repeating after an SDK upgrade, all against the `.aab`:

- Zoom's native libraries are in the feature, not the base. Here: 37 `.so` per
  ABI in `base/`, 83 (arm64) / 82 (v7a) in `zoom/`. That is exactly what
  `mobilertc.aar` carries (84 / 83) minus the `libc++_shared.so` the feature
  drops. `libdvf.so` is arm64-only **in Zoom's own AAR** — not something the
  split lost.
- No Zoom classes leak into the base: `strings base/dex/*.dex | grep -c '^Lus/zoom/'`
  must be 0.

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
