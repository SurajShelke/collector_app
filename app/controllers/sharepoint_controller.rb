class SharepointController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :get_access_token_details, only: [:callback]
  before_action :verify_referer, only: [:authorize]

  def authorize
    state_params = {
      auth_data: params[:auth_data],
      secret: params[:secret]
    }.to_json
    redirect_to "/auth/microsoft_v2_auth?state_params=#{state_params}"
  end

  def callback
    begin
      # save user details with identity provider and redirect to list folder UI
      if @access_token && @email && @name
        provider = User.create_or_update_sharepoint_user(@access_token, @refresh_token, @expires_at, @email, @name)
        if provider
          redirect_to fetch_folders_sharepoint_index_path(
            provider_id: provider.id,
            state: @state
          )
        else
          render json: { message: "Record cannot be processed" }, status: :unprocessable_entity
        end
      end
    rescue Exception => he
      render json: { message: "#{he.message}" }, status: :unprocessable_entity
    end
  end

  def fetch_folders
    record = IdentityProvider.find_by(id: params[:provider_id])
    if record
      begin
        decrypt_state
        if @unauthorized_parameters
          render json: { message: 'Unauthorized parameters' }, status: :unauthorized
        else
          sharepoint_communicator = SharepointCommunicator.new(
            client_id:     AppConfig.integrations['sharepoint']['client_id'],
            client_secret: AppConfig.integrations['sharepoint']['client_secret'],
            token:         record.token
          )

          root_site = sharepoint_communicator.root_site("/v1.0/sites/root")
          @sharepoint_url = root_site["siteCollection"]["hostname"]

          if @sharepoint_url
              @folders = sharepoint_communicator.folders("/v1.0/sites/#{@sharepoint_url}/drive/root/children")["value"]
          else
            render json: { message: 'Failed to get root site information, Please contact administrator' }, status: :unprocessable_entity
          end
        end
      rescue Exception => he
        redirect_to authorize_sharepoint_index_path
      end
    else
      render json: { folders: [], provider_id: params[:provider_id], message: 'Invalid user' }, status: :unprocessable_entity
    end
  end

  def create_sources
    record = IdentityProvider.find_by(id: params[:provider_id])
    if record
      begin
        decrypt_state
        if @unauthorized_parameters
          render json: { message: 'Unauthorized parameters' }, status: :unauthorized
        else
          service = SharepointSourceCreationService.new(
            AppConfig.integrations['sharepoint']['ecl_client_id'],
            AppConfig.integrations['sharepoint']['ecl_token'],
            folders:         source_params[:folders] || [],
            refresh_token:   record.secret,
            sharepoint_url:  source_params[:sharepoint_url],
            organization_id: @organization_id,
            source_type_id:  @source_type_id
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
    params.permit(:state, :sharepoint_url, :provider_id, folders: {})
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

  def get_access_token_details
    begin
      data   = request.env['omniauth.auth']
      @email = data.extra.raw_info.userPrincipalName
      @name  = data.extra.raw_info.displayName
      @access_token = data['credentials']["token"]
      @refresh_token = data['credentials']["refresh_token"]
      @expires_at = data['credentials']['expires_at']
      @state = request.env['omniauth.params']['state_params']
    rescue OAuth2::Error => oe
      render json: { message: "#{oe.message}" }, status: :unprocessable_entity
    end
  end

  def verify_referer
    # check referer TODO
  end
end
