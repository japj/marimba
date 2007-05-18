require File.dirname(__FILE__) + '/../test_helper'
require 'play_lists_controller'

# Re-raise errors caught by the controller.
class PlayListsController; def rescue_action(e) raise e end; end

class PlayListsControllerTest < Test::Unit::TestCase
  def setup
    @controller = PlayListsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
