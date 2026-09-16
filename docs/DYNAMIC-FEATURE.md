# Shipping Zoom as an on-demand module

> **Status: design, not yet implemented.** The library still ships as a single
> `android/` module and `ZoomModule` is not exported yet. This describes the
> split that is being built, and the reasoning behind each piece, so the shape
> can be reviewed before the restructure lands.


Zoom is roughly 140 MB of an Android build: ~124 MB of compressed native
libraries for one ABI, plus its dex and resources. That alone puts a React
Native app over Google Play's 200 MB per-device download limit, which is why
`armeabi-v7a` had to be dropped — and with it, half the supported devices.

Play Feature Delivery fixes the size problem properly: an **on-demand** module
does not count toward the initial download, so Zoom stops competing for the
200 MB budget and 32-bit support can come back.

Install-time modules *do* count toward the limit, so `dist:on-demand` is not
optional here.

## Why the usual attempt fails with "resource not found"

Zoom ships an official sample (`feature_mobilertc` + `dynamic_sample` in the SDK
zip). Comparing it against a typical first attempt, four things are usually
missing:

1. **`android.nonTransitiveRClass=false` and `android.nonFinalResIds=false`.**
   Zoom's own `gradle.properties` sets both. AGP 8 defaults `nonTransitiveRClass`
   to `true`, which gives each library an R class holding only its own
   resources — and `mobilertc.aar` resolves resources through its own R. This is
   the single most common cause of the resource errors.
2. **`SplitCompat`.** The `Application` needs `SplitCompat.install(this)` in
   `attachBaseContext`, and every `Activity` that touches the module's resources
   needs `SplitCompat.installActivity(this)`. Zoom's meeting activities live
   inside the AAR and cannot be patched, so this can never be made complete.
3. **A process restart.** Point 2 stops mattering entirely once the process
   restarts: the split is then in `ApplicationInfo.splitSourceDirs` and the
   framework loads its classes, resources and `.so` files natively. This is the
   reliable path, and the one used here.
4. **Native library preloading.** Without a restart, `System.loadLibrary` cannot
   find the module's `.so` files, which is why Zoom's sample preloads ~76
   libraries through ReLinker in a specific order. With a restart, that is
   unnecessary.

## The React Native problem

Autolinking compiles the Zoom bridge into the app module, and that bridge
references `us.zoom.sdk.*`. If Zoom lives in the feature module, the base app no
longer compiles.

So the library is split in two:

| | |
| --- | --- |
| `android/` | **Loader.** Autolinked into the app. Contains no Zoom references: it only asks `SplitInstallManager` whether the module is present, downloads it, reports progress, and restarts the process. |
| `android-impl/` | **Implementation.** The actual bridge — `RNZoomUsModule`, `RNZoomUsVideoView`, `RNZoomUsVideoViewManager`, `RNZoomUsPackage` — plus the Zoom AAR. Consumed by the app's feature module, never by the app. |

The base app adds the real `ReactPackage` reflectively, so it never needs the
class at compile time:

```kotlin
override fun getPackages(): List<ReactPackage> =
    PackageList(this).packages.apply {
        if (SplitInstallManagerFactory.create(this@MainApplication)
                .installedModules.contains("zoom")) {
            add(Class.forName("ch.milosz.reactnative.RNZoomUsPackage")
                    .getDeclaredConstructor().newInstance() as ReactPackage)
        }
    }
```

Because the process restarts after installing, by the time `getPackages()` runs
the class is genuinely loadable.

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
