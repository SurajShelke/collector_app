class BoxSourceCreationService
  def initialize(ecl_client_id, ecl_token, options= {})
    @ecl_client_id   = ecl_client_id
    @ecl_token       = ecl_token
    @options         = options
    @source_type_id  = options[:source_type_id]
    @organization_id = options[:organization_id]
    @refresh_token   = options[:refresh_token]
    @folders         = options[:folders]
  end

  def create_sources
    @folders.each do |folder_id, folder_name|
      communicator = EclDeveloperClient::Source.new(@ecl_client_id, @ecl_token)
      attributes = {
        source_type_id:  @source_type_id,
        source_config:   {
          client_id:     AppConfig.integrations['box']['client_id'],
          client_secret: AppConfig.integrations['box']['client_secret'],
          refresh_token:  @refresh_token,
          folder_id:     folder_id,
        },
        display_name:    "Box (#{folder_name})",
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
