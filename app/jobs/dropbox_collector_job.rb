class DropboxCollectorJob

  include Sidekiq::Worker
  sidekiq_options queue: :dropbox, retry: 1, backtrace: true

  def perform(source_type_id= nil)
    source_type_id ||= SourceType.get_source_type_by_name("dropbox").first["id"]

    if source_type_id.present?
      service = SourcePullerService.new(source_type_id)

      service.fetch_sources_by_source_type do |source|
        DropboxContentCollectorJob.perform_async(
          source_id:       source['id'],
          last_polled_at:  source['last_polled_at'],
          organization_id: source['organization_id'],
          source_config:   source['source_config']
        )
      end
    end
  end
end
