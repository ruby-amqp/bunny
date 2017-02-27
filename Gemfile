# encoding: utf-8

source "https://rubygems.org"

# Use local clones if possible.
# If you want to use your local copy, just symlink it to vendor.
# See http://blog.101ideas.cz/posts/custom-gems-in-gemfile.html
extend Module.new {
  def gem(name, *args)
    options = args.last.is_a?(Hash) ? args.last : Hash.new

    local_path = File.expand_path("../vendor/#{name}", __FILE__)
    if File.exist?(local_path)
      super name, options.merge(:path => local_path).
        delete_if { |key, _| [:git, :branch].include?(key) }
    else
      super name, *args
    end
  end
}

gem "rake", ">= 10.0.4"
gem "effin_utf8"

group :development do
  gem "yard"

  gem "redcarpet", :platform => :mri
  gem "ruby-prof", :platform => :mri

  gem "json",      :platform => :ruby_18
end

group :test do
  gem "rspec", "~> 3.5.0"
  gem "rabbitmq_http_api_client", "~> 1.8.0"
end

gemspec

# Use local clones if possible.
# If you want to use your local copy, just symlink it to vendor.
def custom_gem(name, options = Hash.new)
  local_path = File.expand_path("../vendor/#{name}", __FILE__)
  if File.exist?(local_path)
    # puts "Using #{name} from #{local_path}..."
    gem name, options.merge(:path => local_path).delete_if { |key, _| [:git, :branch].include?(key) }
  else
    gem name, options
  end
end

custom_gem "amq-protocol", git: "https://github.com/ruby-amqp/amq-protocol", branch: "master"
