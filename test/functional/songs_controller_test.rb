require File.dirname(__FILE__) + '/../test_helper'
require 'songs_controller'

# Re-raise errors caught by the controller.
class SongsController; def rescue_action(e) raise e end; end

class SongsControllerTest < Test::Unit::TestCase
  def setup
    @controller = SongsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
