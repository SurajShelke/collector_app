class SharepointSourceCreationService
  def initialize(ecl_client_id, ecl_token, options= {})
    @ecl_client_id          = ecl_client_id
    @ecl_token              = ecl_token
    @options                = options
    @source_type_id         = options[:source_type_id]
    @organization_id        = options[:organization_id]
    @access_token           = options[:access_token]
    @folders                = options[:folders]
    @site_realm             = options[:site_realm]
    @audience_principal_id  = options[:audience_principal_id]
    @sharepoint_url         = options[:sharepoint_url]
  end

  def create_sources
    @folders.each do |folder_relative_url, folder_name|
      communicator = EclDeveloperClient::Source.new(@ecl_client_id, @ecl_token)
      attributes = {
        source_type_id:  @source_type_id,
        source_config:   {
          client_id:              AppConfig.integrations['sharepoint']['client_id'],
          client_secret:          AppConfig.integrations['sharepoint']['client_secret'],
          access_token:           @access_token,
          site_realm:             @site_realm,
          audience_principal_id:  @audience_principal_id,
          sharepoint_url:         @sharepoint_url,
          folder_relative_url:    folder_relative_url.split("_sp_")[1]
        },
        display_name:    folder_name,
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
