Pod::Spec.new do |s|
  s.name = 'Covfefe'
  s.version = '0.3.2'
  s.license = 'MIT'
  s.summary = 'A parser generator for nondeterministic context free languages'
  s.homepage = 'https://github.com/palle-k/Covfefe'
  s.authors = 'Palle Klewitz'
  s.source = { :git => 'https://github.com/palle-k/Covfefe.git', :tag => s.version }

  s.ios.deployment_target = '11.0'

  s.source_files = 'Sources/Covfefe/*.swift'
end
