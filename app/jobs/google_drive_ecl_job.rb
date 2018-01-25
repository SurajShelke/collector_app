class GoogleDriveEclJob < BaseEclJob
  sidekiq_options queue: :google_drive_ecl_job

  def content_integration
    'GoogleDriveIntegration'
  end
end
