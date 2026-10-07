require "json"
package = JSON.parse(File.read(File.join(__dir__, "package.json")))

# Zoom Meeting SDK for iOS.
#
# RNZoomSDK -- github.com/vuduc4793/zoom-sdk-pods -- rather than Zoom's own
# ZoomMeetingSDK pod, which exists and carries the identical xcframeworks. The
# mirror is kept for one reason: a CocoaPods version takes three components, so
# Zoom's own pod publishes "7.2.1" with the build dropped and a rebuilt 7.2.1
# would reinstall under the same name. The mirror can also be cut the day a
# build lands rather than when Zoom gets around to publishing.
#
# The four-part number is Zoom's own, not this project's invention: version.txt
# inside their download reads v7.2.1.39202. And the mirror does not repackage --
# its release asset is byte-identical to the file Zoom serves:
#   sha256 13db4daae13d35fee40d128a6b3530a080e0f130b87c48ea047822af09057f0b
#
# Matched to Android's 7.2.1.43944 (its version.txt: v7.2.1.43944). Zoom numbers
# builds separately per platform, so the build suffixes differ while the SDK
# version does not.
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

  # Zoom's own podspec declares 13.0, but the binary they ship disagrees:
  # MobileRTC.framework's Info.plist in 7.2.1.39202 carries MinimumOSVersion
  # 15.0. So 15.0 here is the measured floor, not a conservative guess -- and
  # React Native 0.81 requires 15.1 anyway, so nothing can consume lower.
  s.platform     = :ios, "15.0"

  s.source       = { :git => "https://github.com/vuduc4793/react-native-zoom-us" }
  s.source_files = "ios/*.{h,m}"
  s.requires_arc = true

  s.static_framework = true
  s.dependency "React-Core"
  s.dependency "RNZoomSDK", ZOOM_SDK_VERSION

  # All three xcframeworks -- MobileRTC, MobileRTCScreenShare, zoomcml -- ship
  # ios-arm64 and ios-arm64-simulator only, with no x86_64 simulator slice
  # (checked in 7.2.1.39202), so this pod and the consuming app have to agree to
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
