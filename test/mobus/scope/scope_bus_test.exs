defmodule Mobus.Scope.ScopeBusTest do
  use ExUnit.Case, async: true

  alias Mobus.Scope.ScopeBus

  defmodule TestScope do
    @behaviour Mobus.Scope.Behaviour

    @impl true
    def build(_socket), do: %{role: :admin, permissions: [:read, :write]}

    @impl true
    def can?(%{permissions: perms}, action), do: action in perms

    @impl true
    def feature?(_data, :beta), do: true
    def feature?(_data, _), do: false
  end

  defmodule MinimalScope do
    @behaviour Mobus.Scope.Behaviour

    @impl true
    def build(_socket), do: %{level: :basic}

    @impl true
    def can?(_data, _action), do: false
  end

  defp new_socket do
    %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
  end

  describe "init/1" do
    test "assigns __scope_bus__ as empty map" do
      socket = ScopeBus.init(new_socket())
      assert socket.assigns.__scope_bus__ == %{}
    end

    test "is idempotent -- does not overwrite existing bus" do
      socket =
        new_socket()
        |> ScopeBus.init()
        |> ScopeBus.register(test: TestScope)

      socket_after = ScopeBus.init(socket)
      assert map_size(socket_after.assigns.__scope_bus__) == 1
    end
  end

  describe "register/2" do
    test "stores scope modules as {module, :pending}" do
      socket =
        new_socket()
        |> ScopeBus.init()
        |> ScopeBus.register(test: TestScope)

      assert socket.assigns.__scope_bus__[:test] == {TestScope, :pending}
    end

    test "does not overwrite already-registered scopes" do
      socket =
        new_socket()
        |> ScopeBus.init()
        |> ScopeBus.register(test: TestScope)

      {_data, socket} = ScopeBus.resolve(socket, :test)
      socket = ScopeBus.register(socket, test: MinimalScope)

      # Should still have TestScope's resolved data, not MinimalScope
      {_mod, scope_data} = socket.assigns.__scope_bus__[:test]
      assert scope_data == %{role: :admin, permissions: [:read, :write]}
    end
  end

  describe "resolve/2" do
    test "builds scope on first access and caches result" do
      socket =
        new_socket()
        |> ScopeBus.init()
        |> ScopeBus.register(test: TestScope)

      {scope_data, updated_socket} = ScopeBus.resolve(socket, :test)
      assert scope_data == %{role: :admin, permissions: [:read, :write]}

      # Second resolve returns cached data without rebuilding
      {scope_data_2, _socket_2} = ScopeBus.resolve(updated_socket, :test)
      assert scope_data_2 == scope_data
    end

    test "returns {nil, socket} for unregistered scope" do
      socket = new_socket() |> ScopeBus.init()
      {result, returned_socket} = ScopeBus.resolve(socket, :nonexistent)
      assert result == nil
      assert returned_socket == socket
    end
  end

  describe "available?/2" do
    test "returns true for registered scope" do
      socket =
        new_socket()
        |> ScopeBus.init()
        |> ScopeBus.register(test: TestScope)

      assert ScopeBus.available?(socket, :test) == true
    end

    test "returns false for unregistered scope" do
      socket = new_socket() |> ScopeBus.init()
      assert ScopeBus.available?(socket, :missing) == false
    end
  end

  describe "get/2" do
    test "returns nil before resolve" do
      socket =
        new_socket()
        |> ScopeBus.init()
        |> ScopeBus.register(test: TestScope)

      assert ScopeBus.get(socket, :test) == nil
    end

    test "returns scope data after resolve" do
      socket =
        new_socket()
        |> ScopeBus.init()
        |> ScopeBus.register(test: TestScope)

      {_data, socket} = ScopeBus.resolve(socket, :test)
      assert ScopeBus.get(socket, :test) == %{role: :admin, permissions: [:read, :write]}
    end
  end

  describe "can?/3" do
    test "delegates to scope module correctly" do
      socket =
        new_socket()
        |> ScopeBus.init()
        |> ScopeBus.register(test: TestScope)

      assert ScopeBus.can?(socket, :test, :read) == true
      assert ScopeBus.can?(socket, :test, :delete) == false
    end

    test "returns false for unregistered scope" do
      socket = new_socket() |> ScopeBus.init()
      assert ScopeBus.can?(socket, :missing, :read) == false
    end
  end

  describe "feature?/3" do
    test "delegates to scope module when feature?/2 is implemented" do
      socket =
        new_socket()
        |> ScopeBus.init()
        |> ScopeBus.register(test: TestScope)

      assert ScopeBus.feature?(socket, :test, :beta) == true
      assert ScopeBus.feature?(socket, :test, :gamma) == false
    end

    test "returns false when scope module does not implement feature?/2" do
      socket =
        new_socket()
        |> ScopeBus.init()
        |> ScopeBus.register(minimal: MinimalScope)

      assert ScopeBus.feature?(socket, :minimal, :anything) == false
    end

    test "returns false for unregistered scope" do
      socket = new_socket() |> ScopeBus.init()
      assert ScopeBus.feature?(socket, :missing, :beta) == false
    end
  end
end
