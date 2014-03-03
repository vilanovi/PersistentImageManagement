Pod::Spec.new do |s|

  s.name         = "Persistent Image Cache"
  s.version      = "0.0.1"
  s.summary      = "Easy solution for storing and querying images from persistence"

  s.description  = ""

  s.homepage     = "http://github.com/vilanovi/ios-imagestore"
  s.license      = { :type => 'MIT', :file => 'LICENSE.txt' }
  s.author             = { "Joan Martin" => "vilanovi@gmail.com" }
  s.social_media_url = "http://twitter.com/joan_mh"
  s.platform     = :ios, '6.0'
  s.source       = { :git => "https://github.com/vilanovi/ios-imagestore.git", :tag => "0.0.1" }
  s.source_files = '*.{h,m}'
  s.framework  = 'UIKit'
  s.dependency   'FMDB'
  s.requires_arc = true
  
end