class GoogleTeamDriveController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :get_access_token, only: [:callback]
  before_action :verify_referer, only: [:authorize]

  def authorize
    state_params = {
      auth_data: params[:auth_data],
      secret: params[:secret]
    }.to_json

    get_client.auth_code.authorize_url(
      redirect_uri: AppConfig.google_team_drive_redirect_uri,
      scope: Google::Apis::DriveV3::AUTH_DRIVE_READONLY,
      access_type: "offline",
      approval_prompt: 'force',
      state: state_params
    )
  end

  def callback
    begin
      # generate client object using access token
      @client = DropboxApi::Client.new(@access_token)

      # fetch user account details
      user_account = @client.get_current_account

      # save user details with identity provider and redirect to list folder UI
      if user_account.present?
        user = User.create_or_update_dropbox_user(user_account, @access_token)
        redirect_to fetch_folders_dropbox_index_path(
          email: user.email,
          state: params[:state]
        )
      end
    rescue DropboxApi::Errors::HttpError => he
      render json: { message: "#{he.message}" }, status: :unprocessable_entity
    end
  end

  def fetch_folders
    # fetch dropbox access token using email param
    dropbox_access_token = IdentityProvider.get_dropbox_access_token(params[:email])

    if dropbox_access_token
      begin
        client = DropboxApi::Client.new(dropbox_access_token)
        result = client.list_folder('', recursive: true)

        if result.instance_values['data']
          # show only folders list
          @folders = result.instance_values['data']['entries'].select{|c| c[".tag"] == 'folder'}
        end
      rescue DropboxApi::Errors::HttpError => he
        redirect_to authorize_dropbox_index_path
      end
    else
      render json: { folders: [], email: params[:email], message: 'Invalid user' }, status: :unprocessable_entity
    end
  end

  def create_sources
    dropbox_access_token = IdentityProvider.get_dropbox_access_token(params[:email])

    if dropbox_access_token
      begin
        decrypt_state

        if @unauthorized_parameters
          render json: { message: 'Unauthorized parameters' }, status: :unauthorized
        else
          service = SourceCreationService.new(
            folders:         source_params[:folders] || [],
            access_token:    dropbox_access_token,
            email:           params[:email],
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

  def get_access_token
    begin
      @access_token = get_client.auth_code.get_token(
        params[:code],
        { redirect_uri: AppConfig.google_team_drive_redirect_uri, token_method: :post }
      )
    rescue OAuth2::Error => oe
      render json: { message: "#{oe.message}" }, status: :unprocessable_entity
    end
  end

  def verify_referer
    # check referer TODO
  end

  def get_client
    @client ||= OAuth2::Client.new(
      AppConfig.google_team_drive_client_id,
      AppConfig.google_team_drive_client_secret,
      site: "https://accounts.google.com",
      authorize_url: "/o/oauth2/auth",
      token_url: "/o/oauth2/token",
      additional_parameters: { "access_type" => "offline" })
  end
end
