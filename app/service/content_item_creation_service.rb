class ContentItemCreationService

  attr_accessor :attributes, :organization_id

  def initialize(ecl_client_id,ecl_token,attributes)
    @ecl_client_id = ecl_client_id
    @ecl_token = ecl_token
    @attributes = attributes
  end

  def create
    begin
      service = EclDeveloperClient::ContentItem.new(@ecl_client_id,@ecl_token)
      service.create(@attributes)
    rescue => e
      if e.is_a?(Faraday::ConnectionFailed)
        ContentItemCreationJob.perform_in(3.minutes,@ecl_client_id,@ecl_token, @attributes)
        reschedule_message = "Rescheduled: After 3 minutes"
      end
      raise Collector::Error::ContentCreationFailure, "ECL Content Creation Error - OrganizationId: #{@organization_id}, ErrorMessage: #{e.message}, #{reschedule_message}"
    end
  end

  

end
