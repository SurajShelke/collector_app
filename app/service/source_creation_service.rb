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
      service = EclClient::Source.new(is_org_admin: true, organization_id: @organization_id)
      service.create(
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
      )

      json_response = service.response_data

      if service.error.present?
        puts 'Source creation failed'
      end
    end
  end
end
