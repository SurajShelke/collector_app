class SafariBooksOnlinePublicEclJob < BaseEclJob
  sidekiq_options queue: :safari_books_online_public_ecl_job

  def content_integration
    'SafariBooksOnlinePublicIntegration'
  end
end
