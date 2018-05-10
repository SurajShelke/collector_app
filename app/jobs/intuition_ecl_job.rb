class IntuitionEclJob < BaseEclJob
  sidekiq_options queue: :intuition_ecl_job

  def content_integration
    'IntuitionIntegration'
  end
end
