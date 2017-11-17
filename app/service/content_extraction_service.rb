module ContentExtractionService
  # extracts text from over a thousand different file types (such as PPT, XLS, and PDF).
  # Reference : https://tika.apache.org/
  def get_file_content(file_path)
    data = `#{java} -jar #{Rails.root.to_path}/vendor/tika-app-1.14.jar -t "#{file_path}"`
    data[0...AppConfig.max_file_content_size]
  end

  def java
    ENV['JAVA_HOME'] ? ENV['JAVA_HOME'] + '/bin/java' : 'java'
  end
end 