class BoxEclJob < BaseEclJob
  sidekiq_options queue: :box_ecl_job

  def content_integration
    'BoxIntegration'
  end
end
