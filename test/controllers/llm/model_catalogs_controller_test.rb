require "test_helper"

class Llm::ModelCatalogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "updates the model catalog" do
    refreshed = false

    RubyLLM.models.stub(:refresh, -> { refreshed = true }) do
      patch model_catalog_path
    end

    assert refreshed
    assert_redirected_to models_path
  end
end
