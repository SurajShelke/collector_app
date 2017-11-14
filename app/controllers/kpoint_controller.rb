class KpointController < ApplicationController

  skip_before_action :verify_authenticity_token

  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

  def index
    begin
      @auth_token = params[:auth_token]
    rescue StandardError => he
      redirect_to authorize_kpoint_index_path
    end
  end

  def authorize
    state_params = {
      auth_data: params[:auth_data],
      secret: params[:secret]
    }.to_json
    # send client_host, organization_id, and source_type_id in state param
    state_params = Base64.urlsafe_encode64(state_params)
    redirect_to "#{AppConfig.integrations['kpoint']['request_uri']}/api/v1/oauth2/authorize?client_id=#{AppConfig.integrations['kpoint']['client_id']}&response_type=token&redirect_uri=#{AppConfig.integrations['kpoint']['redirect_uri']}"
  end

  def callback_extended
    auth_token = CGI.parse(CGI::unescapeHTML(params[:auth_params]))["access_token"].first
    unless auth_token
      render json: { message: "Invalid user" }, status: :unprocessable_entity
    else
      redirect_to kpoint_index_url(auth_token: auth_token)
    end
  end

  def sync_kapsules
    auth_token = params[:auth_token]
    if auth_token
      begin
        KpointIntegration.fetch_content(auth_token)
      end
    end
    # urlsafe_encode64
    # render :action => 'index'
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
    else
      @unauthorized_parameters = true
    end
  end

  def source_params
    params.permit(:state, :provider_id, :request_uri, :source_type_id, :organization_id, :utf8, :authenticity_token, :commit, folders: {})
  end

end
