class EdutubeEclJob < BaseEclJob
  sidekiq_options queue: :edutube_ecl_job

  def content_integration
    'EdutubeIntegration'
  end
end
