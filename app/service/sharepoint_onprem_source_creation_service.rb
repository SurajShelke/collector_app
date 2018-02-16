class SharepointOnpremSourceCreationService
  def initialize(ecl_client_id, ecl_token, options = {})
    @ecl_client_id          = ecl_client_id
    @ecl_token              = ecl_token
    @options                = options
    @source_type_id         = options[:source_type_id]
    @organization_id        = options[:organization_id]
    @folders                = options[:folders]
    @site_name              = options[:site_name]
    @client_secret          = options[:client_secret]
    @sharepoint_url         = options[:sharepoint_url]
  end

  def create_sources
    @folders.each do |folder_relative_url, folder|
      communicator = EclDeveloperClient::Source.new(@ecl_client_id, @ecl_token)
      attributes = {
        source_type_id:  @source_type_id,
        source_config:   {
          folder_id:              folder[:id],
          folder_relative_url:    folder_relative_url,
          site_name:              @site_name,
          client_secret:          @client_secret,
          sharepoint_url:         @sharepoint_url
        },
        display_name:    "#{@site_name} (#{folder[:name]})",
        organization_id: @organization_id,
        is_enabled:      true,
        is_default:      false,
        is_featured:     false,
        approved:        true
      }
      response = communicator.create(attributes)
      response.success? ? communicator.response_data['data'] : {}
    end
  end
end
