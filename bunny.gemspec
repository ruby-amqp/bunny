# encoding: utf-8

require File.expand_path("../lib/bunny/version", __FILE__)

Gem::Specification.new do |s|
  s.name = %q{bunny}
  s.version = Bunny::VERSION.dup
  s.authors = ["Chris Duncan"]
  s.description = %q{Another synchronous Ruby AMQP client}
  s.email = %q{celldee@gmail.com}
  s.rubyforge_project = %q{bunny-amqp}
  s.has_rdoc = true
 	s.extra_rdoc_files = [ "README.rdoc" ]
  s.rdoc_options = [ "--main", "README.rdoc" ]
  s.homepage = %q{http://github.com/ruby-amqp/bunny}
  s.summary = %q{A synchronous Ruby AMQP client that enables interaction with AMQP-compliant brokers/servers.}
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
