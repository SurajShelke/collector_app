class FileEclJob < BaseEclJob
  sidekiq_options queue: :file_ecl_job

  def content_integration
    'FileIntegration'
  end
end