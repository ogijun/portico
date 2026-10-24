require "test_helper"
require "portico/identity"
require "portico/rails_settings"

class RailsSettingsTest < Minitest::Test
  ASOBO = Portico::Identity.new(name: "asobo", host: "asobo.test", worktree: nil)
  TOMINOCLE = Portico::Identity.new(name: "tominocle-pre", host: "tominocle-pre.test", worktree: nil)

  def test_defaults_to_https
    settings = Portico::RailsSettings.for(ASOBO, env: {})
    assert_equal "https://asobo.test", settings[:app_base_url]
    assert_equal true, settings[:assume_ssl]
    assert_equal ["asobo.test", ".asobo.test"], settings[:hosts]
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
    assert_equal false, settings[:assume_ssl]
  end

  def test_explicit_https_base_url
    settings = Portico::RailsSettings.for(ASOBO, env: { "APP_BASE_URL" => "https://asobo.test" })
    assert_equal true, settings[:assume_ssl]
  end

  def test_empty_base_url_counts_as_unset
    assert_equal "https://asobo.test", Portico::RailsSettings.for(ASOBO, env: { "APP_BASE_URL" => "" })[:app_base_url]
  end
end
