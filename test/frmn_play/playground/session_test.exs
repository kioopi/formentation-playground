defmodule FrmnPlay.Playground.SessionTest do
  use ExUnit.Case, async: true

  alias FrmnPlay.Playground
  alias FrmnPlay.Playground.Session

  describe "has_diagnostics?/1" do
    test "false when the accepted form compiled without diagnostics" do
      session = Playground.start_session()

      refute Session.has_diagnostics?(session)
    end

    test "true when the accepted form has diagnostics" do
      session = %{Playground.start_session() | diagnostics: [%{code: :test, message: "boom"}]}

      assert Session.has_diagnostics?(session)
    end
  end
end
