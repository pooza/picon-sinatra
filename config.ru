ROOT_DIR = File.expand_path('..', __FILE__)
$LOAD_PATH.push(ROOT_DIR)
ENV['BUNDLE_GEMFILE'] ||= File.join(ROOT_DIR, 'Gemfile')

require 'bundler/setup'
require 'sinatra'
require 'sinatra/json'
require 'app.rb'
run Picon
