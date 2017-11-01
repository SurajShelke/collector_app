class TeamDriveController < ApplicationController

  skip_before_action :verify_authenticity_token

  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

  def index
    refresh_token = IdentityProvider.get_team_drive_refresh_token(params[:provider_id])
    if refresh_token
      begin
        drive_sesion = authentication_session(refresh_token: refresh_token)
        @drives = get_team_drives(drive_sesion)
      rescue StandardError => he
        redirect_to authorize_team_drive_index_path
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
    auth_url = client.auth_code.authorize_url(:redirect_uri => callback_team_drive_index_url, :scope => [Google::Apis::DriveV3::AUTH_DRIVE_READONLY, 'https://www.googleapis.com/auth/userinfo.email'].join(' '), :access_type => "offline", :approval_prompt => 'force', :state => state_params)
    redirect_to auth_url
  end

  # mine
  def callback
    unless params[:code]
      render json: { message: "Invalid user" }, status: :unprocessable_entity
    else
      token = get_token_from_code(params[:code])
      # fetch user account details
      user_account = get_user_info(@access_token)
      # save user details with identity provider and redirect to list folder UI
      if user_account.present?
        provider = User.create_or_update_team_drive_user(user_account, @refresh_token)

        if provider
          redirect_to team_drive_index_url(
            provider_id: provider.id,
            state: params[:state]
          )
        else
          render json: { message: "Record cannot be processed" }, status: :unprocessable_entity
        end
      end
    end
  end

  # Fetch files for selected Team Drive
  # Input: Drive Id
  def fetch_folders
    refresh_token = IdentityProvider.get_team_drive_refresh_token(params[:provider_id])
    if refresh_token
      begin
        drive_sesion = authentication_session(refresh_token: refresh_token)

        @drives = get_team_drives(drive_sesion)
        @files  = get_team_drive_content(drive_sesion)

        @files.select! { |file| file.mime_type == "application/vnd.google-apps.folder" } if @files
        @drive_id = source_params[:drive_id]
      end
    end
    # urlsafe_encode64
    render :action => 'index'
  end

  def create_sources
    begin
      decrypt_state
      refresh_token = IdentityProvider.get_team_drive_refresh_token(params[:provider_id])
      if @unauthorized_parameters
        render json: { message: 'Unauthorized parameters' }, status: :unauthorized
      else
        service = TeamDriveSourceCreationService.new(
            AppConfig.integrations['team_drive']['ecl_client_id'],
            AppConfig.integrations['team_drive']['ecl_token'],
            folders:          params[:folders] || [],
            team_drive_id:    params[:drive_id],
            refresh_token:    refresh_token,
            organization_id:  @organization_id,
            source_type_id:   @source_type_id
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

  # Fetch Team Drives list using Google APIs
  def get_team_drives(drive_sesion)
    drive_sesion.drive.list_teamdrives.team_drives if drive_sesion
  end

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
    else
      @unauthorized_parameters = true
    end
  end

  # Exchanges an authorization code for a token
  def get_token_from_code(code)
    begin
      auth_bearer = client.auth_code.get_token(code, { :redirect_uri => callback_team_drive_index_url, :token_method => :post })
      session[:google_auth_token] = auth_bearer.to_hash
      @access_token = auth_bearer.token
      @refresh_token = auth_bearer.refresh_token
    rescue OAuth2::Error => oe
      render json: { message: "#{oe.message}" }, status: :unprocessable_entity
    end
  end

  def client
    OAuth2::Client.new(AppConfig.integrations['team_drive']['client_id'],
                       AppConfig.integrations['team_drive']['client_secret'],
                       :site => "https://accounts.google.com",
                       :authorize_url => "/o/oauth2/auth",
                       :token_url => "/o/oauth2/token",
                       :additional_parameters => {"access_type" => "offline"})
  end

  def get_user_info(access_token)
    conn = Faraday.new("https://www.googleapis.com/oauth2/v1/userinfo?access_token=#{access_token}")
    response = conn.get
    response = JSON.parse(response.body)
  end

  def get_access_token(access_token)
    begin
      # Get the current token hash
      # token_hash = JSON.parse(access_token)
      token = OAuth2::AccessToken.from_hash(client, access_token) rescue nil
      renew_token_if_expired(token) if token
    rescue OAuth2::Error => oe
      render json: { message: "#{oe.message}" }, status: :unprocessable_entity
    end
  end

  def authentication_session(args={})
    token = get_refresh_token(args[:refresh_token])
    if token
      token_hash = JSON.parse(token.to_json)
      access_token = OAuth2::AccessToken.from_hash(client, token_hash.dup)
      # access_token.refesh! if Time.now.to_i > access_token.expires_at
      GoogleDrive.login_with_oauth(access_token)
    end
  end

  # Gets the current access token
  def get_refresh_token(refresh_token)
    params = {
        client_id: AppConfig.integrations['team_drive']['client_id'],
        client_secret: AppConfig.integrations['team_drive']['client_secret'],
        refresh_token: refresh_token,
        grant_type: 'refresh_token',
        additional_parameters: {"access_type" => "offline"}
      }
    conn = Faraday.new('https://accounts.google.com')
    response = conn.post do |req|
      req.url '/o/oauth2/token'
      req.headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }
      req.body = params
    end
    response = JSON.parse(response.body)
    OAuth2::AccessToken.new(client, response["access_token"])
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

  def get_team_drive_content(drive_sesion)
      query = params[:folder_id] ? "'#{params[:folder_id]}'" : "'#{params[:drive_id]}'"
      paginated_files = []
      begin
        (files, page_token) = drive_sesion.files(q: "#{query} in parents",
                    supports_team_drives: true,
                    team_drive_id: params[:drive_id],
                    include_team_drive_items: true,
                    corpora: 'teamDrive',
                    orderBy: "folder",
                    page_token: page_token)
        paginated_files.concat(files)
      end while page_token
      return paginated_files
    end

  def source_params
    params.permit(:state, :provider_id, :drive_id, :client_host, :source_type_id, :organization_id, :utf8, :authenticity_token, :commit, folders: {})
  end

end
