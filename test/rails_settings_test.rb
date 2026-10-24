require "test_helper"
require "portico/identity"
require "portico/rails_settings"

class RailsSettingsTest < Minitest::Test
  ASOBO = Portico::Identity.new(name: "asobo", host: "asobo.test", worktree: nil)
  TOMINOCLE = Portico::Identity.new(name: "tominocle-pre", host: "tominocle-pre.test", worktree: nil)

  def test_defaults_to_https
    settings = Portico::RailsSettings.for(ASOBO, env: {})
    assert_equal "https://asobo.test", settings[:app_base_url]
    assert_equal ["asobo.test", ".asobo.test"], settings[:hosts]
  end

  # https is detected from Caddy's X-Forwarded-Proto. assume_ssl would also turn
  # direct http://localhost:3000 access (Caddy down) into https redirects.
  def test_never_assumes_ssl
    refute Portico::RailsSettings.for(ASOBO, env: {}).key?(:assume_ssl)
  end

  def test_worktree_uses_its_own_host
    wt = Portico::Identity.new(name: "asobo", host: "galeocerdo.asobo.test", worktree: "galeocerdo")
    settings = Portico::RailsSettings.for(wt, env: {})
    assert_equal "https://galeocerdo.asobo.test", settings[:app_base_url]
    assert_includes settings[:hosts], ".asobo.test"
  end

  def test_explicit_http_base_url_is_respected
    settings = Portico::RailsSettings.for(TOMINOCLE, env: { "APP_BASE_URL" => "http://tominocle-pre.test" })
    assert_equal "http://tominocle-pre.test", settings[:app_base_url]
  end

  def test_empty_base_url_counts_as_unset
    assert_equal "https://asobo.test", Portico::RailsSettings.for(ASOBO, env: { "APP_BASE_URL" => "" })[:app_base_url]
  end
end
