class SharepointController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :get_access_token, only: [:callback]
  before_action :verify_referer, only: [:authorize]

  def authorize
    state_params = {
      auth_data: params[:auth_data],
      secret: params[:secret]
    }.to_json
    
    redirect_to "https://#{AppConfig.integrations['sharepoint']['sharepoint_url']}/_layouts/oauthauthorize.aspx?state=#{state_params}&client_id=#{AppConfig.integrations['sharepoint']['client_id']}&scope=Web.Read&response_type=code&redirect_uri=#{redirect_uri}"
  end
  
  def callback
    begin
      user_account = sharepoint_communicator.get_loged_in_user("/_api/Web/CurrentUser")
      # save user details with identity provider and redirect to list folder UI
      if user_account.present?
        provider = User.create_or_update_sharepoint_user(user_account, @access_token)

        if provider
          redirect_to fetch_folders_sharepoint_index_path(
            provider_id: provider.id,
            state: params[:state]
          )
        else
          render json: { message: "Record cannot be processed" }, status: :unprocessable_entity
        end
      end
    rescue Exception => he
      render json: { message: "#{he.message}" }, status: :unprocessable_entity
    end
  end

  def select_folders(folders)
    system_folders = ["Attachments", "Item", "Forms"]
    folders.select do |folder| 
      folder unless system_folders.include?(folder["Name"])
    end
  end

  def fetch_folders
    # fetch sharepoint access token using email param
    @access_token = IdentityProvider.get_sharepoint_access_token(params[:provider_id])
    if @access_token
      begin
        @access_token = JSON.parse(@access_token)
        @folders = select_folders(sharepoint_communicator.get_folders("/_api/web/GetFolderByServerRelativeUrl('#{URI.encode('/Shared Documents')}')", { "$expand" => "Folders" })["Folders"])
      rescue Exception => he
        redirect_to authorize_sharepoint_index_path
      end
    else
      render json: { folders: [], provider_id: params[:provider_id], message: 'Invalid user' }, status: :unprocessable_entity
    end
  end

  def create_sources
    sharepoint_access_token = IdentityProvider.get_sharepoint_access_token(params[:provider_id])

    if sharepoint_access_token
      begin
        decrypt_state
        if @unauthorized_parameters
          render json: { message: 'Unauthorized parameters' }, status: :unauthorized
        else
          service = SharepointSourceCreationService.new(
            AppConfig.integrations['sharepoint']['ecl_client_id'],
            AppConfig.integrations['sharepoint']['ecl_token'],
            folders:         source_params[:folders] || [],
            access_token:    sharepoint_access_token,
            organization_id: @organization_id,
            source_type_id:  @source_type_id,
            site_realm: AppConfig.integrations['sharepoint']['site_realm'],
            audience_principal_id: AppConfig.integrations['sharepoint']['audience_principal_id'],
            sharepoint_url: AppConfig.integrations['sharepoint']['sharepoint_url']
          )
          service.create_sources
          redirect_to "#{@client_host}/admin/integrations/eclConfigurations"
        end
      rescue => e
        render json: { message: 'Invalid or bad parameters' }, status: :unprocessable_entity
      end
    else
      render json: { message: 'Invalid access token' }, status: :unprocessable_entity
    end
  end

  private

  def source_params
    params.permit(:state, folders: {})
  end

  def decrypt_state
    state_data = JSON.parse(source_params[:state])
    decrypted_data = JSON.parse(Base64.decode64(state_data["auth_data"]))

    digest  = OpenSSL::Digest.new('sha256')
    calculated_secret = OpenSSL::HMAC.hexdigest(digest, AppConfig.digest_secret, state_data['auth_data'])

    # check integrity of params passed
    if calculated_secret == state_data['secret']
      @client_host     = decrypted_data['client_host']
      @organization_id = decrypted_data['organization_id']
      @source_type_id  = decrypted_data['source_type_id']
    else
      @unauthorized_parameters = true
    end
  end

  def sharepoint_communicator
    @communicator = @communicator || SharepointCommunicator.new(
                  client_id:              AppConfig.integrations['sharepoint']['client_id'],
                  client_secret:          AppConfig.integrations['sharepoint']['client_secret'],
                  site_realm:             AppConfig.integrations['sharepoint']['site_realm'],
                  token:                  @access_token,
                  sharepoint_url:         AppConfig.integrations['sharepoint']['sharepoint_url'],
                  audience_principal_id:  AppConfig.integrations['sharepoint']['audience_principal_id'],
                  redirect_uri:           AppConfig.integrations['sharepoint']['redirect_uri']
                )
  end

  def get_access_token
    @access_token = sharepoint_communicator.get_access_token(params[:code])
  end

  def verify_referer
    # check referer TODO
  end
  
  def redirect_uri
    URI.encode(AppConfig.integrations['sharepoint']['redirect_uri'])
  end
  
end