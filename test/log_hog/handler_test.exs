defmodule LogHog.HandlerTest do
  use ExUnit.Case, async: true

  import Mox
  alias LogHog.API
  require Logger

  @moduletag capture_log: true

  setup_all {LoggerHandlerKit.Arrange, :ensure_per_handler_translation}

  setup :verify_on_exit!

  setup %{test: test} do
    stub_with(API.Mock, API.Stub)

    config =
      LogHog.Config.validate!(
        public_url: "https://us.i.posthog.com",
        api_key: "my_api_key",
        api_client_module: LogHog.API.Mock
      )

    {context, on_exit} =
      LoggerHandlerKit.Arrange.add_handler(
        test,
        LogHog.Handler,
        config
      )

    on_exit(on_exit)
    context
  end

  test "takes distinct_id from metadata", %{handler_ref: ref} do
    expect(API.Mock, :request, fn _client, method, url, opts ->
      assert method == :post
      assert url == "/i/v0/e"

      assert opts[:json] == %{
               event: "$exception",
               properties: %{
                 distinct_id: "foo",
                 "$exception_list": [
                   %{
                     type: "Hello World",
                     value: "Hello World",
                     mechanism: %{handled: true, type: "generic"},
                     stacktrace: %{}
                   }
                 ]
               }
             }

      {:ok, %{}}
    end)

    Logger.info("Hello World", distinct_id: "foo")
    LoggerHandlerKit.Assert.assert_logged(ref)
  end

  test "string message", %{handler_ref: ref} do
    expect(API.Mock, :request, fn _client, method, url, opts ->
      assert method == :post
      assert url == "/i/v0/e"

      assert %{
               event: "$exception",
               properties: %{
                 "$exception_list": [
                   %{
                     type: "Hello World",
                     value: "Hello World",
                     mechanism: %{handled: true}
                   }
                 ]
               }
             } = opts[:json]

      {:ok, %{}}
    end)

    LoggerHandlerKit.Act.string_message()
    LoggerHandlerKit.Assert.assert_logged(ref)
  end

  test "charlist message", %{handler_ref: ref} do
    expect(API.Mock, :request, fn _client, method, url, opts ->
      assert method == :post
      assert url == "/i/v0/e"

      assert %{
               event: "$exception",
               properties: %{
                 "$exception_list": [
                   %{
                     type: "Hello World",
                     value: "Hello World",
                     mechanism: %{handled: true}
                   }
                 ]
               }
             } = opts[:json]

      {:ok, %{}}
    end)

    LoggerHandlerKit.Act.charlist_message()
    LoggerHandlerKit.Assert.assert_logged(ref)
  end

  test "chardata message", %{handler_ref: ref} do
    expect(API.Mock, :request, fn _client, method, url, opts ->
      assert method == :post
      assert url == "/i/v0/e"

      assert %{
               event: "$exception",
               properties: %{
                 "$exception_list": [
                   %{
                     type: "Hello World",
                     value: "Hello World",
                     mechanism: %{handled: true}
                   }
                 ]
               }
             } = opts[:json]

      {:ok, %{}}
    end)

    LoggerHandlerKit.Act.chardata_message(:proper)
    LoggerHandlerKit.Assert.assert_logged(ref)
  end

  test "chardata message - improper", %{handler_ref: ref} do
    expect(API.Mock, :request, fn _client, method, url, opts ->
      assert method == :post
      assert url == "/i/v0/e"

      assert %{
               event: "$exception",
               properties: %{
                 "$exception_list": [
                   %{
                     type: "Hello World",
                     value: "Hello World",
                     mechanism: %{handled: true}
                   }
                 ]
               }
             } = opts[:json]

      {:ok, %{}}
    end)

    LoggerHandlerKit.Act.chardata_message(:improper)
    LoggerHandlerKit.Assert.assert_logged(ref)
  end

  test "io format", %{handler_ref: ref} do
    expect(API.Mock, :request, fn _client, method, url, opts ->
      assert method == :post
      assert url == "/i/v0/e"

      assert %{
               event: "$exception",
               properties: %{
                 "$exception_list": [
                   %{
                     type: "Hello World",
                     value: "Hello World",
                     mechanism: %{handled: true}
                   }
                 ]
               }
             } = opts[:json]

      {:ok, %{}}
    end)

    LoggerHandlerKit.Act.io_format()
    LoggerHandlerKit.Assert.assert_logged(ref)
  end

  test "keyword report", %{handler_ref: ref} do
    expect(API.Mock, :request, fn _client, method, url, opts ->
      assert method == :post
      assert url == "/i/v0/e"

      assert %{
               event: "$exception",
               properties: %{
                 "$exception_list": [
                   %{
                     type: "[hello: \"world\"]",
                     value: "[hello: \"world\"]",
                     mechanism: %{handled: true}
                   }
                 ]
               }
             } = opts[:json]

      {:ok, %{}}
    end)

    LoggerHandlerKit.Act.keyword_report()
    LoggerHandlerKit.Assert.assert_logged(ref)
  end

  test "map report", %{handler_ref: ref} do
    expect(API.Mock, :request, fn _client, method, url, opts ->
      assert method == :post
      assert url == "/i/v0/e"

      assert %{
               event: "$exception",
               properties: %{
                 "$exception_list": [
                   %{
                     type: "%{hello: \"world\"}",
                     value: "%{hello: \"world\"}",
                     mechanism: %{handled: true}
                   }
                 ]
               }
             } = opts[:json]

      {:ok, %{}}
    end)

    LoggerHandlerKit.Act.map_report()
    LoggerHandlerKit.Assert.assert_logged(ref)
  end

  test "struct report", %{handler_ref: ref} do
    expect(API.Mock, :request, fn _client, method, url, opts ->
      assert method == :post
      assert url == "/i/v0/e"

      assert %{
               event: "$exception",
               properties: %{
                 "$exception_list": [
                   %{
                     type: "%LoggerHandlerKit.FakeStruct{hello: \"world\"}",
                     value: "%LoggerHandlerKit.FakeStruct{hello: \"world\"}",
                     mechanism: %{handled: true}
                   }
                 ]
               }
             } = opts[:json]

      {:ok, %{}}
    end)

    LoggerHandlerKit.Act.struct_report()
    LoggerHandlerKit.Assert.assert_logged(ref)
  end

  test "task error exception", %{handler_ref: ref} do
    expect(API.Mock, :request, fn _client, method, url, opts ->
      assert method == :post
      assert url == "/i/v0/e"

      assert %{
               event: "$exception",
               properties: %{
                 "$exception_list": [
                   %{
                     type: "** (RuntimeError) oops",
                     value: "** (RuntimeError) oops",
                     mechanism: %{handled: true, type: "generic"},
                     stacktrace: %{
                       type: "raw",
                       frames: [
                         %{
                           in_app: true,
                           filename: "lib/logger_handler_kit/act.ex",
                           function: "anonymous fn/0 in LoggerHandlerKit.Act.task_error/1",
                           lineno: _,
                           module: "LoggerHandlerKit.Act",
                           platform: "python"
                         },
                         %{
                           in_app: true,
                           filename: "lib/task/supervised.ex",
                           function: "Task.Supervised.invoke_mfa/2",
                           lineno: _,
                           module: "Task.Supervised",
                           platform: "python"
                         }
                       ]
                     }
                   }
                 ]
               }
             } = opts[:json]

      {:ok, %{}}
    end)

    LoggerHandlerKit.Act.task_error(:exception)
    LoggerHandlerKit.Assert.assert_logged(ref)
  end

  test "task error throw", %{handler_ref: ref} do
    expect(API.Mock, :request, fn _client, method, url, opts ->
      assert method == :post
      assert url == "/i/v0/e"

      assert %{
               event: "$exception",
               properties: %{
                 "$exception_list": [
                   %{
                     type: "** (throw) \"catch!\"",
                     value: "** (throw) \"catch!\"",
                     mechanism: %{handled: true, type: "generic"},
                     stacktrace: %{
                       type: "raw",
                       frames: [
                         %{
                           in_app: true,
                           filename: "lib/logger_handler_kit/act.ex",
                           function: "anonymous fn/0 in LoggerHandlerKit.Act.task_error/1",
                           lineno: _,
                           module: "LoggerHandlerKit.Act",
                           platform: "python"
                         },
                         %{
                           in_app: true,
                           filename: "lib/task/supervised.ex",
                           function: "Task.Supervised.invoke_mfa/2",
                           lineno: _,
                           module: "Task.Supervised",
                           platform: "python"
                         }
                       ]
                     }
                   }
                 ]
               }
             } = opts[:json]

      {:ok, %{}}
    end)

    LoggerHandlerKit.Act.task_error(:throw)
    LoggerHandlerKit.Assert.assert_logged(ref)
  end

  test "task error exit", %{handler_ref: ref} do
    expect(API.Mock, :request, fn _client, method, url, opts ->
      assert method == :post
      assert url == "/i/v0/e"

      assert %{
               event: "$exception",
               properties: %{
                 "$exception_list": [
                   %{
                     type: "** (exit) \"i quit\"",
                     value: "** (exit) \"i quit\"",
                     mechanism: %{handled: true, type: "generic"},
                     stacktrace: %{
                       type: "raw",
                       frames: [
                         %{
                           in_app: true,
                           filename: "lib/logger_handler_kit/act.ex",
                           function: "anonymous fn/0 in LoggerHandlerKit.Act.task_error/1",
                           lineno: _,
                           module: "LoggerHandlerKit.Act",
                           platform: "python"
                         },
                         %{
                           in_app: true,
                           filename: "lib/task/supervised.ex",
                           function: "Task.Supervised.invoke_mfa/2",
                           lineno: _,
                           module: "Task.Supervised",
                           platform: "python"
                         }
                       ]
                     }
                   }
                 ]
               }
             } = opts[:json]

      {:ok, %{}}
    end)

    LoggerHandlerKit.Act.task_error(:exit)
    LoggerHandlerKit.Assert.assert_logged(ref)
  end

  test "genserver crash exception", %{handler_ref: ref} do
    expect(API.Mock, :request, fn _client, method, url, opts ->
      assert method == :post
      assert url == "/i/v0/e"

      assert %{
               event: "$exception",
               properties: %{
                 "$exception_list": [
                   %{
                     type: "** (RuntimeError) oops",
                     value: "** (RuntimeError) oops",
                     mechanism: %{handled: true, type: "generic"},
                     stacktrace: %{
                       type: "raw",
                       frames: [
                         %{
                           in_app: true,
                           filename: "lib/logger_handler_kit/act.ex",
                           function: "anonymous fn/0 in LoggerHandlerKit.Act.genserver_crash/1",
                           lineno: _,
                           module: "LoggerHandlerKit.Act",
                           platform: "python"
                         },
                         %{
                           filename: "gen_server.erl",
                           function: ":gen_server.try_handle_call/4",
                           in_app: true,
                           lineno: _,
                           module: ":gen_server",
                           platform: "python"
                         },
                         %{
                           filename: "gen_server.erl",
                           function: ":gen_server.handle_msg/6",
                           in_app: true,
                           lineno: _,
                           module: ":gen_server",
                           platform: "python"
                         },
                         %{
                           filename: "proc_lib.erl",
                           function: ":proc_lib.init_p_do_apply/3",
                           in_app: true,
                           lineno: _,
                           module: ":proc_lib",
                           platform: "python"
                         }
                       ]
                     }
                   }
                 ]
               }
             } = opts[:json]

      {:ok, %{}}
    end)

    LoggerHandlerKit.Act.genserver_crash(:exception)
    LoggerHandlerKit.Assert.assert_logged(ref)
  end
end
