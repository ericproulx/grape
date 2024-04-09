# frozen_string_literal: true

# when changing this file, run appraisal install ; rubocop -a gemfiles/*.gemfile

source('https://rubygems.org')

gemspec

group :development, :test do
  gem 'bundler'
  gem 'dry-validation'
  gem 'hashie'
  gem 'rake'
  gem 'rubocop', '1.59.0', require: false
  gem 'rubocop-performance', '1.20.1', require: false
  gem 'rubocop-rspec', '2.25.0', require: false
end

group :development do
  gem 'appraisal'
  gem 'benchmark-ips'
  gem 'benchmark-memory'
  gem 'guard'
  gem 'guard-rspec'
  gem 'guard-rubocop'
end

group :test do
  gem 'grape-entity', '~> 0.6', require: false
  gem 'rack-contrib', require: 'rack/contrib/jsonp'
  gem 'rack-test', '< 2.1'
  gem 'rspec', '< 4'
  gem 'ruby-grape-danger', '~> 0.2.0', require: false
  gem 'simplecov', '~> 0.21.2'
  gem 'simplecov-lcov', '~> 0.8.0'
  gem 'test-prof', require: false
end

platforms :jruby do
  gem 'racc'
end
