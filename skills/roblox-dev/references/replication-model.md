# Replication Model Reference

What replicates from where, what doesn't, and the timing rules.

Source: [create.roblox.com/docs/scripting/networking](https://create.roblox.com/docs) (replication, FilteringEnabled era and current model).

---

## Replication direction

| From → To | Replicates? | Notes |
|---|---|---|
| Server → all clients | ✅ automatic | For Instances under `Workspace`, `ReplicatedStorage`, `ReplicatedFirst`. |
| Server → one client | ✅ automatic | For Instances under `Players[X].PlayerGui`, `Players[X].Backpack`. |
| Client → server | ❌ | Anything a client creates or modifies in `Workspace` etc. stays local. **Exceptions:** `Player.Character` (filtered), input events, explicit `RemoteEvent`/`RemoteFunction` calls. |
| Client → other clients | ❌ | Always goes through the server. |

Server-only containers: `ServerStorage`, `ServerScriptService`. Clients never see them.

---

## Per-property replication

Replication is per-property, not all-or-nothing.

- Visual properties (`CFrame`, `Color`, `Material`, `Transparency`, `Size`) replicate.
- Some scripted properties replicate, some don't. Check the [docs](https://create.roblox.com/docs/reference/engine) for the specific class.
- Attributes set with `:SetAttribute(name, value)` replicate.
- `Tags` from `CollectionService` replicate.
- `Player.PlayerScripts` exists on both sides but its contents are owned by the client; server changes don't reach the client.
- `Player.PlayerGui` initially populated from `StarterGui` on character spawn; subsequent server-side adds/removes replicate, but client-local additions are client-only.

---

## Replication timing & ordering

- **Replication is async.** Anything created server-side appears on clients on a future frame, not the same one.
- **Set properties before parenting.** Once an Instance is in a replicated container, every change replicates as its own message. Build it fully, then `Parent = ...` last.
- **Don't rely on synchronous-fire signals.** With `Workspace.SignalBehavior = "Deferred"` (modern default), signals batch until the next resumption point. Code that does `child.Parent = parent; assert(parent:FindFirstChild(child.Name))` works; code that registers a one-shot listener and immediately reparents may miss the firing depending on signal mode.
- **Initial replication on join** — clients receive a snapshot of replicated state when they join, then incremental updates. `WaitForChild` exists because that snapshot may not include a child you wrote on the server before the client could see it.

---

## Trust boundaries

- **`Player` argument on `OnServerEvent`/`OnServerInvoke`** — authentic. Provided by the engine.
- **Every other `RemoteEvent` argument** — untrusted. Type as `unknown` and validate.
- **Client-set properties** that replicate (e.g. character `CFrame`) — observable but not trustworthy. Validate position deltas, speed, etc. against expectations before acting.
- **`MessagingService` payloads** — cross-server messages. Untrusted as far as game state goes; one bad server can publish anything. Validate and rate-limit.

---

## When in doubt

- Test in Studio with **Local Server** (multiple clients + one server). Reproduces actual replication behavior; running in Edit mode does not.
- For specific properties, the docs page for the class lists `Replication` and `Security` per property. Read it before assuming.
