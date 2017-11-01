EclDeveloperClient.configure do |config|
  config.ecl_app_url = ENV['ECL_APP_URL'] || "http://localhost:3000/api/developer/v1"
end
