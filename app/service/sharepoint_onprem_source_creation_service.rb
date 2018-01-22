class SharepointOnpremSourceCreationService
  def initialize(ecl_client_id, ecl_token, options= {})
    @ecl_client_id          = ecl_client_id
    @ecl_token              = ecl_token
    @options                = options
    @source_type_id         = options[:source_type_id]
    @organization_id        = options[:organization_id]
    @folders                = options[:folders]
    @provider_id            = options[:provider_id]
    @site_name              = options[:site_name]
    @client_secret          = options[:client_secret]
  end

  def create_sources
    @folders.each do |folder_relative_url, folder|
      communicator = EclDeveloperClient::Source.new(@ecl_client_id, @ecl_token)
      attributes = {
        source_type_id:  @source_type_id,
        source_config:   {
          provider_id:            @provider_id,
          folder_id:              folder[:id],
          folder_relative_url:    folder_relative_url,
          site_name:              @site_name,
          client_secret:          @client_secret
        },
        display_name:    "#{@site_name} (#{folder[:name]})",
        organization_id: @organization_id,
        is_enabled:      true,
        is_default:      false,
        is_featured:     false,
        approved:        true
      }
      response = communicator.create(attributes)  
      response.success? ? communicator.response_data["data"] : {}
    end
  end
end