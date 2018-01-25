class BaseEclJob
  include Sidekiq::Worker

  def perform
    FetchContentService.new.run(content_integration)
    self.class.perform_at(repeat_interval)
  end

  # String name of the content integration class, like
  # 'BrainsharkIntegration' or 'LyndaIntegration'
  def content_integration
    raise NotImplementedError
  end

  # Repeat interval for re-pulling data. Defaults to 24 hours
  def repeat_interval
    24.hours.from_now
  end
end
