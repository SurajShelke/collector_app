require 'test_helper'

class JobPostsControllerTest < ActionDispatch::IntegrationTest
  test "should get feed" do
    get job_posts_feed_url
    assert_response :success
  end

end
