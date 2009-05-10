Gem::Specification.new do |s|
  s.name = %q{bunny}
  s.version = "0.3.0"
  s.authors = ["Chris Duncan"]
  s.date = %q{2009-05-10}
  s.description = %q{Another synchronous Ruby AMQP client}
  s.email = %q{celldee@gmail.com}
  s.rubyforge_project = %q{bunny-amqp}
  s.has_rdoc = true
 	s.extra_rdoc_files = [ "README" ]
  s.rdoc_options = [ "--main", "README" ]
  s.homepage = %q{http://github.com/celldee/bunny}
  s.summary = %q{A synchronous Ruby AMQP client that enables interaction with AMQP-compliant brokers/servers.}
  s.files = ["LICENSE",
 "README",
 "Rakefile",
 "bunny.gemspec",
 "examples/simple.rb",
 "examples/simple_ack.rb",
 "examples/simple_consumer.rb",
 "examples/simple_fanout.rb",
 "examples/simple_publisher.rb",
 "examples/simple_topic.rb",
 "ext/amqp-0.8.json",
 "ext/codegen.rb",
 "lib/bunny.rb",
 "lib/bunny/client.rb",
 "lib/bunny/exchange.rb",
 "lib/bunny/protocol/protocol.rb",
 "lib/bunny/protocol/spec.rb",
 "lib/bunny/queue.rb",
 "lib/bunny/transport/buffer.rb",
 "lib/bunny/transport/frame.rb",
 "spec/bunny_spec.rb",
 "spec/exchange_spec.rb",
 "spec/queue_spec.rb"]
end
