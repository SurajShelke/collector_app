class DropboxEclJob < BaseEclJob
  sidekiq_options queue: :dropbox_ecl_job

  def content_integration
    'DropboxIntegration'
  end
end
