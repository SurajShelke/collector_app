class ContentItemCreationService

  attr_accessor :attributes, :organization_id

  def initialize(attributes,organization_id=nil)
    @attributes = attributes
    @organization_id = organization_id
  end

  def create
    begin
      service = EclClient::ContentItem.new(payload)
      service.create(@attributes)
    rescue => e
      if e.is_a?(Faraday::ConnectionFailed)
        ContentItemCreationJob.perform_in(15.minutes, @attributes, @organization_id)
        reschedule_message = "Rescheduled: After 15 minutes"
      end
      raise Collector::Error::ContentCreationFailure, "ECL Content Creation Error - OrganizationId: #{@organization_id}, ErrorMessage: #{e.message}, #{reschedule_message}"
    end
  end

  def payload
    {
      "organization_id"=> @organization_id,
      "is_superadmin" => @organization_id.blank? ? true : false
    }
  end

end
