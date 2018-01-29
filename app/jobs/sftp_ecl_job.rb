class SftpEclJob < BaseEclJob
  sidekiq_options queue: :sftp_ecl_job

  def content_integration
    'SftpIntegration'
  end
end