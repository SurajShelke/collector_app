class DropboxIntegration < BaseIntegration
  attr_accessor :client,:source_id,:organization_id
  def self.get_source_name
    'dropbox'
  end

  def self.get_fetch_content_job_queue
    :dropbox
  end

  def self.get_credentials_from_config(source)
    source["source_config"]
  end

  def self.ecl_client_id
    AppConfig.dropbox['ecl_client_id']
  end

  def self.ecl_token
    AppConfig.dropbox['ecl_token']
  end

  # 
  #  @options ={start: start, limit: limit, page: page, last_polled_at: @last_polled_at}
  #  We dont need start or limit for this Integration 
  #  Whenever pagination is available we can use it
  def get_content(options={})
    @options = options
    @client          = DropboxApi::Client.new(@credential['access_token'])
    @source_id       = @credential["source_id"]
    @organization_id = @credential["organization_id"]
    fetch_content(@credential['folder_id'])
  end

  def fetch_content(folder_id,cursor)
    begin
      if cursor.nil?
        response = @client.list_folder(path: @credential['folder_id'],recursive: true)
        collect_files(response)
      else
        response = @client.list_folder_continue(cursor)
        collect_files(response)
      end
    rescue DropboxApi::Errors::HttpError => e
      logs.error  "Invalid Oauth2 token, #{e.message}"
      nil
    end
    
  end
  
  def collect_files(response)
    response.entries.each do |entry|
    #  Conisder folder has 3 sub folder and 3 file
    #  Create 3 content Item and spawn 3 different job
    # TODO add code for to check last polled at vs server update 
    # time so we will not have multiple jobs to spawn every time
    if entry.class.to_s == "DropboxApi::Metadata::Folder"
      credential = @credentials
      credential['folder_id'] = entry.id
      Sidekiq::Client.push(
        'class' => FetchContentJob,
        'queue' => self.get_fetch_content_job_queue.to_s,
        'args' => [self.class.to_s, credential, @source_id, @organization_id, @options[:last_polled_at]]
      )
      # Call again background job so current job is finish faster
    elsif entry.class.to_s == "DropboxApi::Metadata::File"
      create_file_as_content_item(entry.path_lower)
    end
  end

 

  def create_file_as_content_item(file_path)
    links = @client.list_shared_links(path: file_path, direct_only: true)

    if links.links.present?
      links.links.map {|link| create_content_item(link.to_hash) }
    else
      logs.error "unable to get shared link for #{file_path}"
    end
  end

 

  def create_content_item(link)
    entry = {
      name:          link['name'],
      description:   link['path_lower'],
      url:           link['url'],
      content_type:  'article',
      external_id:   link['id'],
      raw_record:    link,
      source_id:     @source_id,
      resource_metadata: {
        images:      [{ url: nil }],
        title:       link['name'],
        description: link['path_lower'],
        url:         link['url']
      },

      additional_metadata: {
        path_lower:      link['path_lower'],
        size:            link['size'],
        revision:        link['rev'],
        client_modified: link['client_modified'],
        server_modified: link['server_modified'],
      }
    }

    DropboxContentItemCreationJob.perform_async(@organization_id, entry)
  end

  
  



end