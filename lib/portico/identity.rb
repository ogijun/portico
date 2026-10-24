require "yaml"
require "portico"

module Portico
  # Decides the hostname of the app at `root` by reading files only.
  # Loads neither Rails nor Puma, so it can run before either.
  Identity = Data.define(:name, :host, :worktree) do
    def self.resolve(root)
      name = configured_host(root) || module_name(root) ||
        raise(Error, "portico: #{root} からホスト名を決められません。config/portico.yml に host: を書いてください")
      worktree = File.file?(File.join(root, ".git")) ? normalize(File.basename(root)) : nil
      host = [worktree, name, "test"].compact.join(".")
      new(name:, host:, worktree:)
    end

    def self.configured_host(root)
      path = File.join(root, "config/portico.yml")
      return unless File.exist?(path)

      host = YAML.safe_load_file(path)&.fetch("host", nil)
      host && normalize(host.to_s.delete_suffix(".test"))
    end

    def self.module_name(root)
      path = File.join(root, "config/application.rb")
      return unless File.exist?(path)

      mod = File.read(path)[/^module\s+(\w+)/, 1]
      mod && normalize(mod.gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1-\2').gsub(/([a-z\d])([A-Z])/, '\1-\2'))
    end

    # Lowercase letters, digits and hyphens only, so the result is a valid DNS label.
    def self.normalize(label)
      label.downcase.tr("_", "-").gsub(/[^a-z0-9-]/, "").squeeze("-").delete_prefix("-").delete_suffix("-")
    end
  end
end
