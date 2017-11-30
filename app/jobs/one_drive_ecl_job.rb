class OneDriveEclJob < BaseEclJob
  sidekiq_options queue: :one_drive_ecl_job

  def content_integration
  	'OneDriveIntegration'
  end
end