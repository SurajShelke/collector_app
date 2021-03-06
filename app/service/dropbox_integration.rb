class DropboxIntegration < BaseIntegration
  attr_accessor :client
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
    AppConfig.integrations['dropbox']['ecl_client_id']
  end

  def self.ecl_token
    AppConfig.integrations['dropbox']['ecl_token']
  end

  def get_content(options={})
    @options         = options
    @client          = DropboxApi::Client.new(@credentials['access_token'])
    fetch_content(@credentials['folder_id'])
  end

  def fetch_content(folder_id)
    begin
      cursor = @options[:page] == 0 ? nil : @options[:page]
      if cursor.nil?
        response = @client.list_folder(folder_id, recursive: true)
        collect_files(response)
      else
        response = @client.list_folder_continue(cursor)
        collect_files(response)
      end

      # send response.cursor as page param in other FetchContentJob
      if response.has_more?
        Sidekiq::Client.push(
          'class' => FetchContentJob,
          'queue' => self.class.get_fetch_content_job_queue.to_s,
          'args'  => [self.class.to_s, @credentials, @credentials["source_id"],@credentials["organization_id"], options[:last_polled_at], response.cursor],
          'at'    => self.class.schedule_at
        )
      end
    rescue DropboxApi::Errors::HttpError => e
      Rails.logger.error "Invalid Oauth2 token, #{e.message}"
      nil
    end
  end

  def collect_files(response)
    response.entries.each do |entry|
      #  Conisder folder has 3 sub folder and 3 file
      #  Create 3 content Item and spawn 3 different job
      # TODO add code for to check last polled at vs server update - 1 days so we will not fetched lot of data
      # time so we will not have multiple jobs to spawn every time
      if entry.class.to_s == "DropboxApi::Metadata::Folder"
        credentials = @credentials

        # check for subfolders only
        if credentials['folder_id'] != entry.id
          credentials['folder_id'] = entry.id

          # Call again background job so current job is finish faster
          Sidekiq::Client.push(
            'class' => FetchContentJob,
            'queue' => self.class.get_fetch_content_job_queue.to_s,
            'args' => [self.class.to_s, credentials, credentials["source_id"], credentials["organization_id"], @options[:last_polled_at]],
            'at' => self.class.schedule_at
          )
        end
      elsif entry.class.to_s == "DropboxApi::Metadata::File"
        create_file_as_content_item(entry.path_lower)
      end
    end
  end

  def create_file_as_content_item(file_path)
    links = @client.list_shared_links(path: file_path, direct_only: true)

    if links.links.present?
      links.links.map {|link| create_content_item(link.to_hash) }
    else
      Rails.logger.error "unable to get shared link for #{file_path}"
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
      source_id:     @credentials['source_id'],
      organization_id: @credentials['organization_id'],
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

    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, entry)
  end
end
