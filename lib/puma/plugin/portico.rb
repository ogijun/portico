require "puma/plugin"
require "portico"
require "portico/identity"
require "portico/caddy_client"
require "portico/registration"
require "portico/free_port"

# `plugin :portico` in config/puma.rb.
# Puma calls #start before it opens any socket, so the binds can still be replaced here.
Puma::Plugin.create do
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

    Portico::Registration.check!(identity.host, client:)

    port = Portico.free_port
    launcher.options[:binds] = ["tcp://127.0.0.1:#{port}"]

    launcher.events.after_booted do
      client.register(host: identity.host, port:)
      log.("portico: https://#{identity.host} (→ 127.0.0.1:#{port})")
    end
    launcher.events.after_stopped { client.unregister(identity.host) }
  end
end
