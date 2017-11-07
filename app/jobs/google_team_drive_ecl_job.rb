class GoogleTeamDriveEclJob < BaseEclJob
  sidekiq_options queue: :google_team_drive_ecl_job

  def content_integration
    'GoogleTeamDriveIntegration'
  end
end
