require "json"
require "net/http"
require "portico"

module Portico
  # Talks to the Caddy admin API. The only state lives in Caddy: one route per host,
  # identified by "@id": "portico:<host>", inserted before the fallback route.
  class CaddyClient
    ROUTES = "/config/apps/http/servers/portico/routes".freeze

    attr_reader :admin

    def initialize(admin: ENV.fetch("PORTICO_CADDY_ADMIN", "http://localhost:2019"))
      @admin = admin
    end

    def reachable?
      request(Net::HTTP::Get.new("/config/"), timeout: 1).code == "200"
    rescue SystemCallError, IOError, Timeout::Error
      false
    end

    def upstream_port(host)
      response = request(Net::HTTP::Get.new(id_path(host)))
      return nil if response.code == "404"

      ensure_success!(response)
      dial = JSON.parse(response.body).dig("handle", 0, "upstreams", 0, "dial")
      dial && Integer(dial.split(":").last)
    end

    def register(host:, port:)
      unregister(host)
      route = {
        "@id" => route_id(host),
        "match" => [{ "host" => [host] }],
        "handle" => [{ "handler" => "reverse_proxy", "upstreams" => [{ "dial" => "127.0.0.1:#{port}" }] }],
        "terminal" => true
      }
      put = Net::HTTP::Put.new("#{ROUTES}/0", "Content-Type" => "application/json")
      put.body = JSON.generate(route)
      ensure_success!(request(put))
    end

    def unregister(host)
      response = request(Net::HTTP::Delete.new(id_path(host)))
      ensure_success!(response) unless response.code == "404"
    end

    private

    def route_id(host) = "portico:#{host}"
    def id_path(host) = "/id/#{route_id(host)}"

    def request(req, timeout: 5)
      uri = URI(@admin)
      Net::HTTP.start(uri.host, uri.port, open_timeout: timeout, read_timeout: timeout) { |http| http.request(req) }
    end

    def ensure_success!(response)
      return if response.code.start_with?("2")

      raise Error, "portico: Caddy の管理 API が #{response.code} を返しました: #{response.body}"
    end
  end
end
