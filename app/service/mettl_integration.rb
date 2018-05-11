# {    "status": "SUCCESS",
#     "assessment": {
#         "id": 4107,
#         "duration": 50,
#  "testsTaken": 0, //No. of candidates who have taken the test
#         "name": "Aptitude Test",
#         "instructions": "",
#  “defaultinstructions”:"<h2><b>Things to remember</b></h2><ul style="list-style-type:decimal;margin: 10px
# 20px;"><li>To ensure an uninterrupted test-taking experience, you may close all chats, screen-saver etc before
# starting the test.</li><li>Do not press "F5" during the test at any time as doing so will cause your test to finish
# abruptly.</li><li>Please make sure that you have a steady internet connection before taking the test.</li><li>In
# case your test suddenly shuts off due to power supply being disconnected you can restart from where you left
# off (with your previous answers saved) within a few minutes. You need to follow the same steps to start your
# test as now and use the same registration details.</li></ul><div class="section-duration">TEST DETAILS<br
# /><table class="table"><tr><th>Section Name</th><th>No. of Questions</th><th>Time Limit
# (Mins)</th></tr><tr><td>Section #1</td><td>1</td><td>Untimed*</td></tr><tr><td>Section
# #2</td><td>1</td><td>Untimed*</td></tr></table>*Untimed: These sections are without any specific time
# limit. You can answer these sections within the total assessment time limit.<br />i.e Total Time of Untimed
# Sections = Total Time of Test - Total Time of Timed Sections<br /><b>Total Test Duration:</b> 90
# Mins</div>",
#  "allowCopyPaste" : false,
#  "exitRedirectionURL" : null,
#  ​"customAssessmentName": "{assessment-name} for {schedule-name}" ​ //It is the name provided by a client
#  "showReportToCandidateOnExit" : false,
#  "onScreenCalculator" : false,
#  "fixedSectionOrder": true
#  "createdAt": "Thu, 14 Jun 2012 12:43:56 GMT",
#         "maxMarks": 125.0, //Depends on the marks allotted for correct and incorrect grade(Auto
# Calculated)
#             "markingScheme": "FIXED", //Fixed or Dynamic
#         "sections": [
#             {
#                 "name": "Section #1",
#                 "instructions": "",
#                 "duration": 0,
#                 "isTimed": false,
#  "order": 1
#  "randomizeQuestions": false
#  "randomizeOptions": false
#  "allQuestionsMandatory": false
#                 "skills": [
#                     {
#                         "name": "Quantitative Aptitude",
#                         "level": "EASY",
#                         "questionCount": 10,
#                         "source": "Mettl",
#                         "questionType": MCQ, //Possible question types: AllType or MCQ, CODE, FITB,
#  LONG_ANSWER, MCA, SQL, SHORT_ANSWER, CS, CP,
#  FES, TS, FU
#                         "duration": 15,
#                         "correctGrade": 1.0,
#                         "incorrectGrade": -0.0
#                     } ]
#  "skills": [
#  { "name": "Sample Topic",
#  "level": "EASY",
#   "questionCount": 1,
#  "source": "Custom",
#  "questionType": "AllType",
#  "duration": 0,
#  "correctGrade": 1,
# "incorrectGrade": 0,
#  "questionPooling": true}
# ]}
#             }
#         ],
#         "registrationFields": [
#             {   "name": "Email Address",
#                 "type": "TextBox",
#                 "required": true,
#                 "validate": false,
#                 "values": []
#             },
#             {
#                 "name": "First Name",
#                 "type": "TextBox",
#                 "required": true,
#                 "validate": false
#             },
#            {    "name": "Gender",
#                 "type": "SelectBox",
#                 "required": false,
#                 "validate": false,
#                 "values": [“Male”, “Female”]
#             }
#         ]
#  assessmentPerformanceCategory": { // THESE ARE DEFINED BY THE USER
#  "version": 1
#  "performanceCategories": [
#  "Pass", "Fail" ]}
# }
#     }
# }

class MettlIntegration < BaseIntegration
  def self.get_source_name
    'mettl'
  end

  def self.get_fetch_content_job_queue
    :mettl
  end

  def self.get_credentials_from_config
    source["source_config"]
  end

  def self.ecl_client_id
    SourceTypeConfig.find_by(source_type_name: 'mettl').values['ecl_client_id']
  end

  def self.ecl_token
    SourceTypeConfig.find_by(source_type_name: 'mettl').values['ecl_token']
  end

  def get_content(options={})
    begin
      if @credentials['host_url'].present?
        data = json_request(
          "#{@credentials['host_url']}",
          :get,
          headers: { 'Content-Type' => 'application/json' },
          params: delta_params
        )

        data['assessments'].each { |entry| create_content_item(entry) }
      end
    rescue StandardError => err
      raise Webhook::Error::IntegrationFailure, "[MettlIntegration] Failed Integration for source #{@credentials['source_id']}, ErrorMessage: #{err.message}"
    end
  end

  def create_content_item(entry)
    ContentItemCreationJob.perform_async(self.class.ecl_client_id, self.class.ecl_token, content_item_attributes(entry))
  end

  def content_item_attributes(entry)
    description = sanitize_content(entry['instructions'])
    url = CGI.unescape(entry['exitRedirectionURL'])

    {
      external_id:     entry['id'],
      source_id:       @credentials["source_id"],
      name:            entry['name'],
      description:     description,
      content_type:   'article',
      organization_id: @credentials["organization_id"],

      resource_metadata: {
        title:         entry['name'],
        url:           url,
        description:   description
      },

      additional_metadata: {
        default_instructions: entry['defaultinstructions'],
        custom_assessment_name: entry['customAssessmentName'],
        created_at: entry['created_at'],
        sections: entry['sections'],
        registration_fields: entry['registrationFields'],
        allow_copy_paste: entry['allowCopyPaste'],
        show_report_to_candidate_on_exit: entry['showReportToCandidateOnExit']
      }
    }
  end

  def delta_params
    {}
  end

end