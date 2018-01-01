class BoxController < ApplicationController

  skip_before_action :verify_authenticity_token

  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

  def index
    provider = IdentityProvider.find_by(id: params[:provider_id])
    if provider
      begin
        new_tokens = get_new_tokens(provider.token)
        # Box's refresh tokens are valid for a single refresh, for up to 60 days. So, update refresh_token with recently received one.
        provider.update_attribute(:token, new_tokens["refresh_token"])

        client = Boxr::Client.new(new_tokens["access_token"])
        @root_id = Boxr::ROOT
        user_account = client.current_user(fields: [])
        @folders = client.folder_items(Boxr::ROOT)
        @folders.select! { |folder| folder.type == 'folder' }
        @folders.unshift({"id" => "#{@root_id}", "name" => "Root"})
      rescue StandardError => he
        redirect_to authorize_box_index_path
      end
    else
      render json: { folders: [], provider_id: params[:provider_id], message: 'Invalid user' }, status: :unprocessable_entity
    end
  end

  def authorize
    state_params = {
      auth_data: params[:auth_data],
      secret: params[:secret]
    }.to_json
    # send client_host, organization_id, and source_type_id in state param
    state_params = Base64.urlsafe_encode64(state_params)
    auth_url = code_client.auth_code.authorize_url(:redirect_uri => callback_box_index_url,
      :response_type => "code",
      :scope => "root_readwrite", 
      :state => state_params)
    redirect_to auth_url
  end

  # mine
  def callback
    unless params[:code]
      render json: { message: "Invalid user" }, status: :unprocessable_entity
    else
      token = token_client.auth_code.get_token(params[:code],
        :redirect_uri => callback_box_index_url,
        :grant_type => 'authorization_code'
        )
      
      client = Boxr::Client.new(token.token)
      user_account = client.current_user(fields: [])
      @refresh_token = token.refresh_token
      # fetch user account details
      # save user details with identity provider and redirect to list folder UI
      if user_account.present?
        provider = User.create_or_update_box_user(user_account, @refresh_token)

        if provider
          redirect_to box_index_url(
            provider_id: provider.id,
            state: params[:state]
          )
        else
          render json: { message: "Record cannot be processed" }, status: :unprocessable_entity
        end
      end
    end
  end

  def fetch_folders
    refresh_token = IdentityProvider.get_box_refresh_token(params[:provider_id])
    if refresh_token
      begin
        box_sesion = authentication_session(refresh_token: refresh_token)
        @folders  = get_folders(box_sesion)
      end
    end
    # urlsafe_encode64
    render :action => 'index'
  end

  def create_sources
    begin
      decrypt_state
      refresh_token = IdentityProvider.get_box_refresh_token(params[:provider_id])
      if @unauthorized_parameters
        render json: { message: 'Unauthorized parameters' }, status: :unauthorized
      else
        service = BoxSourceCreationService.new(
            AppConfig.integrations['box']['ecl_client_id'],
            AppConfig.integrations['box']['ecl_token'],
            folders:          source_params[:folders] || [],
            refresh_token:    refresh_token,
            organization_id:  @organization_id,
            source_type_id:   @source_type_id,
            extract_content:  @extract_content
        )
        begin
          service.create_sources
          redirect_to "#{@client_host}/admin/integrations/eclConfigurations"
        rescue StandardError => err
          render json: { message: err }, status: :unprocessable_entity
        end
      end
    rescue => e
      render json: { message: 'Invalid or bad parameters' }, status: :unprocessable_entity
    end
  end

  private

  def decrypt_state
    decoded_params = Base64.decode64(params[:state])
    state_data = JSON.parse(decoded_params)
    decrypted_data = JSON.parse(Base64.decode64(state_data["auth_data"]))

    digest  = OpenSSL::Digest.new('sha256')
    calculated_secret = OpenSSL::HMAC.hexdigest(digest, AppConfig.digest_secret, state_data['auth_data'])

    # check integrity of params passed
    if calculated_secret == state_data['secret']
      @client_host     = decrypted_data['client_host']
      @organization_id = decrypted_data['organization_id']
      @source_type_id  = decrypted_data['source_type_id']
      @extract_content = decrypted_data['extract_content']
    else
      @unauthorized_parameters = true
    end
  end

  # Exchanges an authorization code for a token
  def get_token_from_code(code)
    begin
      auth_bearer = client.auth_code.get_token(code, { :redirect_uri => callback_box_index_url, :token_method => :post })
      session[:box_auth_token] = auth_bearer.to_hash
      @access_token = auth_bearer.token
      @refresh_token = auth_bearer.refresh_token
    rescue OAuth2::Error => oe
      render json: { message: "#{oe.message}" }, status: :unprocessable_entity
    end
  end

  # Gets the current access token
  def get_new_tokens(refresh_token)
    params = {
                client_id: AppConfig.integrations['box']['client_id'],
                client_secret: AppConfig.integrations['box']['client_secret'],
                refresh_token: refresh_token,
                grant_type: 'refresh_token'
              }
    conn = Faraday.new('https://api.box.com')
    response = conn.post do |req|
      req.url '/oauth2/token'
      req.headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }
      req.body = params
    end
    JSON.parse(response.body)
  end

  # Check if token is expired, refresh if so
  def renew_token_if_expired(token)
    if token.expired?
      new_token = token.refresh!
      new_token.to_hash
    else
      token.to_hash
    end
  end

  def source_params
    params.permit(:state, :provider_id, :drive_id, :client_host, :source_type_id, :organization_id, :utf8, :authenticity_token, :commit, folders: {})
  end

  def code_client
    OAuth2::Client.new(AppConfig.integrations['box']['client_id'],
                       AppConfig.integrations['box']['client_secret'],
                       :site => "https://account.box.com",
                       :authorize_url => "/api/oauth2/authorize")
  end

  def token_client
    OAuth2::Client.new(AppConfig.integrations['box']['client_id'],
                       AppConfig.integrations['box']['client_secret'],
                       :site => "https://api.box.com/",
                       :token_url => "/oauth2/token",
                       :scope => "root_readwrite",
                       :grant_type => 'authorization_code')
  end

end
