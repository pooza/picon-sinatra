ROOT_DIR = File.expand_path('..', __FILE__)
$LOAD_PATH.push(File.join(ROOT_DIR, 'lib'))
ENV['BUNDLE_GEMFILE'] ||= File.join(ROOT_DIR, 'Gemfile')

require 'bundler/setup'

namespace :server do
  [:start, :stop, :restart].each do |action|
    desc "#{action} thin"
    task action do
      sh "thin --config config/thin.yaml #{action}"
    end
  end
end