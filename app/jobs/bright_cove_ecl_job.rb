class BrightCoveEclJob < BaseEclJob
  sidekiq_options queue: :bright_cove_ecl_job

  def content_integration
    'BrightCoveIntegration'
  end
end
