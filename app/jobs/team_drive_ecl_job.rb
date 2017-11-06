class TeamDriveEclJob < BaseEclJob
  sidekiq_options queue: :team_drive_ecl_job

  def content_integration
    'TeamDriveIntegration'
  end
end
