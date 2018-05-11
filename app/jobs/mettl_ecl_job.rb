class MettlEclJob < BaseEclJob
  sidekiq_options queue: :mettl_ecl_job

  def content_integration
    'MettlIntegration'
  end
end