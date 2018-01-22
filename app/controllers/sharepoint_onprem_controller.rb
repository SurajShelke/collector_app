require 'sharepoint-http-auth'

class SharepointOnpremController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_referer, only: [:authorize]

  def authorize
    @state = {
      auth_data: params[:auth_data],
      secret: params[:secret]
    }.to_json
  end

  def fetch_folders
    @provider = IdentityProvider.get_sharepoint_onprem_provider(params[:provider_id])
    if @provider
      decrypt_state(@provider.auth_info, @provider.secret)
      if @unauthorized_parameters
        render json: { message: 'Unauthorized parameters' }, status: :unauthorized
      else
        auth_data = decode_credentials(source_params['client_secret'])
        @client_secret = source_params['client_secret']
        @site_name = source_params['site_name']
        communicator = SharepointOnpremCommunicator.new(auth_data['user_name'], auth_data['password'], @sharepoint_url, @site_name)
        @sites = communicator.get_sites
        @folders = communicator.get_root_folders
        @root_id = "/Shared Documents"
      end
    else
      render json: { folders: [], provider_id: params[:provider_id], message: 'Invalid user' }, status: :unprocessable_entity
    end
  end

  def fetch_sites
    state_data = JSON.parse(source_params[:state])
    decrypt_state(state_data["auth_data"], state_data['secret'])
    encode_credentials(source_params[:user_name], source_params[:password])
    if @unauthorized_parameters
      render json: { message: 'Unauthorized parameters' }, status: :unauthorized
    else
      begin
        communicator = SharepointOnpremCommunicator.new(source_params[:user_name], source_params[:password], @sharepoint_url)
        current_user = communicator.current_user
        @provider = User.create_or_update_sharepoint_onprem_user(current_user.id, state_data[:user_name], state_data["auth_data"], state_data['secret'])
        if @provider
          @sites = communicator.get_sites
        end
      rescue Exception => he
        flash[:error] = "username or password is invalid"
        redirect_to authorize_sharepoint_onprem_index_path(
          auth_data: state_data["auth_data"],
          secret: state_data['secret']
        )
      end
    end
  end

  def create_sources
    begin
      provider = IdentityProvider.get_sharepoint_onprem_provider(params[:provider_id])
      if provider
        decrypt_state(provider.auth_info, provider.secret)
        if @unauthorized_parameters
          render json: { message: 'Unauthorized parameters' }, status: :unauthorized
        else
          @site_name = source_params['site_name']
          auth_data = decode_credentials(source_params['client_secret'])
          communicator = SharepointOnpremCommunicator.new(auth_data['user_name'], auth_data['password'], @sharepoint_url, @site_name)
          folders = communicator.update_relative_url(source_params[:folders])
          service = SharepointOnpremSourceCreationService.new(
            AppConfig.integrations['sharepoint_onprem']['ecl_client_id'],
            AppConfig.integrations['sharepoint_onprem']['ecl_token'],
            folders:          folders || [],
            organization_id:  @organization_id,
            source_type_id:   @source_type_id,
            provider_id:      provider.id,
            client_secret:    JWT.encode({user_name: auth_data['user_name'], password: auth_data['password']}, AppConfig.digest_secret, 'HS256' ),
            site_name:        @site_name
          )
          service.create_sources
          redirect_to "#{@client_host}/admin/integrations/eclConfigurations"
        end
      else
        render json: { folders: [], provider_id: params[:provider_id], message: 'Invalid user' }, status: :unprocessable_entity
      end
    rescue => e
      render json: { message: 'Invalid or bad parameters' }, status: :unprocessable_entity
    end
  end

  private

  def source_params
    params.permit(:state, :client_secret, :user_name , :password, :auth_data, :site_name, :secret, folders: {})
  end

  def decrypt_state(auth_data, secret)
    decrypted_data = JSON.parse(Base64.decode64(auth_data))

    digest  = OpenSSL::Digest.new('sha256')
    calculated_secret = OpenSSL::HMAC.hexdigest(digest, AppConfig.digest_secret, auth_data)

    # check integrity of params passed
    if calculated_secret == secret
      @client_host     = decrypted_data['client_host']
      @organization_id = decrypted_data['organization_id']
      @source_type_id  = decrypted_data['source_type_id']
      @sharepoint_url  = decrypted_data['sharepoint_url']
    else
      @unauthorized_parameters = true
    end
  end
  
  def encode_credentials(user_name, password)
    @client_secret = JWT.encode({user_name: user_name, password: password}, AppConfig.digest_secret, 'HS256' )
  end
  
  def decode_credentials(auth_data)
    JWT.decode(auth_data, AppConfig.digest_secret, { :algorithm => 'HS256' })[0]
  end
  def verify_referer
    # check referer TODO
  end
  
end