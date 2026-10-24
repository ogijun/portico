module Portico
  module RailsSettings
    # What portico changes in a development Rails app, as plain data.
    # An APP_BASE_URL the app already sets (e.g. in .env) always wins.
    #
    # No assume_ssl: Caddy sends X-Forwarded-Proto, which Rack already honours, so a
    # request through https://<host> is https and one through http:// stays http.
    # assume_ssl would also rewrite direct http://localhost access (Caddy down) to https.
    def self.for(identity, env: ENV)
      base_url = env["APP_BASE_URL"].to_s
      base_url = "https://#{identity.host}" if base_url.empty?
      {
        hosts: [identity.host, ".#{identity.name}.test"].uniq,
        app_base_url: base_url
      }
    end
  end
end
