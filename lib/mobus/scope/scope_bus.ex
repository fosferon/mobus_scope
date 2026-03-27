defmodule Mobus.Scope.ScopeBus do
  @moduledoc """
  Lazy scope registry for Phoenix LiveView sockets.

  Scopes are registered at mount but only built on first access. This avoids
  expensive computation during mount when the scope data may not be needed
  for the current action.

  ## Usage

  LiveView macros declare scopes during `__using__`:

      socket
      |> ScopeBus.init()
      |> ScopeBus.register(directory: MyApp.Scopes.DirectoryScope,
                           overlay: MyApp.Scopes.OverlayScope)

  Scopes are stored in `socket.assigns.__scope_bus__` as a map of
  `scope_key => {module, :pending | scope_data}`.

  On first `resolve/2` call, the scope module's `build/1` is called with
  the socket, and the result is cached.
  """

  import Phoenix.Component, only: [assign: 3]

  @type scope_key :: atom()
  @type scope_entry :: {module(), :pending} | {module(), map()}
  @type scope_bus :: %{scope_key() => scope_entry()}

  @doc """
  Initialize the scope bus on a socket (called once during mount).

  Idempotent -- if already initialized, returns the socket unchanged.
  """
  @spec init(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def init(socket) do
    case Map.get(socket.assigns, :__scope_bus__) do
      nil -> assign(socket, :__scope_bus__, %{})
      _existing -> socket
    end
  end

  @doc """
  Register available scopes without building them.

  `scope_modules` is a keyword list of `[scope_key: ScopeModule]`.
  Does not overwrite already-registered scopes.
  """
  @spec register(Phoenix.LiveView.Socket.t(), keyword(module())) :: Phoenix.LiveView.Socket.t()
  def register(socket, scope_modules) when is_list(scope_modules) do
    bus = Map.get(socket.assigns, :__scope_bus__, %{})

    updated_bus =
      Enum.reduce(scope_modules, bus, fn {key, mod}, acc ->
        Map.put_new(acc, key, {mod, :pending})
      end)

    assign(socket, :__scope_bus__, updated_bus)
  end

  @doc """
  Build scope on first access, cache in assigns.

  Returns `{scope_data, updated_socket}`.
  If scope is not registered, returns `{nil, socket}`.
  """
  @spec resolve(Phoenix.LiveView.Socket.t(), scope_key()) ::
          {map() | nil, Phoenix.LiveView.Socket.t()}
  def resolve(socket, scope_key) do
    bus = Map.get(socket.assigns, :__scope_bus__, %{})

    case Map.get(bus, scope_key) do
      {mod, :pending} ->
        scope_data = mod.build(socket)
        updated_bus = Map.put(bus, scope_key, {mod, scope_data})
        updated_socket = assign(socket, :__scope_bus__, updated_bus)
        {scope_data, updated_socket}

      {_mod, scope_data} when is_map(scope_data) ->
        {scope_data, socket}

      nil ->
        {nil, socket}
    end
  end

  @doc """
  Check if a scope is registered (not necessarily built).
  """
  @spec available?(Phoenix.LiveView.Socket.t(), scope_key()) :: boolean()
  def available?(socket, scope_key) do
    bus = Map.get(socket.assigns, :__scope_bus__, %{})
    Map.has_key?(bus, scope_key)
  end

  @doc """
  Get scope data if already resolved, without triggering a build.

  Returns `nil` if not registered or not yet built.
  """
  @spec get(Phoenix.LiveView.Socket.t(), scope_key()) :: map() | nil
  def get(socket, scope_key) do
    bus = Map.get(socket.assigns, :__scope_bus__, %{})

    case Map.get(bus, scope_key) do
      {_mod, scope_data} when is_map(scope_data) -> scope_data
      _ -> nil
    end
  end

  @doc """
  Check a permission within a scope.

  Resolves the scope lazily if still pending. If scope isn't registered,
  returns `false` (safe default).
  """
  @spec can?(Phoenix.LiveView.Socket.t(), scope_key(), atom()) :: boolean()
  def can?(socket, scope_key, action) do
    bus = Map.get(socket.assigns, :__scope_bus__, %{})

    case Map.get(bus, scope_key) do
      {mod, scope_data} when is_map(scope_data) ->
        mod.can?(scope_data, action)

      {mod, :pending} ->
        scope_data = mod.build(socket)
        mod.can?(scope_data, action)

      nil ->
        false
    end
  end

  @doc """
  Check if a feature flag is enabled within a scope.

  Resolves the scope lazily if still pending. Returns `false` if scope
  isn't registered or the scope module doesn't implement `feature?/2`.
  """
  @spec feature?(Phoenix.LiveView.Socket.t(), scope_key(), atom()) :: boolean()
  def feature?(socket, scope_key, feature) do
    bus = Map.get(socket.assigns, :__scope_bus__, %{})

    case Map.get(bus, scope_key) do
      {mod, scope_data} when is_map(scope_data) ->
        if function_exported?(mod, :feature?, 2) do
          mod.feature?(scope_data, feature)
        else
          false
        end

      {mod, :pending} ->
        scope_data = mod.build(socket)

        if function_exported?(mod, :feature?, 2) do
          mod.feature?(scope_data, feature)
        else
          false
        end

      nil ->
        false
    end
  end
end
