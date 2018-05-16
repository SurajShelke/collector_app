class FileParser
	attr_accessor :url, :root_element, :file_type

  def initialize(url: , root_element:, file_type:)
    @url = url
    @root_element = root_element
    @file_type = file_type
	end

	def parse_content
		file_content, data = File.read(@url), []
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
end