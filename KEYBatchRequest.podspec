#
# Be sure to run `pod lib lint KEYBatchRequest.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'KEYBatchRequest'
  s.version          = '1.0.0'
  s.summary          = 'Library for handling batch requests via multipart/mixed.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
If you need a convenient way of bundling requests in a multipart/mixed request, this library is for you.
We use it to bundle requests directed at a .NET server, so the formatting should be just right.
It contains carefully adapted code from https://github.com/couchbase/couchbase-lite-ios.
                       DESC

  s.homepage         = 'https://github.com/keyper/KEYBatchRequest'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Manuel Maly' => 'manuel@creativepragmatics.com' }
  s.source           = { :git => 'https://github.com/keyper/KEYBatchRequest.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'
  
  s.libraries             = 'z'

  s.source_files = 'KEYBatchRequest/Classes/**/*'
  
  s.frameworks = 'QuartzCore'
  # s.resource_bundles = {
  #   'KEYBatchRequest' => ['KEYBatchRequest/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.dependency 'AFNetworking', '~> 2.3'
end
