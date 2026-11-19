Pod::Spec.new do |s|
  s.name             = 'nexa_realtime'
  s.version          = '0.1.0'
  s.summary          = 'Read-only audio session facts for NEXA voice calls.'
  s.homepage         = 'https://example.invalid/nexa'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'NEXA' => 'dev@example.invalid' }
  s.source           = { :path => '.' }
  s.source_files     = 'nexa_realtime/Sources/nexa_realtime/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.9'
end
