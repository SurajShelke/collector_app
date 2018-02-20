class LyndaEclJob < BaseEclJob
  sidekiq_options queue: :lynda_ecl_job

  def content_integration
    'LyndaIntegration'
  end
end
