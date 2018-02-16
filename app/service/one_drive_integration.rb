class OneDriveIntegration < SharepointIntegration
  def self.get_source_name
    'one_drive'
  end

  def self.get_fetch_content_job_queue
    :one_drive
  end
end
