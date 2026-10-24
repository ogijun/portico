require "socket"

module Portico
  # A TCP port on 127.0.0.1 that nothing is listening on right now.
  def self.free_port
    server = TCPServer.new("127.0.0.1", 0)
    server.addr[1]
  ensure
    server&.close
  end
end
