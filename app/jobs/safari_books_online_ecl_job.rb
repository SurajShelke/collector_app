class SafariBooksOnlineEclJob < BaseEclJob
  sidekiq_options queue: :safari_books_online_ecl_job

  def content_integration
    'SafariBooksOnlineIntegration'
  end
end
