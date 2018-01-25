Bugsnag.configure do |config|
  config.api_key = ENV['BUGSNAG_RAILS_API_KEY'] || ''
  config.notify_release_stages = ["production", "staging", "qa"]
  config.ignore_classes = []
  config.send_environment = true
end
