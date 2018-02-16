class SourcePullerService
  attr_accessor :source_type_id, :sources, :source_name

  def initialize(source_name, ecl_client, ecl_secret)
    @source_name = source_name
    @ecl_client = ecl_client
    @ecl_secret = ecl_secret
    fetch_source_type
  end

  def fetch_source_type
    service = EclDeveloperClient::SourceType.new(@ecl_client, @ecl_secret)
    @response = service.get(name: @source_name)
    response_data = service.response_data

    @source_type_id = response_data['data'].present? && response_data['data'][0]['id'] if @response.success?
  end

  def fetch_sources_by_source_type
    offset = 0

    while offset
      params = {
        source_type_id: @source_type_id,
        limit: 10,
        offset: offset * 10
      }

      service = EclDeveloperClient::Source.new(@ecl_client, @ecl_secret)
      @response = service.get(params)
      response_data = service.response_data

      break unless @response.success?

      @sources = response_data['data']
      break if @sources.length.zero?

      @sources.each do |source|
        yield source
      end
      offset += 1
    end
  end
end
