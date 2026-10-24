require "test_helper"
require "portico/registration"

class RegistrationTest < Minitest::Test
  FakeClient = Struct.new(:port) do
    def upstream_port(_host) = port
  end

  def test_claims_over_dead_upstream
    Portico::Registration.check!("demo.test", client: FakeClient.new(45678), alive: ->(_) { false })
  end

  def test_refuses_live_upstream
    error = assert_raises(Portico::HostTaken) do
      Portico::Registration.check!("demo.test", client: FakeClient.new(45678), alive: ->(_) { true })
    end
    assert_includes error.message, "demo.test"
    assert_includes error.message, "45678"
  end

  def test_allows_own_port
    Portico::Registration.check!("demo.test", client: FakeClient.new(45678), alive: ->(_) { true }, own_port: 45678)
  end

  def test_free_host
    Portico::Registration.check!("demo.test", client: FakeClient.new(nil), alive: ->(_) { flunk "alive should not be called" })
  end

  def test_tcp_alive_detects_listener
    server = TCPServer.new("127.0.0.1", 0)
    assert Portico::Registration::TCP_ALIVE.(server.addr[1])
    port = server.addr[1]
    server.close
    refute Portico::Registration::TCP_ALIVE.(port)
  end
end
