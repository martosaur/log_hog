defmodule LogHog.HandlerTest do
  use ExUnit.Case, async: true

  import Mox
  require Logger
  alias LogHog.Context

  @moduletag capture_log: true

  setup {LoggerHandlerKit.Arrange, :ensure_per_handler_translation}

  setup %{test: test} = context do
    stub_with(LogHog.API.Mock, LogHog.API.Stub)

    config =
      [
        public_url: "https://us.i.posthog.com",
        api_key: "my_api_key",
        api_client_module: LogHog.API.Mock,
        supervisor_name: test,
        capture_level: :info
      ]
      |> Keyword.merge(context[:config] || [])
      |> LogHog.Config.validate!()
      |> Map.put(:max_batch_time_ms, to_timeout(60_000))
      |> Map.put(:max_batch_events, 100)

    start_link_supervised!({LogHog.Supervisor, config})
    sender_pid = test |> LogHog.Registry.via(LogHog.Sender) |> GenServer.whereis()

    big_config_override = Map.take(context, [:handle_otp_reports, :handle_sasl_reports, :level])

    {context, on_exit} =
      LoggerHandlerKit.Arrange.add_handler(
        test,
        LogHog.Handler,
        config,
        big_config_override
      )

    on_exit(on_exit)
    Map.put(context, :sender_pid, sender_pid)
  end

  test "takes distinct_id from metadata", %{handler_ref: ref, sender_pid: sender_pid} do
    Logger.info("Hello World", distinct_id: "foo")
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{
               distinct_id: "foo",
               "$exception_list": [
                 %{
                   type: "Hello World",
                   value: "Hello World",
                   mechanism: %{handled: true, type: "generic"}
                 }
               ]
             }
           } = event
  end

  test "always exports global context", %{handler_ref: ref, sender_pid: sender_pid} do
    Logger.info("Hello World")
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{
               "$lib": "LogHog",
               "$lib_version": _,
               "$exception_list": [
                 %{
                   type: "Hello World",
                   value: "Hello World",
                   mechanism: %{handled: true, type: "generic"}
                 }
               ]
             }
           } = event
  end

  @tag config: [capture_level: :warning]
  test "ignores messages lower than capture_level", %{handler_ref: ref, sender_pid: sender_pid} do
    Logger.info("Hello World")
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: []} = :sys.get_state(sender_pid)
  end

  @tag config: [capture_level: :warning]
  test "logs with crash reason always captured", %{handler_ref: ref, sender_pid: sender_pid} do
    Logger.debug("Hello World", crash_reason: {"exit reason", []})
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{
               distinct_id: "unknown",
               "$exception_list": [
                 %{
                   type: "** (exit) \"exit reason\"",
                   value: "** (exit) \"exit reason\"",
                   mechanism: %{handled: true, type: "generic"}
                 }
               ]
             }
           } = event
  end

  test "string message", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.string_message()
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

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
           } = event
  end

  test "charlist message", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.charlist_message()
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

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
           } = event
  end

  test "chardata message", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.chardata_message(:proper)
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

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
           } = event
  end

  test "chardata message - improper", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.chardata_message(:improper)
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

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
           } = event
  end

  test "io format", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.io_format()
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

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
           } = event
  end

  test "keyword report", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.keyword_report()
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

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
           } = event
  end

  test "map report", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.map_report()
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

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
           } = event
  end

  test "struct report", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.struct_report()
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

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
           } = event
  end

  test "task error exception", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.task_error(:exception)
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{
               "$exception_list": [
                 %{
                   type: "RuntimeError",
                   value: "** (RuntimeError) oops",
                   mechanism: %{handled: true, type: "generic"},
                   stacktrace: %{
                     type: "raw",
                     frames: [
                       %{
                         in_app: false,
                         filename: "lib/logger_handler_kit/act.ex",
                         function: "anonymous fn/0 in LoggerHandlerKit.Act.task_error/1",
                         lineno: _,
                         module: "LoggerHandlerKit.Act",
                         platform: "custom",
                         lang: "elixir"
                       },
                       %{
                         in_app: false,
                         filename: "lib/task/supervised.ex",
                         function: "Task.Supervised.invoke_mfa/2",
                         lineno: _,
                         module: "Task.Supervised",
                         platform: "custom",
                         lang: "elixir"
                       }
                     ]
                   }
                 }
               ]
             }
           } = event
  end

  test "task error throw", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.task_error(:throw)
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

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
                         in_app: false,
                         filename: "lib/logger_handler_kit/act.ex",
                         function: "anonymous fn/0 in LoggerHandlerKit.Act.task_error/1",
                         lineno: _,
                         module: "LoggerHandlerKit.Act",
                         platform: "custom",
                         lang: "elixir"
                       },
                       %{
                         in_app: false,
                         filename: "lib/task/supervised.ex",
                         function: "Task.Supervised.invoke_mfa/2",
                         lineno: _,
                         module: "Task.Supervised",
                         platform: "custom",
                         lang: "elixir"
                       }
                     ]
                   }
                 }
               ]
             }
           } = event
  end

  test "task error exit", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.task_error(:exit)
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

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
                         in_app: false,
                         filename: "lib/logger_handler_kit/act.ex",
                         function: "anonymous fn/0 in LoggerHandlerKit.Act.task_error/1",
                         lineno: _,
                         module: "LoggerHandlerKit.Act",
                         platform: "custom",
                         lang: "elixir"
                       },
                       %{
                         in_app: false,
                         filename: "lib/task/supervised.ex",
                         function: "Task.Supervised.invoke_mfa/2",
                         lineno: _,
                         module: "Task.Supervised",
                         platform: "custom",
                         lang: "elixir"
                       }
                     ]
                   }
                 }
               ]
             }
           } = event
  end

  test "genserver crash exception", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.genserver_crash(:exception)
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{
               "$exception_list": [
                 %{
                   type: "RuntimeError",
                   value: "** (RuntimeError) oops",
                   mechanism: %{handled: true, type: "generic"},
                   stacktrace: %{
                     type: "raw",
                     frames: [
                       %{
                         in_app: false,
                         filename: "lib/logger_handler_kit/act.ex",
                         function: "anonymous fn/0 in LoggerHandlerKit.Act.genserver_crash/1",
                         lineno: _,
                         module: "LoggerHandlerKit.Act",
                         platform: "custom",
                         lang: "elixir"
                       },
                       %{
                         filename: "gen_server.erl",
                         function: ":gen_server.try_handle_call/4",
                         in_app: false,
                         lineno: _,
                         module: ":gen_server",
                         platform: "custom",
                         lang: "elixir"
                       },
                       %{
                         filename: "gen_server.erl",
                         function: ":gen_server.handle_msg/6",
                         in_app: false,
                         lineno: _,
                         module: ":gen_server",
                         platform: "custom",
                         lang: "elixir"
                       },
                       %{
                         filename: "proc_lib.erl",
                         function: ":proc_lib.init_p_do_apply/3",
                         in_app: false,
                         lineno: _,
                         module: ":proc_lib",
                         platform: "custom",
                         lang: "elixir"
                       }
                     ]
                   }
                 }
               ],
               distinct_id: "unknown"
             }
           } = event
  end

  test "genserver crash exit", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.genserver_crash(:exit)
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

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
                         in_app: false,
                         filename: "lib/logger_handler_kit/act.ex",
                         function: "anonymous fn/0 in LoggerHandlerKit.Act.genserver_crash/1",
                         lineno: _,
                         module: "LoggerHandlerKit.Act",
                         platform: "custom",
                         lang: "elixir"
                       },
                       %{
                         filename: "gen_server.erl",
                         function: ":gen_server.try_handle_call/4",
                         lineno: _,
                         module: ":gen_server",
                         platform: "custom",
                         lang: "elixir",
                         in_app: false
                       },
                       %{
                         filename: "gen_server.erl",
                         function: ":gen_server.handle_msg/6",
                         lineno: _,
                         module: ":gen_server",
                         platform: "custom",
                         lang: "elixir",
                         in_app: false
                       },
                       %{
                         filename: "proc_lib.erl",
                         function: ":proc_lib.init_p_do_apply/3",
                         in_app: false,
                         lineno: _,
                         module: ":proc_lib",
                         platform: "custom",
                         lang: "elixir"
                       }
                     ]
                   }
                 }
               ]
             }
           } = event
  end

  test "genserver crash exit with struct", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.genserver_crash(:exit_with_struct)
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{
               "$exception_list": [
                 %{
                   type: "** (exit) %LoggerHandlerKit.FakeStruct{hello: \"world\"}",
                   value: "** (exit) %LoggerHandlerKit.FakeStruct{hello: \"world\"}",
                   mechanism: %{handled: true, type: "generic"}
                 }
               ]
             }
           } = event
  end

  test "genserver crash throw", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.genserver_crash(:throw)
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{
               "$exception_list": [
                 %{
                   type: "** (exit) bad return value: \"catch!\"",
                   value: "** (exit) bad return value: \"catch!\"",
                   mechanism: %{handled: true, type: "generic"}
                 }
               ]
             }
           } = event
  end

  test "gen_state_m crash exception", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.gen_statem_crash(:exception)
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{
               "$exception_list": [
                 %{
                   type: "RuntimeError",
                   value: "** (RuntimeError) oops",
                   mechanism: %{handled: true, type: "generic"},
                   stacktrace: %{
                     frames: [
                       %{
                         function: "anonymous fn/0 in LoggerHandlerKit.Act.gen_statem_crash/1",
                         module: "LoggerHandlerKit.Act",
                         filename: "lib/logger_handler_kit/act.ex",
                         in_app: false,
                         lineno: _,
                         platform: "custom",
                         lang: "elixir"
                       },
                       %{
                         function: ":gen_statem.loop_state_callback/11",
                         module: ":gen_statem",
                         filename: "gen_statem.erl",
                         in_app: false,
                         lineno: _,
                         platform: "custom",
                         lang: "elixir"
                       },
                       %{
                         function: ":proc_lib.init_p_do_apply/3",
                         module: ":proc_lib",
                         filename: "proc_lib.erl",
                         in_app: false,
                         lineno: _,
                         platform: "custom",
                         lang: "elixir"
                       }
                     ],
                     type: "raw"
                   }
                 }
               ],
               distinct_id: "unknown"
             }
           } = event
  end

  test "bare process crash exception", %{
    handler_id: handler_id,
    handler_ref: ref,
    sender_pid: sender_pid
  } do
    LoggerHandlerKit.Act.bare_process_crash(handler_id, :exception)
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{
               "$exception_list": [
                 %{
                   type: "RuntimeError",
                   value: "** (RuntimeError) oops",
                   mechanism: %{handled: true, type: "generic"},
                   stacktrace: %{
                     frames: [
                       %{
                         filename: "lib/logger_handler_kit/act.ex",
                         function: "anonymous fn/0 in LoggerHandlerKit.Act.bare_process_crash/2",
                         in_app: false,
                         lineno: _,
                         module: "LoggerHandlerKit.Act",
                         platform: "custom",
                         lang: "elixir"
                       }
                     ],
                     type: "raw"
                   }
                 }
               ],
               distinct_id: "unknown"
             }
           } = event
  end

  test "bare process crash throw", %{
    handler_id: handler_id,
    handler_ref: ref,
    sender_pid: sender_pid
  } do
    LoggerHandlerKit.Act.bare_process_crash(handler_id, :throw)
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{
               "$exception_list": [
                 %{
                   type: "ErlangError",
                   value: "** (ErlangError) Erlang error: {:nocatch, \"catch!\"}",
                   mechanism: %{handled: true, type: "generic"},
                   stacktrace: %{
                     frames: [
                       %{
                         filename: "lib/logger_handler_kit/act.ex",
                         function: "anonymous fn/0 in LoggerHandlerKit.Act.bare_process_crash/2",
                         in_app: false,
                         lineno: _,
                         module: "LoggerHandlerKit.Act",
                         platform: "custom",
                         lang: "elixir"
                       }
                     ],
                     type: "raw"
                   }
                 }
               ]
             }
           } = event
  end

  @tag handle_sasl_reports: true
  test "genserver init crash", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.genserver_init_crash()
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{
               "$exception_list": [
                 %{
                   type: "RuntimeError",
                   value: "** (RuntimeError) oops",
                   mechanism: %{handled: true, type: "generic"},
                   stacktrace: %{
                     frames: [
                       %{
                         filename: "lib/logger_handler_kit/act.ex",
                         function:
                           "anonymous fn/0 in LoggerHandlerKit.Act.genserver_init_crash/0",
                         in_app: false,
                         lineno: _,
                         module: "LoggerHandlerKit.Act",
                         platform: "custom",
                         lang: "elixir"
                       },
                       %{
                         filename: "gen_server.erl",
                         function: ":gen_server.init_it/2",
                         in_app: false,
                         lineno: _,
                         module: ":gen_server",
                         platform: "custom",
                         lang: "elixir"
                       },
                       %{
                         filename: "gen_server.erl",
                         function: ":gen_server.init_it/6",
                         in_app: false,
                         lineno: _,
                         module: ":gen_server",
                         platform: "custom",
                         lang: "elixir"
                       },
                       %{
                         filename: "proc_lib.erl",
                         function: ":proc_lib.init_p_do_apply/3",
                         in_app: false,
                         lineno: _,
                         module: ":proc_lib",
                         platform: "custom",
                         lang: "elixir"
                       }
                     ],
                     type: "raw"
                   }
                 }
               ]
             }
           } = event
  end

  @tag handle_sasl_reports: true
  test "proc_lib crash exception", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.proc_lib_crash(:exception)
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{
               "$exception_list": [
                 %{
                   type: "RuntimeError",
                   value: "** (RuntimeError) oops",
                   mechanism: %{handled: true, type: "generic"},
                   stacktrace: %{
                     frames: [
                       %{
                         filename: "lib/logger_handler_kit/act.ex",
                         function: "anonymous fn/1 in LoggerHandlerKit.Act.proc_lib_crash/1",
                         in_app: false,
                         lineno: _,
                         module: "LoggerHandlerKit.Act",
                         platform: "custom",
                         lang: "elixir"
                       },
                       %{
                         filename: "proc_lib.erl",
                         function: ":proc_lib.init_p/3",
                         in_app: false,
                         lineno: _,
                         module: ":proc_lib",
                         platform: "custom",
                         lang: "elixir"
                       }
                     ],
                     type: "raw"
                   }
                 }
               ]
             }
           } = event
  end

  @tag handle_sasl_reports: true
  test "supervisor progress report failed to start child", %{
    handler_ref: ref,
    sender_pid: sender_pid
  } do
    LoggerHandlerKit.Act.supervisor_progress_report(:failed_to_start_child)
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{
               "$exception_list": [
                 %{
                   type: "Child :task of Supervisor" <> type_end,
                   value: "Child :task of Supervisor" <> value_end,
                   mechanism: %{handled: true, type: "generic"}
                 }
               ]
             }
           } = event

    assert String.ends_with?(type_end, "failed to start")
    assert String.ends_with?(value_end, "\nType: :worker")
  end

  @tag handle_sasl_reports: true, config: [capture_level: :debug]
  test "supervisor progress report child started", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.supervisor_progress_report(:child_started)
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{
               "$exception_list": [
                 %{
                   type: "Child :task of Supervisor" <> type_end,
                   value: "Child :task of Supervisor" <> value_end,
                   mechanism: %{handled: true, type: "generic"}
                 }
               ]
             }
           } = event

    assert String.ends_with?(type_end, "started")
    assert String.ends_with?(value_end, "\nType: :worker")
  end

  @tag handle_sasl_reports: true
  test "supervisor progress report child terminated", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.supervisor_progress_report(:child_terminated)
    LoggerHandlerKit.Assert.assert_logged(ref)
    LoggerHandlerKit.Assert.assert_logged(ref)
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [_, _, _] = events} = :sys.get_state(sender_pid)

    for event <- events do
      assert %{
               event: "$exception",
               properties: %{
                 "$exception_list": [
                   %{
                     type: "Child :task of Supervisor" <> type_end,
                     mechanism: %{handled: true, type: "generic"}
                   }
                 ]
               }
             } = event

      assert Enum.any?([
               String.ends_with?(type_end, "started"),
               String.ends_with?(type_end, "terminated"),
               String.ends_with?(type_end, "caused shutdown")
             ])
    end
  end

  @tag config: [metadata: [:extra]]
  test "exports metadata if configured", %{handler_ref: ref, sender_pid: sender_pid} do
    Logger.error("Error with metadata", extra: "Foo", hello: "world")
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{
               extra: "Foo",
               "$exception_list": [
                 %{
                   type: "Error with metadata",
                   value: "Error with metadata",
                   mechanism: %{handled: true}
                 }
               ]
             }
           } = event
  end

  @tag config: [metadata: [:extra]]
  test "ensures metadata is serializable", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.metadata_serialization(:all)
    LoggerHandlerKit.Act.string_message()
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{extra: maybe_encoded}
           } = event

    assert %{
             boolean: true,
             string: "hello world",
             binary: "<<1, 2, 3>>",
             atom: :foo,
             integer: 42,
             datetime: ~U[2025-06-01 12:34:56.000Z],
             struct: %{hello: "world"},
             tuple: [:ok, "hello"],
             keyword: %{hello: "world"},
             improper_keyword: "[[:a, 1] | {:b, 2}]",
             fake_keyword: [[:a, 1], [:b, 2, :c]],
             list: [1, 2, 3],
             improper_list: "[1, 2 | 3]",
             map: %{:hello => "world", "foo" => "bar"},
             function: "&LoggerHandlerKit.Act.metadata_serialization/1",
             anonymous_function: "#Function<" <> _,
             pid: "#PID<" <> _,
             ref: "#Reference<" <> _,
             port: "#Port<" <> _
           } = maybe_encoded

    JSON.encode!(maybe_encoded)
  end

  @tag config: [metadata: [:extra]]
  test "purposefully set context is always exported", %{handler_ref: ref, sender_pid: sender_pid} do
    Context.set(%{foo: "bar"})
    Logger.error("Error with metadata", hello: "world")
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{
               distinct_id: "unknown",
               foo: "bar",
               "$exception_list": [
                 %{
                   type: "Error with metadata",
                   value: "Error with metadata",
                   mechanism: %{handled: true, type: "generic"}
                 }
               ]
             }
           } = event
  end

  test "erlang frames in stacktrace", %{handler_ref: ref, sender_pid: sender_pid} do
    {:ok, _pid} = Task.start(fn -> :erlang.system_time(:foo) end)
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{
               "$exception_list": [
                 %{
                   type: "ArgumentError",
                   value:
                     "** (ArgumentError) errors were found at the given arguments:\n\n  * 1st argument: invalid time unit\n",
                   stacktrace: %{
                     type: "raw",
                     frames: [
                       %{
                         filename: "",
                         function: ":erlang.system_time(:foo)",
                         in_app: false,
                         lineno: nil,
                         module: ":erlang",
                         platform: "custom",
                         lang: "elixir"
                       }
                       | _
                     ]
                   },
                   mechanism: %{type: "generic", handled: true}
                 }
               ]
             }
           } = event
  end

  @tag config: [in_app_otp_apps: [:logger_handler_kit]]
  test "marks in_app frames as such", %{handler_ref: ref, sender_pid: sender_pid} do
    LoggerHandlerKit.Act.task_error(:exception)
    LoggerHandlerKit.Assert.assert_logged(ref)

    assert %{events: [event]} = :sys.get_state(sender_pid)

    assert %{
             event: "$exception",
             properties: %{
               "$exception_list": [
                 %{
                   stacktrace: %{
                     type: "raw",
                     frames: [
                       %{
                         in_app: true,
                         module: "LoggerHandlerKit.Act"
                       },
                       %{
                         in_app: false,
                         module: "Task.Supervised"
                       }
                     ]
                   }
                 }
               ]
             }
           } = event
  end
end
