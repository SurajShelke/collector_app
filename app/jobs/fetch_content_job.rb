class FetchContentJob
  include Sidekiq::Worker
  sidekiq_options queue: :fetch_content_ecl_job, retry: 1, backtrace: true,
    unique: :until_executed

  def perform(content_integration_str, credentials, source_id, organization_id=nil, last_polled_at= nil, page= 0)
    service = StoreContentItemService.new(content_integration_str, credentials, source_id, organization_id, last_polled_at)
    service.run(page)

    integration = content_integration_str.constantize

    if !credentials.has_key?('is_delta')
      ecl_service = EclDeveloperClient::Source.new(integration.ecl_client_id,integration.ecl_token)
      ecl_service.update(source_id, { last_polled_at: Time.now })
    end
  end
end
