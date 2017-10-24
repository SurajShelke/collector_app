class SourceService

  attr_accessor :client_id,:secret,:communicator
  
  def initialize(client_id,secret)
    @client_id = client_id
    @token = token
  end
  # Get Source  based on id
  def find(source_id)
    @communicator = EclDeveloperClient::Source.new(@client_id,@secret)
    response = @communicator.find(source_id)
    response.success? ? communicator.response_data["data"] : {}
  end

   def create(params={})
      
    @communicator = EclDeveloperClient::Source.new(@client_id,@secret)
    response = @communicator.create(params)
    response.success? ? @communicator.response_data["data"] : {}
      # attributes = {
      #   source_type_id:  @source_type_id,
      #   source_config:   {
      #     client_id:     AppConfig.client_id,
      #     client_secret: AppConfig.client_secret,
      #     access_token:  @access_token,
      #     folder_id:     folder_id,
      #     dropbox_login: @options[:email]
      #   },
      #   display_name:    folder_name,
      #   organization_id: @organization_id,
      #   is_enabled:      true,
      #   is_default:      false,
      #   is_featured:     false,
      #   approved:        true
      # }
      # response = communicator.establish_post_connection("api/developer/v1/sources", attributes)
      # response.success? ? communicator.response_data["data"] : {}
    end
  end
end
