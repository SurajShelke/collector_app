require 'csv'
require 'net/sftp'

OpenURI::Buffer.send :remove_const, 'StringMax' if OpenURI::Buffer.const_defined?('StringMax')
OpenURI::Buffer.const_set 'StringMax', 0

class SftpCsvParser
  attr_accessor :delimiter, :server_ip, :server_encrypted_password, :server_username, :server_folder_path

  def initialize(delimiter: ',', server_ip:, server_encrypted_password:, server_username:, server_folder_path:)
    @delimiter = delimiter
    @server_ip = server_ip
    @server_encrypted_password = server_encrypted_password
    @server_username =  server_username
    @server_folder_path = server_folder_path
  end

  def fetch_courses(options = {})
    courses = []
    decoded_pswd = Base64.decode64(server_encrypted_password)
    sftp = Net::SFTP.start(server_ip, server_username, password: decoded_pswd)
    return unless sftp
    begin
      sftp.dir.foreach(server_folder_path) do |entry|
        if entry.file? && entry.name.end_with?('csv')
          # ONLY CSV ALLOWED
          data = sftp.download!("#{server_folder_path}/#{entry.name}")
          options = { headers: true, header_converters: :symbol, col_sep: ',' }
          CSV.parse(data, options) do |row|
            courses << row.to_hash
          end
          courses.delete_if(&:blank?)
        end
      end
      courses
    rescue StandardError => e
      raise Webhook::Error::IntegrationFailure, "SFTP: Failed Integration while connecting to remote server #{server_ip}, ErrorMessage: #{e.message}"
    end
  end
end
