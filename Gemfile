source "https://rubygems.org"

gemspec

def custom_gem(name, *args)
  options = args.last.is_a?(Hash) ? args.pop : {}
  local_path = File.expand_path("../vendor/#{name}", __FILE__)
  if File.exist?(local_path)
    puts "Using #{name} from #{local_path}..."
    gem name, options.merge(path: local_path).delete_if { |key, _| [:git, :branch].include?(key) }
  else
    gem name, *args, **options
  end
end

custom_gem "amq-protocol", "~> 2.7"

gem "rake", ">= 12.3.1"

group :development do
  gem "yard"
  gem "redcarpet", platform: :mri
  gem "ruby-prof", platform: :mri
  gem "benchmark"
end

group :test do
  gem "rspec", "~> 3.13"
  gem "rspec-retry", "~> 0.6"
  gem "sorted_set", "~> 1", ">= 1.0.2"
  gem "base64"
  gem "rabbitmq_http_api_client", "~> 3.2", require: "rabbitmq/http/client"
  gem "toxiproxy", "~> 2"
end
