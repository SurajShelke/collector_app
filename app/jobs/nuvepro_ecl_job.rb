class NuveproEclJob < BaseEclJob
  sidekiq_options queue: :nuvepro_ecl_job

  def content_integration
    'NuveproIntegration'
  end
end
