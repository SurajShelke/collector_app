EclDeveloperClient.configure do |config|
  config.ecl_app_url = ENV['ECL_APP_URL'] || "http://qa.edcast.io/api/developer/v1"
end
