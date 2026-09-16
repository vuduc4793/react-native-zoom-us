require "json"
package = JSON.parse(File.read(File.join(__dir__, "package.json")))

# Zoom Meeting SDK for iOS
#   SDK version : 7.1.5.37603
#   Pod         : https://github.com/vuduc4793/zoom-sdk-pods
ZOOM_SDK_VERSION = "7.1.5.37603"

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

  # Zoom iOS SDK 7.x requires iOS 15.0 and ships an arm64-only simulator slice.
  s.platform     = :ios, "15.0"

  s.source       = { :git => "https://github.com/vuduc4793/react-native-zoom-us" }
  s.source_files = "ios/*.{h,m}"
  s.requires_arc = true

  s.static_framework = true
  s.dependency "React-Core"
  s.dependency "RNZoomSDK", ZOOM_SDK_VERSION

  # Mirror RNZoomSDK's simulator constraint so this pod and the consuming app
  # agree on the arm64-only simulator slice; otherwise the x86_64 link step
  # fails with "building for iOS Simulator, but linking ... built for iOS".
  s.pod_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'x86_64 i386'
  }
  s.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'x86_64 i386'
  }
end
