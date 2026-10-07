require "json"
package = JSON.parse(File.read(File.join(__dir__, "package.json")))

# Zoom Meeting SDK for iOS.
#
# RNZoomSDK -- github.com/vuduc4793/zoom-sdk-pods -- rather than Zoom's own
# ZoomMeetingSDK pod, which exists and carries the identical xcframeworks. The
# mirror is kept for one reason: Zoom versions their pod in three parts, so a
# rebuilt 7.2.1 would reinstall under the same name, while this one pins the
# build (39202) in the version itself and can be cut the day a build lands
# rather than when Zoom gets around to publishing.
#
# Matched to Android's 7.2.1.43944. Zoom numbers builds separately per platform,
# so the build suffixes differ while the SDK version does not.
ZOOM_SDK_VERSION = "7.2.1.39202"

Pod::Spec.new do |s|
  s.name         = "RNZoomUs"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.description  = <<-DESC
                  React Native integration for Zoom SDK
                   DESC
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.author       = { "author" => "author@domain.cn" }

  # Zoom's own podspec declares 13.0. Kept at 15.0 here: React Native 0.81
  # already requires 15.1, so nothing can consume a lower target anyway, and
  # lowering it would be an untested claim rather than a tested one.
  s.platform     = :ios, "15.0"

  s.source       = { :git => "https://github.com/vuduc4793/react-native-zoom-us" }
  s.source_files = "ios/*.{h,m}"
  s.requires_arc = true

  s.static_framework = true
  s.dependency "React-Core"
  s.dependency "RNZoomSDK", ZOOM_SDK_VERSION

  # MobileRTC.xcframework ships ios-arm64 and ios-arm64-simulator only -- no
  # x86_64 simulator slice -- so this pod and the consuming app have to agree to
  # drop it, or the link step fails with "building for iOS Simulator, but
  # linking ... built for iOS". This also means an Intel Mac cannot run the
  # simulator build.
  s.pod_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'x86_64 i386'
  }
  s.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'x86_64 i386'
  }
end
