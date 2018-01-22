class SharepointOnpremCommunicator

  def initialize(user_name, password, sharepoint_url, site_name = "")
    @user_name = user_name
    @password = password
    @sharepoint_url = sharepoint_url
    @site_name = site_name
  end

  def get_sites
    site = get_site(true)
    response = site.query(:get, "webinfos", nil, true)
    @sites = JSON.parse(response)["d"]["results"]
    @sites.unshift({"Title" => site.url[0..-2], "ServerRelativeUrl" => "/"})
  end

  def get_root_folders
    site = get_site
    response = site.query(:get, "GetFolderByServerRelativeUrl('#{URI.encode('Shared Documents')}')?$expand=Folders", nil, true)
    folders = JSON.parse(response)["d"]["Folders"]["results"].select {|f| f unless ["Attachments", "Item", "Forms"].include?(f["Name"])}
    folders.unshift({"ServerRelativeUrl" => "/Shared Documents", "Name" => "Shared Documents"})
  end

  def get_content_by_folder_relative_url(folder_relative_url)
    get_site.query(:get, "GetFolderByServerRelativeUrl('#{URI.encode(folder_relative_url)}')")
  end

  def get_file_meta_data(file_relative_url)
    response = get_site.query(:get, "GetFileByServerRelativeUrl('#{URI.encode(file_relative_url)}')/ListItemAllFields", nil, true)
    JSON.parse(response)
  end

  # def get_file_permission(file_permission_url)
  #   site = get_site
  #   response = site.query(:get, file_permission_url, nil, true)
  #   response = JSON.parse(response)["d"]["results"]
  #   permissions = []
  #   response.each do |entry|
  #     member = site.query(:get, entry["Member"]["__deferred"]["uri"], nil, true)
  #     member = JSON.parse(member)
  #     role_definition = site.query(:get, entry["RoleDefinitionBindings"]["__deferred"]["uri"], nil, true)
  #     role_definition = JSON.parse(role_definition)
  #     roles = []
  #     role_definition["d"]["results"].each do |entry|
  #       roles << {:name => entry["Name"], :id => entry["Id"], :RoleTypeKind => entry["RoleTypeKind"]}
  #     end
  #     permissions << {
  #       :type => member["d"]["__metadata"]["type"],
  #       :name => member["d"]["LoginName"],
  #       :email => member["d"]["RequestToJoinLeaveEmailSetting"],
  #       :roles => roles
  #     }
  #   end
  #   permissions
  # end

  def get_site(is_root = false)
    root_site_name = is_root ? "" : @site_name
    uri = URI(@sharepoint_url)
    site = Sharepoint::Site.new uri.host, URI.encode(root_site_name)
    site.session = Sharepoint::HttpAuth::Session.new site
    site.session.authenticate @user_name, @password
    site.protocole = uri.scheme
    site
  end

  def current_user
    get_site.query(:get, "CurrentUser")
  end

  def update_relative_url(folders)
    site = get_site
    new_folders = {}
    folders.each do |folder_relative_url, folder_name|
      response = site.query(:get, "GetFolderByServerRelativeUrl('#{URI.encode(folder_relative_url)}')/ListItemAllFields", nil, true)
      response = JSON.parse(response)
      if response["d"]["Id"]
        new_folders[folder_relative_url] = { :name => folder_name, :id => response["d"]["Id"] }
      else
        new_folders[folder_relative_url] = { :name => folder_name, :id => @site_name }
      end
    end
    new_folders
  end

end
