# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gitfyncy/version'

Gem::Specification.new do |gem|
  gem.name          = "gitfyncy"
  gem.version       = Gitfyncy::VERSION
  gem.authors       = ["Ryan McGowan"]
  gem.email         = ["ryan@ryanmcg.com"]
  gem.description   = %q{The funky git aware syncer.}
  gem.summary       = %q{Want to sync the working directories of your git
                         directory with a remote one. Look no futher.}
  gem.homepage      = "https://github.com/RyanMcG/git-fyncy"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  [['listen', '~> 1.3']].each do |dep|
    gem.add_dependency(*dep)
  end
end
