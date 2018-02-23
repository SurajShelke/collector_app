class CornerstoneEclJob < BaseEclJob
  sidekiq_options queue: :cornerstone_ecl_job

  def content_integration
    'CornerstoneIntegration'
  end
end
