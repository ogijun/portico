require "portico/version"

module Portico
  class Error < StandardError; end
  class HostTaken < Error; end
end

require "portico/railtie" if defined?(Rails::Railtie)
