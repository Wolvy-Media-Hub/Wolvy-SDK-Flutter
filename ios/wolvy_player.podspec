#
# The Wolvy Flutter SDK on iOS. The Wolvy iOS SDK's sources are carried in
# wolvy_player/Sources/wolvy_player/WolvyCore (tool/sync_ios_core.sh, version in wolvy_player/CORE_VERSION).
#
Pod::Spec.new do |s|
  s.name             = 'wolvy_player'
  s.version          = '0.3.0'
  s.summary          = "Plays Wolvy's DRM-protected video in Flutter apps (FairPlay on iOS)."
  s.description      = <<-DESC
The iOS side of the wolvy_player Flutter package: the Wolvy iOS SDK (AVPlayer and FairPlay) behind
the package's Dart API.
                       DESC
  s.homepage         = 'https://docs.wolvy.net/mobile-sdks/'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Wolvy' => 'contact@wolvy.net' }
  s.source           = { :path => '.' }
  s.source_files     = 'wolvy_player/Sources/wolvy_player/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.frameworks = 'AVFoundation', 'UIKit'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
