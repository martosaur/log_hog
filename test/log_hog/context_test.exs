defmodule LogHog.ContextTest do
  use ExUnit.Case, async: true

  alias LogHog.Context

  test "sets context" do
    assert :ok = Context.set(%{foo: "bar"})
    assert [__loghog__: %{foo: "bar"}] = Logger.metadata()
  end

  test "context is merged" do
    Context.set(%{foo: "bar"})
    Context.set(%{foo: "baz", eggs: "spam"})

    assert [__loghog__: %{foo: "baz", eggs: "spam"}] = Logger.metadata()
  end

  test "but not deep merged" do
    Context.set(%{foo: %{eggs: "spam"}})
    Context.set(%{foo: %{bar: "baz"}})

    assert [__loghog__: %{foo: %{bar: "baz"}}] = Logger.metadata()
  end

  test "get/0 retrieves context" do
    Context.set(%{foo: "bar"})
    Logger.metadata(foo: "baz")

    assert %{foo: "bar"} = Context.get()
  end
end
