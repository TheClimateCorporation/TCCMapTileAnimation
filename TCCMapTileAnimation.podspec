#
# Be sure to run `pod lib lint MapAnimatedTileOverlay.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "TCCMapTileAnimation"
  s.version          = "1.0.0"
  s.summary          = "A library for creating animated map overlays from tiles"
  s.homepage         = "https://github.com/TheClimateCorporation/TCCMapTileAnimation"
  s.license          = 'MIT'
  s.author           = "Kiavash Faisali, John Starin, Richard Shin", "Bruce Johnson", "Matthew Sniff"
  s.source           = { :git => "https://github.com/TheClimateCorporation/TCCMapTileAnimation.git",
  						 :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/climatecorp'

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.framework = 'MapKit'
end
