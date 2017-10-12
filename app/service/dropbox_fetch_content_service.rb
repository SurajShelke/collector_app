class DropboxFetchContentService
  def initialize(options = {})
    @client          = DropboxApi::Client.new(options[:source_config]['access_token'])
    @source_id       = options[:source_id]
    @organization_id = options[:organization_id]
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

  def collect_files(folder_id, cursor= nil)
    folder_data = list_folder(folder_id, cursor)

    if folder_data
      folder_data.instance_values["data"]["entries"].each do |entry|
        if entry['.tag'] == 'file'
          create_file_as_content_item(entry['path_lower'])
        elsif entry['.tag'] == 'folder'
          collect_files(entry['id'])
        end
      end

      collect_files(folder_id, folder_data.cursor) if folder_data.has_more?
    end
  end

  def list_folder(folder_id, cursor)
    begin
      if cursor.nil?
        folder = @client.list_folder(folder_id)
      else
        folder = @client.list_folder_continue(cursor)
      end
    rescue DropboxApi::Errors::HttpError => e
      puts "Invalid Oauth2 token, #{e.message}"
      nil
    end
  end

  def create_file_as_content_item(file_path)
    links = @client.list_shared_links(path: file_path, direct_only: true)

    if links.instance_values["data"]["links"].present?
      create_content_item(links.instance_values["data"]["links"].first)
    else
      puts "unable to get shared link for #{file_path}"
    end
  end

  def fetch_latest_cursor_and_collect_files(folder_id)
    response = @client.list_folder_get_latest_cursor(path: folder_id)
    response.try(:cursor).present? ? collect_files(folder_id, response.cursor) : collect_files(folder_id)
  end
end
