Pod::Spec.new do |s|
  s.name = 'Covfefe'
  s.version = '0.6.1'
  s.license = 'MIT'
  s.summary = 'A parser generator for nondeterministic context free languages'
  s.homepage = 'https://github.com/palle-k/Covfefe'
  s.authors = 'Palle Klewitz'
  s.source = { :git => 'https://github.com/palle-k/Covfefe.git', :tag => s.version }

  s.swift_version = '5.1'

  s.osx.deployment_target = '10.9'
  s.ios.deployment_target = '8.0'
  s.watchos.deployment_target = '2.0'

  s.source_files = 'Sources/Covfefe/*.swift'
end
