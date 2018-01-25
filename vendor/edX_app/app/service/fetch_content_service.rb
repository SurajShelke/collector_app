class FetchContentService
  def run(content_integration_str)
    # STEP 1: Get the content integration class
    content_integration = content_integration_str.constantize

    # STEP 2: Get the fetch content job queue to execute in
    fetch_content_job_queue = content_integration.get_fetch_content_job_queue

    # STEP 3: Initialize the source puller service with the required source name
    sources = content_integration.get_source_name
    sources = sources.is_a?(String) ? [sources] : sources
    sources.each do |source_name|
      service = SourcePullerService.new(source_name,content_integration.ecl_client_id,content_integration.ecl_token)

      service.fetch_sources_by_source_type do |source|
        # STEP 4: Get properly formatted credentials from the content integration
        next if source['deleted_at'].present? && !source['is_default']
        credentials = source["source_config"]
        organization_id = source['organization_id']

        # STEP 5: Execute the fetch content job with
        # credentials, source id and organization id

        Sidekiq::Client.push(
          'class' => FetchContentJob,
          'queue' => fetch_content_job_queue.to_s,
          'args' => [content_integration_str, credentials, source['id'], organization_id, source['last_polled_at']],
          'at'=> content_integration.schedule_at
        )
      end
    end
  end
end
