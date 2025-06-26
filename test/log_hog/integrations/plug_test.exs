defmodule LogHog.Integrations.PlugTest do
  use LogHog.Case, async: true

  @moduletag capture_log: true, config: [capture_level: :error]

  setup {LoggerHandlerKit.Arrange, :ensure_per_handler_translation}
  setup :setup_supervisor
  setup :setup_logger_handler

  defmodule MyRouter do
    use Plug.Router
    require Logger

    plug(LogHog.Integrations.Plug)
    plug(:match)
    plug(:dispatch)

    forward("/", to: LoggerHandlerKit.Plug)
  end

  test "sets relevant context" do
    conn = Plug.Test.conn(:get, "https://posthog.com/foo?bar=10")
    assert LogHog.Integrations.Plug.call(conn, nil)

    assert LogHog.Context.get() == %{
             "$current_url": "https://posthog.com/foo?bar=10",
             "$host": "posthog.com",
             "$ip": "127.0.0.1",
             "$pathname": "/foo"
           }
  end

  describe "Bandit" do
    test "context is attached to exceptions", %{handler_ref: ref, sender_pid: sender_pid} do
      LoggerHandlerKit.Act.plug_error(:exception, Bandit, MyRouter)
      LoggerHandlerKit.Assert.assert_logged(ref)
      LoggerHandlerKit.Assert.assert_logged(ref)

      assert %{events: [event]} = :sys.get_state(sender_pid)

      assert %{
               event: "$exception",
               properties: properties
             } = event

      assert %{
               "$current_url": "http://localhost/exception",
               "$host": "localhost",
               "$ip": "127.0.0.1",
               "$pathname": "/exception",
               "$lib": "LogHog",
               "$lib_version": _,
               "$exception_list": [
                 %{
                   type: "RuntimeError",
                   value: "** (RuntimeError) oops",
                   mechanism: %{handled: false, type: "generic"},
                   stacktrace: %{type: "raw", frames: _frames}
                 }
               ]
             } = properties
    end

    test "context is attached to throws", %{handler_ref: ref, sender_pid: sender_pid} do
      LoggerHandlerKit.Act.plug_error(:throw, Bandit, MyRouter)
      LoggerHandlerKit.Assert.assert_logged(ref)
      LoggerHandlerKit.Assert.assert_logged(ref)

      assert %{events: [event]} = :sys.get_state(sender_pid)

      assert %{
               event: "$exception",
               properties: properties
             } = event

      assert %{
               "$current_url": "http://localhost/throw",
               "$host": "localhost",
               "$ip": "127.0.0.1",
               "$pathname": "/throw",
               "$lib": "LogHog",
               "$lib_version": _,
               "$exception_list": [
                 %{
                   type: "** (throw) \"catch!\"",
                   value: "** (throw) \"catch!\"",
                   mechanism: %{handled: false, type: "generic"},
                   stacktrace: %{type: "raw", frames: _frames}
                 }
               ]
             } = properties
    end

    test "context is attached to exit", %{handler_ref: ref, sender_pid: sender_pid} do
      LoggerHandlerKit.Act.plug_error(:exit, Bandit, MyRouter)
      LoggerHandlerKit.Assert.assert_logged(ref)
      LoggerHandlerKit.Assert.assert_logged(ref)

      assert %{events: [event]} = :sys.get_state(sender_pid)

      assert %{
               event: "$exception",
               properties: properties
             } = event

      assert %{
               "$current_url": "http://localhost/exit",
               "$host": "localhost",
               "$ip": "127.0.0.1",
               "$pathname": "/exit",
               "$lib": "LogHog",
               "$lib_version": _,
               "$exception_list": [
                 %{
                   type: "** (exit) \"i quit\"",
                   value: "** (exit) \"i quit\"",
                   mechanism: %{handled: false, type: "generic"}
                 }
               ]
             } = properties
    end
  end

  describe "Cowboy" do
    test "context is attached to exceptions", %{handler_ref: ref, sender_pid: sender_pid} do
      LoggerHandlerKit.Act.plug_error(:exception, Plug.Cowboy, MyRouter)
      LoggerHandlerKit.Assert.assert_logged(ref)

      assert %{events: [event]} = :sys.get_state(sender_pid)

      assert %{
               event: "$exception",
               properties: properties
             } = event

      assert %{
               "$current_url": "http://localhost/exception",
               "$host": "localhost",
               "$ip": "127.0.0.1",
               "$pathname": "/exception",
               "$lib": "LogHog",
               "$lib_version": _,
               "$exception_list": [
                 %{
                   type: "RuntimeError",
                   value: "** (RuntimeError) oops",
                   mechanism: %{handled: false, type: "generic"},
                   stacktrace: %{type: "raw", frames: _frames}
                 }
               ]
             } = properties
    end

    test "context is attached to throws", %{handler_ref: ref, sender_pid: sender_pid} do
      LoggerHandlerKit.Act.plug_error(:throw, Plug.Cowboy, MyRouter)
      LoggerHandlerKit.Assert.assert_logged(ref)

      assert %{events: [event]} = :sys.get_state(sender_pid)

      assert %{
               event: "$exception",
               properties: properties
             } = event

      assert %{
               "$current_url": "http://localhost/throw",
               "$host": "localhost",
               "$ip": "127.0.0.1",
               "$pathname": "/throw",
               "$lib": "LogHog",
               "$lib_version": _,
               "$exception_list": [
                 %{
                   type: "** (throw) \"catch!\"",
                   value: "** (throw) \"catch!\"",
                   mechanism: %{handled: false, type: "generic"},
                   stacktrace: %{type: "raw", frames: _frames}
                 }
               ]
             } = properties
    end

    test "context is attached to exit", %{handler_ref: ref, sender_pid: sender_pid} do
      LoggerHandlerKit.Act.plug_error(:exit, Plug.Cowboy, MyRouter)
      LoggerHandlerKit.Assert.assert_logged(ref)

      assert %{events: [event]} = :sys.get_state(sender_pid)

      assert %{
               event: "$exception",
               properties: properties
             } = event

      assert %{
               "$current_url": "http://localhost/exit",
               "$host": "localhost",
               "$ip": "127.0.0.1",
               "$pathname": "/exit",
               "$lib": "LogHog",
               "$lib_version": _,
               "$exception_list": [
                 %{
                   type: "** (exit) \"i quit\"",
                   value: "** (exit) \"i quit\"",
                   mechanism: %{handled: false, type: "generic"}
                 }
               ]
             } = properties
    end
  end
end
