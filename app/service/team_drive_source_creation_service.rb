class TeamDriveSourceCreationService
  def initialize(ecl_client_id, ecl_token, options= {})
    @ecl_client_id   = ecl_client_id
    @ecl_token       = ecl_token
    @options         = options
    @source_type_id  = options[:source_type_id]
    @organization_id = options[:organization_id]
    @refresh_token   = options[:refresh_token]
    @folders         = options[:folders]
    @team_drive_id   = options[:team_drive_id]
  end

  def create_sources
    @folders.each do |folder_id, folder_name|
      communicator = EclDeveloperClient::Source.new(@ecl_client_id, @ecl_token)
      attributes = {
        source_type_id:  @source_type_id,
        source_config:   {
          client_id:     AppConfig.integrations['team_drive']['client_id'],
          client_secret: AppConfig.integrations['team_drive']['client_secret'],
          refresh_token:  @refresh_token,
          folder_id:     folder_id,
          team_drive_id: @team_drive_id
        },
        display_name:    folder_name,
        organization_id: @organization_id,
        is_enabled:      true,
        is_default:      false,
        is_featured:     false,
        approved:        true
      }
      response = communicator.create(attributes)
      if response.success?
        return communicator.response_data["data"]
      else
        raise JSON.parse(response.body)["message"].first
      end
    end
  end
end
