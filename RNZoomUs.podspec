require "json"
package = JSON.parse(File.read(File.join(__dir__, "package.json")))

# Zoom Meeting SDK for iOS.
#
# Zoom publishes this pod themselves -- ZoomMeetingSDK, owned by zoom.us, built
# from github.com/zoom/meetingsdk-ios releases -- so there is nothing to mirror.
# It carries the same MobileRTC, zoomcml and MobileRTCScreenShare xcframeworks
# the hand-built RNZoomSDK pod repackaged.
#
# 7.1.5 rather than the newer 7.2.1: it is the closest the iOS line comes to
# Android's 7.1.6.41900, and the two platforms are kept on the same minor
# version. Zoom numbers its builds separately per platform, so 7.1.6 does not
# exist for iOS at all -- 7.1.x is 7.1.0 and 7.1.5.
ZOOM_SDK_VERSION = "7.1.5"

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
  s.dependency "ZoomMeetingSDK", ZOOM_SDK_VERSION

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
