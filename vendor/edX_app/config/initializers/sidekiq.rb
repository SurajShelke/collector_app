require 'sidekiq'
require 'sidekiq/web'

Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
  [user, password] == ["admin", "admin@123!"]
end

if Rails.env == 'production' || Rails.env == 'staging' ||  Rails.env == 'qa'

  host_name = ENV['REDIS_HOST'] || AppConfig.redis['host']
  port_number = ENV['REDIS_PORT'] || AppConfig.redis['port']
  password = ENV['REDIS_PASSWORD'] || AppConfig.redis['password']
  #namespace = ENV['REDIS_NAMESPACE'] || AppConfig.redis['namespace']
  redis_url = "redis://#{host_name}:#{port_number}"

  Sidekiq.configure_client do |config|
    config.redis = { :url => redis_url, :password => password }
    config.error_handlers << Proc.new {|exception, ctx_hash| Bugsnag.notify(exception) }
  end

  Sidekiq.configure_server do |config|
    config.redis = { :url => redis_url, :password => password }
    config.error_handlers << Proc.new {|exception, ctx_hash| Bugsnag.notify(exception) }
  end

end
