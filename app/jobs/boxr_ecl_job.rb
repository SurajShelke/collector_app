class BoxrEclJob < BaseEclJob
  sidekiq_options queue: :boxr_ecl_job

  def content_integration
    'BoxrIntegration'
  end
end
