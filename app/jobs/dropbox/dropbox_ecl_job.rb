class DropboxEclJob < BaseEclJob
  sidekiq_options :queue => :dropbox_ecl_job,:backtrace => true
  def perform
    FetchContentService.new.run(content_integration)    
  end
  def content_integration
    'DropboxIntegration'
  end
end
