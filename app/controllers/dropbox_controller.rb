class DropboxController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :get_access_token, only: [:callback]

  def authorize
    # send client_host, organization_id, and source_type_id in state param
    state_params = CGI.escape({
      organization_id: params[:organization_id],
      source_type_id: params[:source_type_id],
      client_host: params[:client_host]
    }.to_json)

    redirect_to "https://www.dropbox.com/oauth2/authorize?state=#{state_params}&client_id=#{AppConfig.client_id}&response_type=code&redirect_uri=#{AppConfig.redirect_uri}"
  end

  def callback
    begin
      # decode state params
      state_params = JSON.parse(params[:state])

      # generate client object using access token
      @client = DropboxApi::Client.new(@access_token)

      # fetch user account details
      user_account = @client.get_current_account

      # save user details with identity provider and redirect to list folder UI
      if user_account.present?
        user = User.create_or_update_dropbox_user(user_account, @access_token)
        redirect_to fetch_folders_dropbox_index_path(
          email: user.email,
          organization_id: state_params['organization_id'],
          source_type_id: state_params['source_type_id'],
          client_host: state_params['client_host']
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
      service = SourceCreationService.new(
        source_type_id:  source_params[:source_type_id],
        organization_id: source_params[:organization_id],
        folders:         source_params[:folders],
        access_token:    dropbox_access_token,
        email:           params[:email]
        )
      service.create_sources

      redirect_to "https://#{params[:client_host]}/admin/integrations/eclConfigurations"
    else
      render json: { message: 'Invalid access token' }, status: :unprocessable_entity
    end
  end

  private

  def source_params
    params.permit(:source_type_id, :organization_id, folders: {})
  end

  def get_access_token
    begin
      authenticator = DropboxApi::Authenticator.new(AppConfig.client_id, AppConfig.client_secret)
      auth_bearer = authenticator.get_token(params[:code], redirect_uri: AppConfig.redirect_uri)

      @access_token = auth_bearer.token
    rescue OAuth2::Error => oe
      render json: { message: "#{oe.message}" }, status: :unprocessable_entity
    end
  end
end
