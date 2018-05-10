class HbrAscendEclJob < BaseEclJob
  sidekiq_options queue: :hbr_ascend_ecl_job

  def content_integration
    'HbrAscendIntegration'
  end
end
