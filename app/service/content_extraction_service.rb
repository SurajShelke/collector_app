module ContentExtractionService
  # extracts text from over a thousand different file types (such as PPT, XLS, and PDF).
  # Reference : https://tika.apache.org/
  # file_path is either local file system path or you can also specify the URL of a document to be parsed.
  def get_file_content(file_path)
  	begin
  		data = `#{java} -jar #{Rails.root.to_path}/vendor/tika-app-1.14.jar -t "#{file_path}"`
  		data[0...AppConfig.max_file_content_size]
  	rescue Exception => e
      Rails.logger.error "unable to get content for file name : #{name}\nfile_path : #{file_path}"
    end
  end

  def java
    ENV['JAVA_HOME'] ? ENV['JAVA_HOME'] + '/bin/java' : 'java'
  end
end