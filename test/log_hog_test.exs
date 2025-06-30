defmodule LogHogTest do
  use LogHog.Case, async: true

  @moduletag config: [supervisor_name: LogHog]

  import Mox

  alias LogHog.API

  setup :setup_supervisor
  setup :verify_on_exit!

  describe "config/0" do
    test "fetches from LogHog by default" do
      assert %{supervisor_name: LogHog} = LogHog.config()
    end

    @tag config: [supervisor_name: CustomLogHog]
    test "uses custom supervisor name" do
      assert %{supervisor_name: CustomLogHog} = LogHog.config(CustomLogHog)
    end
  end

  describe "bare_capture/4" do
    test "simple call", %{sender_pid: sender_pid} do
      LogHog.bare_capture("case tested", "distinct_id")

      assert %{events: [event]} = :sys.get_state(sender_pid)

      assert %{
               event: "case tested",
               distinct_id: "distinct_id",
               properties: %{},
               timestamp: _
             } = event
    end

    test "with properties", %{sender_pid: sender_pid} do
      LogHog.bare_capture("case tested", "distinct_id", %{foo: "bar"})

      assert %{events: [event]} = :sys.get_state(sender_pid)

      assert %{
               event: "case tested",
               distinct_id: "distinct_id",
               properties: %{foo: "bar"},
               timestamp: _
             } = event
    end

    @tag config: [supervisor_name: CustomLogHog]
    test "simple call for custom supervisor", %{sender_pid: sender_pid} do
      LogHog.bare_capture(CustomLogHog, "case tested", "distinct_id")

      assert %{events: [event]} = :sys.get_state(sender_pid)

      assert %{
               event: "case tested",
               distinct_id: "distinct_id",
               properties: %{},
               timestamp: _
             } = event
    end

    @tag config: [supervisor_name: CustomLogHog]
    test "with properties for custom supervisor", %{sender_pid: sender_pid} do
      LogHog.bare_capture(CustomLogHog, "case tested", "distinct_id", %{foo: "bar"})

      assert %{events: [event]} = :sys.get_state(sender_pid)

      assert %{
               event: "case tested",
               distinct_id: "distinct_id",
               properties: %{foo: "bar"},
               timestamp: _
             } = event
    end

    test "ignores set context but uses global one from the config", %{sender_pid: sender_pid} do
      LogHog.set_context(%{hello: "world"})
      LogHog.bare_capture("case tested", "distinct_id", %{foo: "bar"})

      assert %{events: [%{properties: properties}]} = :sys.get_state(sender_pid)

      assert %{foo: "bar", "$lib": "LogHog", "$lib_version": _} = properties
      refute properties[:hello]
    end
  end

  describe "capture/4" do
    test "simple call", %{sender_pid: sender_pid} do
      LogHog.capture("case tested", %{distinct_id: "distinct_id"})

      assert %{events: [event]} = :sys.get_state(sender_pid)

      assert %{
               event: "case tested",
               distinct_id: "distinct_id",
               properties: %{},
               timestamp: _
             } = event
    end

    test "distinct_id is required" do
      assert {:error, :missing_distinct_id} = LogHog.capture("case tested")
    end

    test "with properties", %{sender_pid: sender_pid} do
      LogHog.capture("case tested", %{distinct_id: "distinct_id", foo: "bar"})

      assert %{events: [event]} = :sys.get_state(sender_pid)

      assert %{
               event: "case tested",
               distinct_id: "distinct_id",
               properties: %{foo: "bar"},
               timestamp: _
             } = event
    end

    @tag config: [supervisor_name: CustomLogHog]
    test "simple call for custom supervisor", %{sender_pid: sender_pid} do
      LogHog.capture(CustomLogHog, "case tested", %{distinct_id: "distinct_id"})

      assert %{events: [event]} = :sys.get_state(sender_pid)

      assert %{
               event: "case tested",
               distinct_id: "distinct_id",
               properties: %{},
               timestamp: _
             } = event
    end

    @tag config: [supervisor_name: CustomLogHog]
    test "with properties for custom supervisor", %{sender_pid: sender_pid} do
      LogHog.capture(CustomLogHog, "case tested", %{distinct_id: "distinct_id", foo: "bar"})

      assert %{events: [event]} = :sys.get_state(sender_pid)

      assert %{
               event: "case tested",
               distinct_id: "distinct_id",
               properties: %{foo: "bar"},
               timestamp: _
             } = event
    end

    test "includes relevant event context", %{sender_pid: sender_pid} do
      LogHog.set_context(%{hello: "world", distinct_id: "distinct_id"})
      LogHog.set_event_context("case tested", %{foo: "bar"})
      LogHog.set_context(MyLogHog, %{spam: "eggs"})
      LogHog.capture("case tested", %{final: "override"})

      assert %{events: [event]} = :sys.get_state(sender_pid)

      assert %{
               event: "case tested",
               distinct_id: "distinct_id",
               properties: %{
                 hello: "world",
                 foo: "bar",
                 final: "override"
               },
               timestamp: _
             } = event
    end
  end

  describe "get_feature_flag/2" do
    test "returns body on success" do
      expect(API.Mock, :request, fn _client, method, url, opts ->
        assert method == :post
        assert url == "/flags"
        assert opts[:params] == %{v: 2}

        assert opts[:json] == %{
                 distinct_id: "foo"
               }

        {:ok, %{status: 200, body: "body"}}
      end)

      assert {:ok, "body"} = LogHog.get_feature_flag("foo")
    end

    test "sophisticated body" do
      expect(API.Mock, :request, fn client, method, url, opts ->
        assert opts[:json] == %{
                 distinct_id: "foo",
                 groups: %{group_type: "group_id"}
               }

        API.Stub.request(client, method, url, opts)
      end)

      assert {:ok, %{}} =
               LogHog.get_feature_flag(%{distinct_id: "foo", groups: %{group_type: "group_id"}})
    end

    test "errors passed as is" do
      expect(API.Mock, :request, fn _client, _method, _url, _opts ->
        {:error, :transport_error}
      end)

      assert {:error, :transport_error} = LogHog.get_feature_flag("foo")
    end

    test "non-200 is wrapped in error" do
      expect(API.Mock, :request, fn _client, _method, _url, _opts ->
        {:ok, %{status: 503}}
      end)

      assert {:error, %{status: 503}} = LogHog.get_feature_flag("foo")
    end

    @tag config: [supervisor_name: MyLogHog]
    test "custom LogHog instance" do
      expect(API.Mock, :request, fn client, method, url, opts ->
        assert opts[:json] == %{distinct_id: "foo"}

        API.Stub.request(client, method, url, opts)
      end)

      assert {:ok, %{}} = LogHog.get_feature_flag(MyLogHog, "foo")
    end
  end

  describe "set_context/2 + get_context/2" do
    test "default scope" do
      LogHog.set_context(%{foo: "bar"})
      assert LogHog.get_context() == %{foo: "bar"}
      assert LogHog.get_context(LogHog) == %{foo: "bar"}
      assert LogHog.get_event_context("$exception") == %{foo: "bar"}
      assert LogHog.get_event_context(LogHog, "$exception") == %{foo: "bar"}
    end

    test "named scope, all events" do
      LogHog.set_context(MyLogHog, %{foo: "bar"})
      assert LogHog.get_context() == %{}
      assert LogHog.get_event_context("$exception") == %{}
      assert LogHog.get_context(MyLogHog) == %{foo: "bar"}
      assert LogHog.get_event_context(MyLogHog, "$exception") == %{foo: "bar"}
    end
  end

  describe "set_event_context/2 + get_event_context/2" do
    test "default scope" do
      LogHog.set_event_context("$exception", %{foo: "bar"})
      assert LogHog.get_context() == %{}
      assert LogHog.get_event_context("$exception") == %{foo: "bar"}
      assert LogHog.get_context(LogHog) == %{}
      assert LogHog.get_event_context(LogHog, "$exception") == %{foo: "bar"}
    end

    test "named scope" do
      LogHog.set_event_context(MyLogHog, "$exception", %{foo: "bar"})
      assert LogHog.get_context() == %{}
      assert LogHog.get_event_context("$exception") == %{}
      assert LogHog.get_context(MyLogHog) == %{}
      assert LogHog.get_event_context(MyLogHog, "$exception") == %{foo: "bar"}
    end
  end
end
