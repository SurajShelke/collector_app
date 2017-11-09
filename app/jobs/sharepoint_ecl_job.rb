class SharepointEclJob < BaseEclJob
  sidekiq_options queue: :sharepoint_ecl_job

  def content_integration
  	'SharepointIntegration'
  end
end