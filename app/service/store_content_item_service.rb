class StoreContentItemService
  def initialize(content_integration_str, credentials, source_id, organization_id=nil, last_polled_at=nil)

    @content_integration = content_integration_str.constantize
    @source_id = source_id
    @organization_id = organization_id
    @last_polled_at = last_polled_at

    credentials ||= {}
    credentials["source_id"] = source_id
    credentials["organization_id"] = organization_id
    @client = @content_integration.new(credentials)

    @source_name = @content_integration.get_source_name
  end

  def run(page=0)
    begin
      # STEP 1: Get data from the client
      start = page * @content_integration.per_page
      limit = @content_integration.per_page
      @client.get_content({start: start, limit: limit, page: page, last_polled_at: @last_polled_at})

    rescue NoContentException => _
      # Ignored
    rescue => e
      raise Collector::Error::IntegrationFailure, "Failed Integration #{@source_id} => Page: #{page}, ErrorMessage: #{e.message}"
    end
  end


end
