# frozen_string_literal: true

require "abstract_unit"
require "console_helpers"
require "plugin_helpers"

class Rails::Engine::CommandsTest < ActiveSupport::TestCase
  include ConsoleHelpers
  include PluginHelpers

  def setup
    @destination_root = Dir.mktmpdir("bukkits")
    generate_plugin("#{@destination_root}/bukkits", "--mountable")
  end

  def teardown
    FileUtils.rm_rf(@destination_root)
  end

  def test_help_command_work_inside_engine
    output = capture(:stderr) do
      in_plugin_context(plugin_path) { `bin/rails --help` }
    end
    assert_no_match "NameError", output
  end

  def test_runner_command_work_inside_engine
    output = capture(:stdout) do
      in_plugin_context(plugin_path) { system({ "RAILS_ENV" => "test" }, "bin/rails runner 'puts Rails.env'") }
    end

    assert_equal "test", output.strip
  end

  if available_pty?
    def test_console_command_work_inside_engine
      primary, replica = PTY.open
      cmd = "console --singleline"
      spawn_command(cmd, replica)
      assert_output(">", primary)
    ensure
      primary.puts "quit"
    end

    def test_dbconsole_command_work_inside_engine
      primary, replica = PTY.open
      spawn_command("dbconsole", replica)
      assert_output("sqlite>", primary)
    ensure
      primary.puts ".exit"
    end

    def test_server_command_work_inside_engine
      primary, replica = PTY.open
      pid = spawn_command("server", replica)
      assert_output("Listening on", primary)
    ensure
      kill(pid)
    end
  end

  private
    def plugin_path
      "#{@destination_root}/bukkits"
    end

    def spawn_command(command, fd)
      in_plugin_context(plugin_path) do
        Process.spawn("bin/rails #{command}", in: fd, out: fd, err: fd)
      end
    end

    def kill(pid)
      Process.kill("TERM", pid)
      Process.wait(pid)
    rescue Errno::ESRCH
    end
end
