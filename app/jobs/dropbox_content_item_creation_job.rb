class DropboxContentItemCreationJob

  include Sidekiq::Worker
  sidekiq_options queue: :dropbox_content_creation_job, retry: 1, backtrace: true

  def perform(organization_id, attributes)
    begin
      service = EclClient::ContentItem.new(organization_id: organization_id, is_org_admin: true)
      service.create(attributes)
    rescue => e
      if e.is_a?(Faraday::ConnectionFailed)
        DropContentItemCreationJob.perform_in(15.minutes, organization_id, attributes)
        reschedule_message = "Rescheduled: After 15 minutes"
      end
      raise Collector::Error::ContentCreationFailure, "ECL Content Creation Error - OrganizationId: #{organization_id}, ErrorMessage: #{e.message}, #{reschedule_message}"
    end
  end
end
