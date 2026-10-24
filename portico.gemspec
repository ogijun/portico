require_relative "lib/portico/version"

Gem::Specification.new do |spec|
  spec.name = "portico"
  spec.version = Portico::VERSION
  spec.authors = ["Junya Ogino"]
  spec.email = ["ogijun@gmail.com"]

  spec.summary = "Open your local Rails apps at https://<name>.test, in front of puma, via Caddy."
  spec.homepage = "https://github.com/ogijun/portico"
  spec.required_ruby_version = ">= 3.3"

  spec.files = Dir["lib/**/*.rb", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "puma", ">= 8.0"
end
