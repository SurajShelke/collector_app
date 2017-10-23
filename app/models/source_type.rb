class SourceType
  # Get Source Type Name
  def self.get_source_type_by_name(source_type_name,options={})
    params = { name: source_type_name }
    params[:limit]  = options[:limit] || 10
    params[:offset] = options[:offset] || 0

    communicator = EclCommunicator.new
    response = communicator.establish_connection('api/developer/v1/source_types', params)
    response.success? ? communicator.response_data["data"] : []
  end


  # Get Source Type based on id
  def self.find(source_type_id)
    communicator = EclCommunicator.new
    response = communicator.establish_connection("api/developer/v1/source_types/#{source_type_id}")
    response.success? ? communicator.response_data["data"] : {}
  end

  # Get Sources for given source type id
  # Default @options ={limit=>0,offset=>10}
  def self.get_sources(source_type_id, options= {limit: 10, offset: 0})
    options[:source_type_id] = source_type_id
    communicator = EclCommunicator.new
    response = communicator.establish_connection("api/developer/v1/sources", options)
    response.success? ? communicator.response_data["data"] : []
  end

  def self.fetch_content(source_type_id)
    DropboxCollectorJob.perform_async(source_type_id)
  end
end
