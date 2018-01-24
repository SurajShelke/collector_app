class EdxEnterpriseEclJob < BaseEclJob
  sidekiq_options queue: :edx_enterprise_ecl_job

  def content_integration
    'EdxEnterpriseIntegration'
  end
end
