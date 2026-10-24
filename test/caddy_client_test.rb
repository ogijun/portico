require "test_helper"
require "support/caddy"
require "portico/caddy_client"

class CaddyClientTest < Minitest::Test
  def setup
    skip "caddy not installed" unless TestCaddy.available?
    @caddy = TestCaddy.new.start
    @client = Portico::CaddyClient.new(admin: @caddy.admin_url)
  end

  def teardown
    @caddy&.stop
    @app&.close
  end

  def test_register_then_lookup
    @client.register(host: "demo.test", port: 45678)
    assert_equal 45678, @client.upstream_port("demo.test")
  end

  def test_register_routes_traffic
    port = start_app("OK demo")
    @client.register(host: "demo.test", port:)
    assert_equal "OK demo", @caddy.get("demo.test").body
  end

  def test_unregistered_host_gets_fallback
    response = @caddy.get("nothing.test")
    assert_equal "503", response.code
    assert_includes response.body.force_encoding("UTF-8"), "nothing.test</strong> は起動していません"
  end

  def test_register_twice_replaces
    @client.register(host: "demo.test", port: 45678)
    @client.register(host: "demo.test", port: 45679)
    assert_equal 45679, @client.upstream_port("demo.test")
    assert_equal 1, @caddy.routes.count { _1["@id"] == "portico:demo.test" }
  end

  def test_unregister_removes_route
    @client.register(host: "demo.test", port: 45678)
    @client.unregister("demo.test")
    assert_nil @client.upstream_port("demo.test")
  end

  def test_unregister_missing_is_noop
    @client.unregister("missing.test")
    assert_nil @client.upstream_port("missing.test")
  end

  def test_reachable
    assert @client.reachable?
  end

  def test_unreachable
    refute Portico::CaddyClient.new(admin: "http://localhost:#{TestCaddy.free_port}").reachable?
  end

  private

  # A minimal HTTP server answering every request with `body`.
  def start_app(body)
    @app = TCPServer.new("127.0.0.1", 0)
    Thread.new do
      loop do
        conn = @app.accept
        conn.gets("\r\n\r\n")
        conn.write("HTTP/1.1 200 OK\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
        conn.close
      rescue IOError
        break
      end
    end
    @app.addr[1]
  end
end
