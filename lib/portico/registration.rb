require "socket"
require "portico"

module Portico
  module Registration
    # Is something listening on 127.0.0.1:port right now?
    TCP_ALIVE = lambda do |port|
      Socket.tcp("127.0.0.1", port, connect_timeout: 0.2).close
      true
    rescue SystemCallError, IOError
      false
    end

    # Refuses to take a host whose current upstream is still alive.
    # A dead upstream (left behind by kill -9) is fine to take over.
    def self.check!(host, client:, alive: TCP_ALIVE)
      port = client.upstream_port(host)
      return if port.nil? || !alive.(port)

      raise HostTaken, "portico: #{host} は別のプロセス (127.0.0.1:#{port}) が使っています。" \
                       "そちらを止めるか、config/portico.yml で host を変えてください"
    end
  end
end
