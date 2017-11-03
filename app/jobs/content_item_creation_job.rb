class ContentItemCreationJob
  include Sidekiq::Worker
  sidekiq_options queue: :content_item_job

  def perform(ecl_client_id, ecl_token, attributes)
    ContentItemCreationService.new(ecl_client_id, ecl_token, attributes).create
  end
end