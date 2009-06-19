Gem::Specification.new do |s|
  s.name = %q{bunny}
  s.version = "0.4.4"
  s.authors = ["Chris Duncan"]
  s.date = %q{2009-06-19}
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
		"examples/simple_headers.rb",
		"lib/bunny.rb",
		"lib/bunny/client08.rb",
		"lib/bunny/client091.rb",
		"lib/bunny/exchange08.rb",
		"lib/bunny/exchange091.rb",
		"lib/bunny/queue08.rb",
		"lib/bunny/queue091.rb",
		"lib/qrack/client.rb",
		"lib/qrack/protocol/protocol.rb",
		"lib/qrack/protocol/spec08.rb",
		"lib/qrack/protocol/spec091.rb",
		"lib/qrack/qrack08.rb",
		"lib/qrack/qrack091.rb",
		"lib/qrack/transport/buffer.rb",
		"lib/qrack/transport/frame08.rb",
		"lib/qrack/transport/frame091.rb",
		"spec/bunny_spec.rb",
		"spec/exchange_spec.rb",
		"spec/queue_spec.rb"]
end
