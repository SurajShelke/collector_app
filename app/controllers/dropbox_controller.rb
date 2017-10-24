class DropboxController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :get_access_token, only: [:callback]
  before_action :verify_referer, only: [:authorize]

  def authorize
    state_params = {
      auth_data: params[:auth_data],
      secret: params[:secret]
    }.to_json

    redirect_to "https://www.dropbox.com/oauth2/authorize?state=#{state_params}&client_id=#{AppConfig.dropbox['client_id']}&response_type=code&redirect_uri=#{AppConfig.dropbox['redirect_uri']}"
  end

  def callback
    begin
      # generate client object using access token
      @client = DropboxApi::Client.new(@access_token)

      # fetch user account details
      user_account = @client.get_current_account

      # save user details with identity provider and redirect to list folder UI
      if user_account.present?
        provider = User.create_or_update_dropbox_user(user_account, @access_token)

        if provider
          redirect_to fetch_folders_dropbox_index_path(
            provider_id: provider.id,
            state: params[:state]
          )
        else
          render json: { message: "Record cannot be processed" }, status: :unprocessable_entity
        end
      end
    rescue DropboxApi::Errors::HttpError => he
      render json: { message: "#{he.message}" }, status: :unprocessable_entity
    end
  end

  def fetch_folders
    # fetch dropbox access token using email param
    dropbox_access_token = IdentityProvider.get_dropbox_access_token(params[:provider_id])

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
      render json: { folders: [], provider_id: params[:provider_id], message: 'Invalid user' }, status: :unprocessable_entity
    end
  end

  def create_sources
    dropbox_access_token = IdentityProvider.get_dropbox_access_token(params[:provider_id])

    if dropbox_access_token
      begin
        decrypt_state

        if @unauthorized_parameters
          render json: { message: 'Unauthorized parameters' }, status: :unauthorized
        else
          service = DropboxSourceCreationService.new(
            AppConfig.dropbox['ecl_client_id'],
            AppConfig.dropbox['ecl_token'],
            folders:         source_params[:folders] || [],
            access_token:    dropbox_access_token,
            organization_id: @organization_id,
            source_type_id:  @source_type_id
            )
          binding.pry
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
      authenticator = DropboxApi::Authenticator.new(AppConfig.dropbox['client_id'], AppConfig.dropbox['client_secret'])
      auth_bearer = authenticator.get_token(params[:code], redirect_uri: AppConfig.dropbox['redirect_uri'])
      @access_token = auth_bearer.token
    rescue OAuth2::Error => oe
      render json: { message: "#{oe.message}" }, status: :unprocessable_entity
    end
  end

  def verify_referer
    # check referer TODO
  end
end
