class Source
  # Get Source  based on id
  def self.find(source_id)
    communicator = EclCommunicator.new
    response = communicator.establish_connection("api/developer/v1/sources/#{source_id}")
    response.success? ? communicator.response_data["data"] : {}
  end

  def self.fetch_content(source_id)
    source = find(source_id)
    if source.present?
      DropboxContentCollectorJob.perform_async(
        source_id:       source['id'],
        last_polled_at:  source['last_polled_at'],
        organization_id: source['organization_id'],
        source_config:   source['source_config']
      )
    end
  end
end
