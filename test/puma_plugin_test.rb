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

  def test_survives_tmp_restart
    File.write(File.join(@app, "config/puma.rb"), "port #{FIXED_PORT}\nplugin :tmp_restart\nplugin :portico\n")
    restart_txt = File.join(@app, "tmp/restart.txt")
    FileUtils.mkdir_p(File.dirname(restart_txt))
    FileUtils.touch(restart_txt, mtime: Time.now - 60) # tmp_restart remembers the first mtime it sees
    log = start_puma
    wait_for(log, "https://demo.test")
    sleep 3 # let tmp_restart's 2-second poll record the old mtime
    FileUtils.touch(restart_txt)
    @caddy.wait_until(timeout: 20) { File.read(log, encoding: "UTF-8").scan("https://demo.test").size >= 2 }
    assert_equal "hello demo", @caddy.get("demo.test").body
    refute_includes File.read(log, encoding: "UTF-8"), "は別のプロセス"
  end

  def test_stop_keeps_route_of_another_process
    log = start_puma
    wait_for(log, "https://demo.test")
    client.register(host: "demo.test", port: 45678) # someone else took the host over
    pid = @pids.pop
    Process.kill("INT", pid)
    Process.wait(pid)
    assert_equal 45678, client.upstream_port("demo.test")
  end

  def test_stop_with_caddy_down_exits_cleanly
    log = start_puma
    wait_for(log, "https://demo.test")
    @caddy.stop
    @caddy = nil
    pid = @pids.pop
    Process.kill("INT", pid)
    Process.wait(pid)
    output = File.read(log, encoding: "UTF-8")
    assert $?.success?, output
    refute_match(/ECONNREFUSED/, output)
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
    # On restart puma resets ENV to Bundler's ORIGINAL_ENV. Spawn from a clean env so the
    # child's "original" env is the one above, not this test process's pre-bundler env.
    @pids << Bundler.with_unbundled_env do
      spawn(env, "bundle", "exec", "puma", "-C", "config/puma.rb", chdir: @app, out: log, err: [:child, :out])
    end
    log
  end

  def wait_for(log, text)
    @caddy.wait_until(timeout: 20) { File.exist?(log) && File.read(log).include?(text) }
  rescue RuntimeError
    flunk "puma の出力に #{text} が出なかった:\n#{File.read(log)}"
  end
end
