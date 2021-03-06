Pod::Spec.new do |s|
  s.name = 'Pledges'
  s.version = '3.0'
  s.social_media_url = 'https://twitter.com/zeGreatRoB'
  s.homepage = 'http://www.github.com/robertfmurdock/Pledges'
  s.authors = { 'Rob Murdock' => 'rmurdock@pillartechnology.com' }
  s.source = { :git => 'https://github.com/robertfmurdock/Pledges.git', :tag => s.version }
  s.license = 'MIT'
  s.summary = 'Pledges: the simple Swift promise library! Designed around ease of flow and composability.'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'

  s.source_files = 'Pledges/*.swift'

  s.requires_arc = true
end
