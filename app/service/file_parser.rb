class FileParser
  attr_accessor :url, :root_element, :file_type

  #root_element is the node key in case of xml and for json it can be optional
  def initialize(url: , root_element:, file_type:, file_source:)
    @url = url
    @root_element = root_element
    @file_type = file_type
    @file_source = file_source
  end

  def parse_content
    file_content, data = read_file, []
    return [] if file_content.nil?
    case @file_type
    when 'json'
      data = @root_element.present? ? JSON.parse(file_content)[@root_element] : JSON.parse(file_content)
    when 'xml'
      data = Hash.from_xml(file_content)[@root_element]
    else
      []
    end
    data
  end

  def read_file
    case @file_source
    #[TODO] Testing purpose will remove in final commit
    when 'local'
      File.read(@url)
  	when 'remote'
      open(@url).read
    end
  end
end
