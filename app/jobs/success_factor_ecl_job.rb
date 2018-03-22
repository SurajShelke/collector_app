class SuccessFactorEclJob < BaseEclJob
  sidekiq_options queue: :success_factor_ecl_job

  def content_integration
    'SuccessFactorIntegration'
  end
end
