# encoding: utf-8

source :rubygems

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

gem "SystemTimer", "1.2", :platform => :ruby_18

group :development do
  gem "rake"
  gem "effin_utf8"
end

group :test do
  gem "rspec", "~> 2.8.0"
end

gemspec

gem "amq-protocol", :git => "git://github.com/ruby-amqp/amq-protocol.git", :branch => "master"
