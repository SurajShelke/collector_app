class SkillSoftEclJob < BaseEclJob
  sidekiq_options queue: :skill_soft_ecl_job

  def content_integration
  	'SkillSoftIntegration'
  end
end