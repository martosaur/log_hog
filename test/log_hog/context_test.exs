defmodule LogHog.ContextTest do
  use ExUnit.Case, async: true

  alias LogHog.Context

  test "sets context for specific scope" do
    assert :ok = Context.set(LogHog, "$exception", %{foo: "bar"})
    assert [__loghog__: %{LogHog => %{"$exception" => %{foo: "bar"}}}] = Logger.metadata()
  end

  test "context is merged" do
    Context.set(LogHog, "$exception", %{foo: "bar"})
    Context.set(LogHog, "$exception", %{foo: "baz", eggs: "spam"})

    assert [__loghog__: %{LogHog => %{"$exception" => %{eggs: "spam", foo: "baz"}}}] =
             Logger.metadata()
  end

  test "but not deep merged" do
    Context.set(LogHog, "$exception", %{foo: %{eggs: "spam"}})
    Context.set(LogHog, "$exception", %{foo: %{bar: "baz"}})

    assert [__loghog__: %{LogHog => %{"$exception" => %{foo: %{bar: "baz"}}}}] = Logger.metadata()
  end

  test "multiple scopes" do
    Context.set(LogHog, :all, %{foo: "bar"})
    Context.set(MyLogHog, "$exception", %{foo: "baz"})
    Context.set(:all, :all, %{hello: "world"})

    assert [
             __loghog__: %{
               LogHog => %{all: %{foo: "bar"}},
               MyLogHog => %{"$exception" => %{foo: "baz"}},
               all: %{all: %{hello: "world"}}
             }
           ] = Logger.metadata()
  end

  test "get/0 retrieves context with scope + all" do
    Context.set(LogHog, :all, %{foo: "bar"})
    Context.set(MyLogHog, "$exception", %{foo: "baz"})
    Context.set(:all, :all, %{hello: "world"})
    Logger.metadata(foo: "baz")

    assert %{foo: "bar", hello: "world"} = Context.get(LogHog, "$exception")
    assert %{foo: "baz", hello: "world"} = Context.get(MyLogHog, "$exception")
    assert %{hello: "world"} = Context.get(MyLogHog, "$exception_list")
    assert %{hello: "world"} = Context.get(FooBar, "$exception")
  end

  test "in case of overlapping keys prefer more specific scope" do
    Context.set(LogHog, :all, %{foo: 1})
    Context.set(LogHog, "$exception", %{foo: 2})
    Context.set(:all, :all, %{foo: 3})
    Context.set(:all, "$exception", %{foo: 4})

    assert %{foo: 2} = Context.get(LogHog, "$exception")
    assert %{foo: 4} = Context.get(:all, "$exception")
  end
end
