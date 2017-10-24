require "redis"

if Rails.env == 'production' || Rails.env == 'staging' ||  Rails.env == 'qa'
  host_name = ENV['REDIS_HOST'] || AppConfig.redis['host']
  port_number = ENV['REDIS_PORT'] || AppConfig.redis['port']
  password = ENV['REDIS_PASSWORD'] || AppConfig.redis['password']

  redis_url = "redis://#{host_name}:#{port_number}"
  $redis = Redis.new(url: redis_url, password: password)
else
  $redis = Redis.new
end
