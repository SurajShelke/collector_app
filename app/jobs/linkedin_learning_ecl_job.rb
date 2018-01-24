class LinkedinLearningEclJob < BaseEclJob
  sidekiq_options queue: :linkedin_learning_ecl_job

  def content_integration
    'LinkedinLearningIntegration'
  end
end
