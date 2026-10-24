require "test_helper"
require "portico/identity"

class IdentityTest < Minitest::Test
  def app(dir_name: "app", mod: nil, config: nil, git: :dir)
    root = File.join(@tmp, dir_name)
    FileUtils.mkdir_p(File.join(root, "config"))
    File.write(File.join(root, "config/application.rb"), "module #{mod}\n  class Application; end\nend\n") if mod
    File.write(File.join(root, "config/portico.yml"), config) if config
    case git
    when :dir then FileUtils.mkdir_p(File.join(root, ".git"))
    when :file then File.write(File.join(root, ".git"), "gitdir: /x/.git/worktrees/1\n")
    end
    root
  end

  def setup = @tmp = Dir.mktmpdir
  def teardown = FileUtils.rm_rf(@tmp)

  def test_name_from_application_module
    id = Portico::Identity.resolve(app(mod: "TeamWiki"))
    assert_equal "team-wiki.test", id.host
    assert_nil id.worktree
  end

  def test_host_from_config_file
    id = Portico::Identity.resolve(app(mod: "TeamWiki", config: "host: tominocle-pre\n"))
    assert_equal "tominocle-pre.test", id.host
  end

  def test_linked_worktree
    id = Portico::Identity.resolve(app(dir_name: "galeocerdo", mod: "Asobo", git: :file))
    assert_equal "galeocerdo.asobo.test", id.host
    assert_equal "galeocerdo", id.worktree
  end

  def test_main_checkout
    assert_nil Portico::Identity.resolve(app(mod: "Asobo", git: :dir)).worktree
  end

  def test_name_normalization
    assert_equal "my-api.test", Portico::Identity.resolve(app(dir_name: "a", mod: "MyAPI")).host
    assert_equal "foo-bar.test", Portico::Identity.resolve(app(dir_name: "b", mod: "Foo_Bar")).host
    assert_equal "tominocle-pre.test", Portico::Identity.resolve(app(dir_name: "c", config: "host: Tominocle-Pre\n")).host
    assert_equal "tominocle-pre.test", Portico::Identity.resolve(app(dir_name: "d", config: "host: tominocle-pre.test\n")).host
  end

  def test_missing_application_raises
    error = assert_raises(Portico::Error) { Portico::Identity.resolve(app) }
    assert_includes error.message, "config/portico.yml"
  end
end
