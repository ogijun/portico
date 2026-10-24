require "portico/identity"
require "portico/rails_settings"

module Portico
  class Railtie < ::Rails::Railtie
    initializer "portico", before: :load_environment_config do |app|
      next unless ::Rails.env.development?

      settings = RailsSettings.for(Identity.resolve(app.root.to_s))
      app.config.hosts.concat(settings[:hosts])
      ENV["APP_BASE_URL"] = settings[:app_base_url]
      app.config.assume_ssl = settings[:assume_ssl]
    rescue Portico::Error => e
      warn e.message
    end
  end
end
