require "test_helper"
require "support/caddy"
require "portico/caddy_client"
require "portico/registration"

# End-to-end: a real puma with `plugin :portico`, behind a real Caddy.
class PumaPluginTest < Minitest::Test
  GEMFILE = File.expand_path("../Gemfile", __dir__)
  FIXED_PORT = 3999

  def setup
    skip "caddy not installed" unless TestCaddy.available?
    @caddy = TestCaddy.new.start
    @app = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@app, "config"))
    File.write(File.join(@app, "config/application.rb"), "module Demo\nend\n")
    File.write(File.join(@app, "config.ru"), "run ->(_) { [200, {}, ['hello demo']] }\n")
    File.write(File.join(@app, "config/puma.rb"), "port #{FIXED_PORT}\nplugin :portico\n")
    @pids = []
  end

  def teardown
    @pids.each do |pid|
      Process.kill("INT", pid)
      Process.wait(pid)
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end
    @caddy&.stop
    FileUtils.rm_rf(@app) if @app
  end

  def test_serves_through_caddy
    log = start_puma
    wait_for(log, "https://demo.test")
    assert_equal "hello demo", @caddy.get("demo.test").body
    refute Portico::Registration::TCP_ALIVE.(FIXED_PORT), "外から渡したポートで待ち受けてはいけない"
  end

  def test_unregisters_on_stop
    log = start_puma
    wait_for(log, "https://demo.test")
    pid = @pids.pop
    Process.kill("INT", pid)
    Process.wait(pid)
    assert_nil client.upstream_port("demo.test")
  end

  def test_aborts_when_host_taken
    wait_for(start_puma, "https://demo.test")
    second = start_puma
    pid = @pids.pop
    Process.wait(pid)
    refute $?.success?
    assert_includes File.read(second, encoding: "UTF-8"), "は別のプロセス"
  end

  def test_caddy_down_leaves_binds_untouched
    log = start_puma(admin: "http://localhost:#{TestCaddy.free_port}")
    @caddy.wait_until { Portico::Registration::TCP_ALIVE.(FIXED_PORT) }
    body = Net::HTTP.get(URI("http://127.0.0.1:#{FIXED_PORT}/"))
    assert_equal "hello demo", body
    assert_equal 1, File.read(log).lines.count { _1.start_with?("portico:") }
  end

  private

  def client = Portico::CaddyClient.new(admin: @caddy.admin_url)

  def start_puma(admin: @caddy.admin_url)
    log = File.join(@app, "puma-#{@pids.size}.log")
    env = { "BUNDLE_GEMFILE" => GEMFILE, "PORTICO_CADDY_ADMIN" => admin }
    @pids << spawn(env, "bundle", "exec", "puma", "-C", "config/puma.rb", chdir: @app, out: log, err: [:child, :out])
    log
  end

  def wait_for(log, text)
    @caddy.wait_until(timeout: 20) { File.exist?(log) && File.read(log).include?(text) }
  rescue RuntimeError
    flunk "puma の出力に #{text} が出なかった:\n#{File.read(log)}"
  end
end
