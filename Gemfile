# encoding: utf-8

source :rubygems

gem "SystemTimer", "1.2", :platform => :ruby_19

group :development do
  gem "rake"

  gem "yard", ">= 0.7.2"

  # Yard tags this buddy along.
  gem "RedCloth",  :platform => :mri
  gem "rdiscount", :platform => :ruby

  gem "changelog"
end

group :test do
  gem "rspec", "~> 2.6.0"
end

gemspec
