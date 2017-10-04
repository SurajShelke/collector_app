module Collector
  class Error < StandardError
    def initialize(message = '')
      puts "#{exception.class} - #{message}"
      # Bugsnag.notify("#{exception} - #{message}")
      super(message)
    end

    # Invalid Cerdentials | Invalid Content | Content Parsing Error
    InvalidContent = Class.new(Error)

    # Integration implementation error
    IntegrationFailure = Class.new(Error)

    # ECL content-item creation error
    ContentCreationFailure = Class.new(Error)
  end

  class NoContentException < StandardError
  end
end
