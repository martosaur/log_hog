defmodule LogHogTest do
  use LogHog.Case, async: true

  @moduletag config: [supervisor_name: LogHog]

  setup :setup_supervisor

  describe "config/0" do
    test "fetches from LogHog by default" do
      assert %{supervisor_name: LogHog} = LogHog.config()
    end

    @tag config: [supervisor_name: CustomLogHog]
    test "uses custom supervisor name" do
      assert %{supervisor_name: CustomLogHog} = LogHog.config(CustomLogHog)
    end
  end

  describe "capture/4" do
    test "simple call", %{sender_pid: sender_pid} do
      LogHog.capture("case tested", "distinct_id")

      assert %{events: [event]} = :sys.get_state(sender_pid)

      assert %{
               event: "case tested",
               distinct_id: "distinct_id",
               properties: %{},
               timestamp: _
             } = event
    end

    test "with properties", %{sender_pid: sender_pid} do
      LogHog.capture("case tested", "distinct_id", %{foo: "bar"})

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
      LogHog.capture(CustomLogHog, "case tested", "distinct_id")

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
      LogHog.capture(CustomLogHog, "case tested", "distinct_id", %{foo: "bar"})

      assert %{events: [event]} = :sys.get_state(sender_pid)

      assert %{
               event: "case tested",
               distinct_id: "distinct_id",
               properties: %{foo: "bar"},
               timestamp: _
             } = event
    end
  end
end
