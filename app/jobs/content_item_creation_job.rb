class ContentItemCreationJob
  include Sidekiq::Worker
  sidekiq_options :queue => :content_item_job

  def perform(attributes, organization_id)
    ContentItemCreationService.new(attributes, organization_id).create
  end
end
