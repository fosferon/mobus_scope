# MobusScope

Lazy capability registry for Phoenix LiveView sockets.

Scopes are registered at mount but only built on first access — avoiding expensive
computation during mount when the scope data may not be needed for the current action.

## Installation

```elixir
def deps do
  [
    {:mobus_scope, "~> 0.1"}
  ]
end
```

## Concepts

- **Scope** — a capability domain (e.g., directory permissions, feature flags) defined by a module implementing `Mobus.Scope.Behaviour`
- **ScopeBus** — a lazy registry stored in socket assigns that builds scopes on demand

## Usage

### 1. Define a scope module

```elixir
defmodule MyApp.Scopes.AdminScope do
  @behaviour Mobus.Scope.Behaviour

  @impl true
  def build(socket) do
    user = socket.assigns.current_user
    %{role: user.role, permissions: user.permissions}
  end

  @impl true
  def can?(%{permissions: perms}, action), do: action in perms
end
```

### 2. Register scopes during mount

```elixir
def mount(_params, _session, socket) do
  socket =
    socket
    |> Mobus.Scope.ScopeBus.init()
    |> Mobus.Scope.ScopeBus.register(
      admin: MyApp.Scopes.AdminScope,
      directory: MyApp.Scopes.DirectoryScope
    )

  {:ok, socket}
end
```

### 3. Check permissions in your LiveView

```elixir
# Lazily builds the scope on first call, then caches it
{scope_data, socket} = Mobus.Scope.ScopeBus.resolve(socket, :admin)

# Quick permission check (auto-resolves if needed)
if Mobus.Scope.ScopeBus.can?(socket, :admin, :delete_users) do
  # show admin controls
end
```

### 4. Optional: feature flags

```elixir
# In your scope module
def feature?(_data, :beta_ui), do: true
def feature?(_data, _), do: false

# In your LiveView
if Mobus.Scope.ScopeBus.feature?(socket, :admin, :beta_ui) do
  # render beta UI
end
```

## API

| Function | Description |
|---|---|
| `init/1` | Initialize scope bus on socket (idempotent) |
| `register/2` | Register scope modules without building them |
| `resolve/2` | Build scope on first access, return `{data, socket}` |
| `get/2` | Get resolved scope data without triggering a build |
| `available?/2` | Check if a scope is registered |
| `can?/3` | Check permission (auto-resolves lazily) |
| `feature?/3` | Check feature flag (auto-resolves lazily) |

## License

MIT
