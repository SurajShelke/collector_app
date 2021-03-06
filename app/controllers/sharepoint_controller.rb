class SharepointController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :get_access_token_details, only: [:callback]
  before_action :verify_referer, only: [:authorize]

  MICROSOFT_ONE_DRIVE = "ms_onedrive"
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
          decrypt_state
          if @unauthorized_parameters
            render json: { message: 'Unauthorized parameters' }, status: :unauthorized
          else
            if @integration == MICROSOFT_ONE_DRIVE
              redirect_to fetch_drives_sharepoint_index_path(
                provider_id: provider.id,
                state: @state
              )
            else
              redirect_to fetch_sites_sharepoint_index_path(
                provider_id: provider.id,
                state: @state
              )
            end
          end
        else
          render json: { message: "Record cannot be processed" }, status: :unprocessable_entity
        end
      end
    rescue Exception => he
      render json: { message: "#{he.message}" }, status: :unprocessable_entity
    end
  end

  def failure
    render json: { message: "#{params[:message]}" }, status: :unprocessable_entity
  end

  def fetch_sites
    begin
      sharepoint_communicator = create_sharepoint_communicator(params[:provider_id])
      @sites = sharepoint_communicator.folders("/v1.0/sites",{:search => '*'})["value"]
    rescue Exception => he
      Rails.logger.error "Invalid Oauth2 token, #{he.message}"
      redirect_to authorize_sharepoint_index_path
    end
  end
  
  def create_sharepoint_communicator(provider_id)
    record = IdentityProvider.find_by(id: provider_id)
    if record
      sharepoint_communicator = SharepointCommunicator.new(
                client_id:     AppConfig.integrations['sharepoint']['client_id'],
                client_secret: AppConfig.integrations['sharepoint']['client_secret'],
                token:         record.token
              )
    else
      raise "Invalid token, please contact administrator."
    end
  end

  def fetch_drives
    begin
      decrypt_state
      if @unauthorized_parameters
        render json: { message: 'Unauthorized parameters' }, status: :unauthorized
      else
        site = source_params[:site]
        if site
          site = JSON.parse(site)
          @site_id = site["id"]
          @site_name = site["name"]
          sharepoint_communicator = create_sharepoint_communicator(params[:provider_id])
          @sites = sharepoint_communicator.folders("/v1.0/sites",{:search => '*'})["value"]
          @drives = sharepoint_communicator.folders("/v1.0/sites/#{@site_id}/drives")["value"]
        else
          sharepoint_communicator = create_sharepoint_communicator(params[:provider_id])

          if @integration == MICROSOFT_ONE_DRIVE
            @drives = sharepoint_communicator.folders("/v1.0/me/drives")["value"]
          else
            @site_id = source_params[:site_id]
            if @site_id
              @sites = sharepoint_communicator.folders("/v1.0/sites",{:search => '*'})["value"]
              @drives = sharepoint_communicator.folders("/v1.0/sites/#{@site_id}/drives")["value"]
            else
              render json: { message: 'Failed to get site information, Please contact administrator' }, status: :unprocessable_entity
            end
          end
        end
      end
    rescue Exception => he
      Rails.logger.error "Invalid Oauth2 token, #{he.message}"
      redirect_to authorize_sharepoint_index_path
    end
  end

  def fetch_folders
    begin
      decrypt_state
      if @unauthorized_parameters
        render json: { message: 'Unauthorized parameters' }, status: :unauthorized
      else
        sharepoint_communicator = create_sharepoint_communicator(params[:provider_id])
        @site_id = source_params[:site_id]
        @site_name = source_params[:site_name]
        @drive_id = source_params[:drive_id]
        if @drive_id
          @folders = sharepoint_communicator.folders("/v1.0/drives/#{@drive_id}/root/children")["value"]
          @folders = @folders.select {|folder| folder["folder"]}
          if @integration == MICROSOFT_ONE_DRIVE
            @drives = sharepoint_communicator.folders("/v1.0/me/drives")["value"]
          else
            @site_id = source_params[:site_id]
            @sites = sharepoint_communicator.folders("/v1.0/sites",{:search => '*'})["value"]
            @drives = sharepoint_communicator.folders("/v1.0/sites/#{@site_id}/drives")["value"] if @site_id
          end  
          # Adding root folder to the folders list, so that files inside root folder can be synced. In Sharepoint instance, root folder is typically named as 'Shared Document'.
          @folders.unshift({"id" => @drive_id, "name" => "Shared Documents"})
        else
          render json: { message: 'Failed to get drive information, Please contact administrator' }, status: :unprocessable_entity
        end
      end
    rescue Exception => he
      Rails.logger.error "Invalid Oauth2 token, #{he.message}"
      redirect_to authorize_sharepoint_index_path
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
            drive_id:        source_params[:drive_id],
            organization_id: @organization_id,
            source_type_id:  @source_type_id,
            # extract_content: @extract_content,
            site_name:       source_params[:site_name]
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
    params.permit(:state, :site, :site_id, :site_name, :drive_id, :provider_id, folders: {})
  end

  def decrypt_state
    @state = @state || source_params[:state]
    state_data = JSON.parse(@state)
    decrypted_data = JSON.parse(Base64.decode64(state_data["auth_data"]))

    digest  = OpenSSL::Digest.new('sha256')
    calculated_secret = OpenSSL::HMAC.hexdigest(digest, AppConfig.digest_secret, state_data['auth_data'])
    # check integrity of params passed
    if calculated_secret == state_data['secret']
      @client_host     = decrypted_data['client_host']
      @organization_id = decrypted_data['organization_id']
      @source_type_id  = decrypted_data['source_type_id']
      # @extract_content = decrypted_data['extract_content']
      @integration     = decrypted_data['integration']
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
