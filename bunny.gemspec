require_relative "lib/bunny/version"

Gem::Specification.new do |s|
  s.name = "bunny"
  s.version = Bunny::VERSION
  s.homepage = "http://rubybunny.info"
  s.summary = "Popular easy to use Ruby client for RabbitMQ"
  s.description = "Easy to use, feature complete Ruby client for RabbitMQ 3.9 and later versions."
  s.license = "MIT"
  s.required_ruby_version = ">= 3.0"

  s.metadata = {
    "changelog_uri" => "https://github.com/ruby-amqp/bunny/blob/main/ChangeLog.md",
    "source_code_uri" => "https://github.com/ruby-amqp/bunny/",
  }

  s.authors = [
    "Chris Duncan",
    "Eric Lindvall",
    "Jakub Stastny aka botanicus",
    "Michael S. Klishin",
    "Stefan Kaes",
  ]

  s.email = ["michael.s.klishin@gmail.com"]

  s.add_runtime_dependency "amq-protocol", "~> 2.7"
  s.add_runtime_dependency "logger", "~> 1", ">= 1.7"
  s.add_runtime_dependency "sorted_set", "~> 1", ">= 1.0.2"

  s.extra_rdoc_files = ["README.md"]
  s.files = Dir["lib/**/*", "README.md", "LICENSE", "ChangeLog.md"]
  s.require_paths = ["lib"]
end
