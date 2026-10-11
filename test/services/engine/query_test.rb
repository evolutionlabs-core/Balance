require "test_helper"

class Engine::QueryTest < ActiveSupport::TestCase
  test "Engine.read returns the not-implemented stub contract" do
    result = Engine.read({})

    assert_equal "error", result[:status]
    assert_equal "NOT_IMPLEMENTED", result[:code]
    assert_equal 501, result[:http_status]
    assert_equal "read path not implemented yet", result[:message]
    assert_equal [], result[:errors]
    assert_equal({}, result[:details])
    assert_nothing_raised { Time.iso8601(result[:timestamp]) }
  end

  test "Engine::Query.call returns the not-implemented stub contract" do
    result = Engine::Query.call({})

    assert_equal "error", result[:status]
    assert_equal "NOT_IMPLEMENTED", result[:code]
    assert_equal 501, result[:http_status]
    assert_equal "read path not implemented yet", result[:message]
    assert_equal [], result[:errors]
    assert_equal({}, result[:details])
    assert_nothing_raised { Time.iso8601(result[:timestamp]) }
  end
end
