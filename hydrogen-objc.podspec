#
# Be sure to run `pod lib lint hydrogen-objc.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "hydrogen-objc"
  s.version          = "0.1.4"
  s.summary          = "Hydrogen Obj-C client"
  s.description      = <<-DESC
                       Obj-C SDK for building a Hydrogen client.
                       DESC
  s.homepage         = "https://github.com/nathansizemore/hydrogen-objc"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = { :type => 'MPL 2.0' }
  s.author           = { "Nathan Sizemore" => "nathanrsizemore@gmail.com" }
  s.source           = { :git => "https://github.com/nathansizemore/hydrogen-objc.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/nathansizemore'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'hydrogen-objc' => ['Pod/Assets/*.png']
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
