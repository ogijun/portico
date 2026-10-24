require "puma/plugin"
require "portico"
require "portico/identity"
require "portico/caddy_client"
require "portico/registration"
require "portico/free_port"

# `plugin :portico` in config/puma.rb.
# Puma calls #start before it opens any socket, so the binds can still be replaced here.
Puma::Plugin.create do
  CADDY_ERRORS = [Portico::Error, SystemCallError, IOError, Timeout::Error, SocketError].freeze

  def start(launcher)
    log = ->(message) { launcher.log_writer.log(message) }

    begin
      identity = Portico::Identity.resolve(Dir.pwd)
    rescue Portico::Error => e
      return log.(e.message)
    end

    client = Portico::CaddyClient.new
    unless client.reachable?
      return log.("portico: Caddy (#{client.admin}) に繋がらないので、通常どおり起動します")
    end

    # On a phased/hot restart (tmp_restart, SIGUSR2) puma re-execs itself and hands the
    # listening socket over. Keep that port: the route in Caddy still points at it.
    port = inherited_port(launcher) || Portico.free_port
    host = identity.host
    Portico::Registration.check!(host, client:, own_port: port)
    launcher.options[:binds] = ["tcp://127.0.0.1:#{port}"]

    launcher.events.after_booted do
      # Another process may have registered while we were booting.
      Portico::Registration.check!(host, client:, own_port: port)
      client.register(host:, port:)
      log.("portico: https://#{host} (→ 127.0.0.1:#{port})")
    rescue Portico::HostTaken => e
      log.(e.message)
      launcher.stop
    rescue *CADDY_ERRORS => e
      log.("portico: Caddy に登録できませんでした (#{e.message})。http://127.0.0.1:#{port} で動いています")
    end

    launcher.events.after_stopped do
      # Only remove the route if it is still ours.
      client.unregister(host) if client.upstream_port(host) == port
    rescue *CADDY_ERRORS => e
      log.("portico: Caddy から登録を外せませんでした (#{e.message})")
    end
  end

  private

  def inherited_port(launcher)
    launcher.binder.inherited_fds.each_key do |url|
      port = url[%r{\Atcp://127\.0\.0\.1:(\d+)\z}, 1]
      return Integer(port) if port
    end
    nil
  end
end
