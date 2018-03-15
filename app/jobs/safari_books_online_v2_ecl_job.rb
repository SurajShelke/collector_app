class SafariBooksOnlineV2EclJob < BaseEclJob
  sidekiq_options queue: :safari_books_online_v2_ecl_job

  def content_integration
    'SafariBooksOnlineV2Integration'
  end
end
