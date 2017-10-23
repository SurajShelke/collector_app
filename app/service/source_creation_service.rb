class SourceCreationService
  def initialize(options= {})
    @options         = options
    @source_type_id  = options[:source_type_id]
    @organization_id = options[:organization_id]
    @access_token    = options[:access_token]
    @folders         = options[:folders]
  end

  def create_sources
    @folders.each do |folder_id, folder_name|
      communicator = EclCommunicator.new
      attributes = {
        source_type_id:  @source_type_id,
        source_config:   {
          client_id:     AppConfig.client_id,
          client_secret: AppConfig.client_secret,
          access_token:  @access_token,
          folder_id:     folder_id,
          dropbox_login: @options[:email]
        },
        display_name:    folder_name,
        organization_id: @organization_id,
        is_enabled:      true,
        is_default:      false,
        is_featured:     false,
        approved:        true
      }
      response = communicator.establish_post_connection("api/developer/v1/sources", attributes)
      response.success? ? communicator.response_data["data"] : {}
    end
  end
end
