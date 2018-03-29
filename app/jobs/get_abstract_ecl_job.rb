class GetAbstractEclJob < BaseEclJob
  sidekiq_options :queue => :get_abstract_ecl_job, :retry => 1, :backtrace => true

  def content_integration
    'GetAbstractIntegration'
  end
end
