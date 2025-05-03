defmodule LogHogTest do
  use ExUnit.Case
  doctest LogHog

  test "greets the world" do
    assert LogHog.hello() == :world
  end
end
