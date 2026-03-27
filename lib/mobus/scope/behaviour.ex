defmodule Mobus.Scope.Behaviour do
  @moduledoc """
  Defines the contract for scope modules used with `Mobus.Scope.ScopeBus`.

  A scope module encapsulates a capability domain (e.g., directory permissions,
  overlay access, feature flags) and provides two required callbacks:

    * `build/1` -- constructs scope data from a LiveView socket. Called lazily
      on first access via `ScopeBus.resolve/2`.

    * `can?/2` -- checks whether an action is permitted within the scope.

  An optional callback `feature?/2` can be implemented for feature-flag checks.

  ## Example

      defmodule MyApp.Scopes.AdminScope do
        @behaviour Mobus.Scope.Behaviour

        @impl true
        def build(socket) do
          user = socket.assigns.current_user
          %{role: user.role, permissions: user.permissions}
        end

        @impl true
        def can?(%{permissions: perms}, action), do: action in perms

        def feature?(_data, :beta_ui), do: true
        def feature?(_data, _), do: false
      end
  """

  @doc """
  Build scope data from the current socket state.

  Called once per scope per LiveView lifecycle (lazy, cached by ScopeBus).
  Should return a map of scope-specific data.
  """
  @callback build(socket :: Phoenix.LiveView.Socket.t()) :: map()

  @doc """
  Check whether an action is permitted within this scope.
  """
  @callback can?(scope_data :: map(), action :: atom()) :: boolean()

  @doc """
  Check whether a feature flag is enabled within this scope.

  Optional -- if not implemented, `ScopeBus.feature?/3` returns `false`.
  """
  @callback feature?(scope_data :: map(), feature :: atom()) :: boolean()

  @optional_callbacks [feature?: 2]
end
