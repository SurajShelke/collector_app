class SharepointOnpremEclJob < BaseEclJob
  sidekiq_options queue: :sharepoint_onprem_ecl_job

  def content_integration
    'SharepointOnpremIntegration'
  end
end