require "test_helper"

class PorticoTest < Minitest::Test
  def test_version
    refute_nil Portico::VERSION
  end
end
