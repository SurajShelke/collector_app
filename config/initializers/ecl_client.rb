EclClient.configure do |config|
  config.ecl_app_url = ENV['ECL_API_ENDPOINT'] || "http://localhost:4000/api/v1"
  config.jwt_secret  = ENV['ECL_SECRET_KEY']  || "jBgilop3DTB2UluA0aae9dexGDJyFuuCm6bapQq0"
end
