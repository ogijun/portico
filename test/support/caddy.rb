require "json"
require "socket"
require "net/http"

# Starts a throwaway Caddy whose config has the same shape as the one in dotfiles
# (server "portico", fallback route last), listening on loopback high ports only.
class TestCaddy
  FALLBACK_BODY = "<p><strong>{http.request.host}</strong> は起動していません。"

  attr_reader :admin_url, :http_port

  def self.available? = system("command -v caddy >/dev/null 2>&1")

  def self.free_port
    server = TCPServer.new("127.0.0.1", 0)
    server.addr[1]
  ensure
    server&.close
  end

  def start
    @dir = Dir.mktmpdir
    admin_port = self.class.free_port
    @http_port = self.class.free_port
    @admin_url = "http://localhost:#{admin_port}"
    fallback = ->(id) { { "@id" => id, "handle" => [{ "handler" => "static_response", "status_code" => 503, "body" => FALLBACK_BODY }] } }
    config = {
      "admin" => { "listen" => "localhost:#{admin_port}" },
      "apps" => { "http" => { "servers" => { "portico" => {
        "listen" => ["127.0.0.1:#{@http_port}"],
        "automatic_https" => { "disable" => true },
        "routes" => [fallback.("portico-fallback")],
        "errors" => { "routes" => [fallback.("portico-fallback-error")] }
      } } } }
    }
    path = File.join(@dir, "caddy.json")
    File.write(path, JSON.generate(config))
    @pid = spawn("caddy", "run", "--config", path, out: File::NULL, err: File.join(@dir, "caddy.log"))
    wait_until { Net::HTTP.get_response(URI("#{@admin_url}/config/")).code == "200" }
    self
  end

  def stop
    Process.kill("TERM", @pid)
    Process.wait(@pid)
    FileUtils.rm_rf(@dir)
  end

  def get(host, path = "/")
    Net::HTTP.start("127.0.0.1", @http_port) { |http| http.get(path, "Host" => host) }
  end

  def routes
    JSON.parse(Net::HTTP.get(URI("#{@admin_url}/config/apps/http/servers/portico/routes")))
  end

  def wait_until(timeout: 10)
    deadline = Time.now + timeout
    loop do
      begin
        return if yield
      rescue SystemCallError, IOError
        nil
      end
      raise "timed out" if Time.now > deadline
      sleep 0.05
    end
  end
end
