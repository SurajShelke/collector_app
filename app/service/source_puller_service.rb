class SourcePullerService

  attr_accessor :source_type_id

  def initialize(source_type_id)
    @source_type_id = source_type_id
  end

  def fetch_sources_by_source_type
    offset = 0

    while offset
      params = {
        limit: 10,
        offset: offset*10
      }

      sources = SourceType.get_sources(source_type_id, params)

      if sources.present?
        sources.each do |source|
          yield source
        end
        offset += 1
      else
        break
      end
    end

  end

end
