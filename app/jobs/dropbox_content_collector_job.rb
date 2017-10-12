class DropboxContentCollectorJob
  include Sidekiq::Worker
  sidekiq_options queue: :dropbox_ecl_job, retry: 1, backtrace: true

  def perform(args)
    args = args.symbolize_keys
    fetch_content(args)
    update_source(args[:source_id], args[:organization_id])
  end

  def fetch_content(args, options={})
    begin
      service = DropboxFetchContentService.new(args)
      source  = service.find_source(args[:source_id], args[:organization_id])

      if source["content_items_count"] || 0)> 0
        service.fetch_latest_cursor_and_collect_files(args[:source_config]['folder_id'])
      else
        service.collect_files(args[:source_config]['folder_id'])
      end
    rescue Collector::NoContentException => _
      # Ignored
    rescue => e
      # Notify Error with message format:
      # "Failed Integration #{integration_name} => ErrorMessage: #{e.message}"
      raise Collector::Error::IntegrationFailure, "Failed Integration Dropbox => ErrorMessage: #{e.message}"
    end
  end

  def find_source(source_id, organization_id)
    service = EclClient::Source.new(organization_id: organization_id, is_org_admin: true)
    response = service.find(source_id)
    response.status_code == 200 ? response.response_data["data"] : {}
  end

  def update_source(source_id, organization_id)
    service = EclClient::Source.new(organization_id: organization_id, is_org_admin: true)
    service.update(source_id, { last_polled_at: Time.now })
  end
end
