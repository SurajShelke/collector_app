erb = ERB.new(File.read("#{Rails.root}/config/app_config.yml")).result
AppConfig = OpenStruct.new YAML.load(erb)[Rails.env]
# ActiveJob::Base.queue_adapter = :sidekiq



