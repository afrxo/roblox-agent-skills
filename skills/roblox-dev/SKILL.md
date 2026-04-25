---
name: roblox-dev
description: >
  How Roblox behaves at runtime. Use whenever writing, reviewing, or debugging
  server/client Roblox code that touches services, Instances, replication,
  RemoteEvents/Functions, character lifecycle, physics, DataStore, or platform
  caveats. Engine layer only — language rules live in luau-expert; UI libraries
  live in roblox-ui; Rojo/Wally workflow lives in roblox-toolchain.
---

# Roblox Engine

How the Roblox platform behaves at runtime. Sources: [create.roblox.com/docs](https://create.roblox.com/docs) for APIs and concepts; [devforum.roblox.com](https://devforum.roblox.com) for engineer clarifications and RFCs.

For deep dives see:

- [`references/replication-model.md`](references/replication-model.md) — what replicates from where, per-property rules, deferred-signal timing
- [`references/cloud-services.md`](references/cloud-services.md) — picker for data stores / memory stores / configs / secrets / in-memory
- [`references/datastore-rules.md`](references/datastore-rules.md) — rate limits, retry/backoff, session locking
- [`references/streaming-enabled.md`](references/streaming-enabled.md) — chunk semantics, `ModelStreamingMode`, client-side rules
- [`references/query-descendants.md`](references/query-descendants.md) — full `Instance:QueryDescendants` selector grammar
- [`references/buffer-library.md`](references/buffer-library.md) — full `buffer` library API
- [`references/parallel-luau.md`](references/parallel-luau.md) — actor model, ConnectParallel, SharedTable, thread safety
- [`references/performance-optimization.md`](references/performance-optimization.md) — full pitfall + mitigation list

---

## Integration Policy

This skill describes preferred patterns; it does **not** authorize rewriting existing code. Apply rules to new code and code the user explicitly asks to refactor. Match the codebase's existing style (casing, indentation, quote style, module shape) before applying skill defaults. Don't introduce tooling the project doesn't already use; surface conflicts once and default to the existing pattern.

Full rules: [`../../shared/integration-policy.md`](../../shared/integration-policy.md).

---

## Principles

- **Server is authoritative.** The client lies. Anything that affects game state (currency, inventory, damage, position-to-trust) lives on the server. The client signals intent; the server validates and applies.
- **State ownership is exclusive.** Every piece of state has one owner — server, the controlling client, or replication. Two writers means a race.
- **Replication is async.** Anything created server-side appears on clients on a future frame, not the same one. Anything created client-side does **not** replicate to the server.
- **Yielding is observable.** A yielding call inside an event handler runs other handlers in between. Order is not what you wrote.
- **Verify before quoting an API.** Roblox's API surface is huge and shifts. State uncertainty rather than hallucinate property names.

---

## Services — `GetService` Everything

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
```

- Use `game:GetService("Name")` always. Not `game.ServiceName`.
  - Some services aren't available at script runtime by default — `GetService` creates them; dot-indexing throws.
  - Some services don't share their class name with their accessor (e.g. `RunService` is internally "Run Service").
- **Prefer `Workspace` via `GetService` over the lowercase `workspace` global.** Both work; the global predates `GetService` and exists for compatibility. Sticking to `GetService` keeps every service access one consistent shape and surfaces typos as undefined-variable errors.
- Put `GetService` calls at the top of the file, alphabetical, no others scattered later.

---

## DataModel & Instances

- The DataModel is the tree rooted at `game`. Services are top-level children. Everything else is an Instance.
- An Instance is alive until its `Parent = nil` AND no script holds a reference. **Setting `Parent = nil` is not destruction.** Use `:Destroy()` to disconnect events, mark it as destroyed, and set `Parent` to nil.
- **`:Destroy()` is irreversible.** A destroyed Instance can't be re-parented; further property access throws.
- `:Clone()` requires `Archivable = true` (the default). Cloning a model includes its descendants; references between siblings are NOT rebound.

### Querying Descendants

- `:GetChildren()` — direct children only.
- `:GetDescendants()` — full subtree, unfiltered. Cheap for small trees, costly for large ones (e.g. a streamed Workspace).
- `:FindFirstChild(name)` / `:FindFirstChild(name, true)` — second arg = recursive.
- `:FindFirstChildOfClass(class)` / `:FindFirstChildWhichIsA(class)` — class-specific direct child.
- **`:QueryDescendants(selector: string)`** → `{ Instance }`. Engine-side filtered descendant query with a CSS-like selector grammar (`ClassName`, `.Tag`, `#Name`, `[prop = val]`, `[$attr]`, `[$attr = val]`, combinators `>` `>>` `,`, pseudo-classes `:not(...)` `:has(...)`). Prefer this over `GetDescendants` + Luau-side filter for large trees. Thread-unsafe. Full grammar + examples in [`references/query-descendants.md`](references/query-descendants.md).

  ```luau
  Workspace:QueryDescendants("MeshPart.SwordPart")              -- MeshParts tagged SwordPart
  Workspace:QueryDescendants("Model >> [$OnFire = true]")       -- attribute-matching descendants of any Model
  Workspace:QueryDescendants(":not(SpotLight, PointLight)")     -- excluding lights
  ```

### `WaitForChild` Rules

- On the **client**, children of replicated containers (e.g. `ReplicatedStorage`, `Workspace`) may not exist on the first frame. Use `:WaitForChild("Name")` for anything you didn't put there yourself.
- On the **server**, every Instance you placed in Studio exists at script start; `:FindFirstChild` is enough.
- Never call `WaitForChild` without a timeout in production code — it yields forever if the child never arrives. `:WaitForChild("Name", 5)` returns `nil` after 5 seconds.

---

## Script Types & Locations

Three script types:

- **`Script`** — runs on server **or** client depending on `Script.RunContext` and location.
  - `RunContext = Legacy` (default) → server-only, only runs in server containers (`ServerScriptService`, `Workspace`, etc.).
  - `RunContext = Server` → server, can run from `ReplicatedStorage` too (but don't — clients can read source).
  - `RunContext = Client` → client, runs from `ReplicatedStorage`. Recommended for new client scripts (clearer than `LocalScript`).
- **`LocalScript`** — client-only. No `RunContext`. Runs only in client containers: `StarterPlayerScripts`, `StarterCharacterScripts`, `StarterGui`, `StarterPack`, `ReplicatedFirst`.
- **`ModuleScript`** — `require()`-able from either side. Runs in the requirer's context.

### Recommended layout

| Where | What goes here | RunContext |
|---|---|---|
| `ServerScriptService` | Server scripts + server-only ModuleScripts | `Server` |
| `ServerStorage` | Server-only data (assets, tables) — clients never see contents | n/a |
| `ReplicatedStorage` | Shared ModuleScripts (server + client) **and** client scripts | `Client` for client scripts |
| `ReplicatedFirst` | Minimal client loader (e.g. loading screen) | `Client` |
| `StarterPlayerScripts` / `StarterCharacterScripts` / `StarterGui` / `StarterPack` | `LocalScript`s that run per-player | n/a |
| `Workspace` | World content. Server-side `Script`s for object behaviors. | `Server` if you want explicit |

Common practice: keep most code as ModuleScripts in `ReplicatedStorage` (shared) or `ServerStorage`/server-only spots, with **one** server entry-point `Script` in `ServerScriptService` that requires the modules, and **one** client entry-point in `ReplicatedStorage` (`RunContext = Client`).

### Rules

- **Don't put server logic in `ReplicatedStorage`.** Clients can read source; assume anything there is leaked.
- **Set `RunContext` explicitly on scripts inside models or packages** — removes ambiguity when the model is reparented or shared.
- **Use `RunService:IsServer()` / `:IsClient()`** for runtime branching in shared ModuleScripts. Don't infer from `script.Parent`.
- **`LocalScript`s in `Workspace` don't run.** Client-runnable containers only. Common bug.
- **Server scripts in `Workspace`** run, but `RunContext = Server` in `ServerScriptService` is clearer and less surprising when geometry moves.

Source: [create.roblox.com/docs/scripting/locations](https://create.roblox.com/docs/scripting/locations).

---

## Replication

- **Server → client is automatic** for replicated containers (`Workspace`, `ReplicatedStorage`, `Players[X].PlayerGui`, `StarterGui`-cloned-to-PlayerGui). Property changes and parenting changes replicate.
- **Client → server is NOT.** Anything a client creates or modifies stays local — the server never sees it. Exception: `Players[X].Character` (filtering era + character ownership), input events, and explicit `RemoteEvent` calls.
- Replication is **per-property**, not all-or-nothing. Some containers exist on both sides but their contents are client-local (`Player.PlayerScripts`, `Player.PlayerGui` after initial replication of `StarterGui`).
- **Set properties before parenting.** Once an Instance is in a replicated container, every subsequent property change replicates as its own update — clients can observe an intermediate state. Build the Instance fully, then set `Parent`.
- **Signal behavior matters.** `Workspace.SignalBehavior = Enum.SignalBehavior.Deferred` (the modern default in new places) batches signal firings until the next resumption point — code that assumes synchronous-fire `ChildAdded` is brittle. Test with deferred signals on.
- See [`references/replication-model.md`](references/replication-model.md) for the full table.

---

## RemoteEvents & RemoteFunctions

```luau
-- Server
local TakeDamage = ReplicatedStorage:WaitForChild("TakeDamage") :: RemoteEvent
TakeDamage.OnServerEvent:Connect(function(player, amount: unknown)
    if typeof(amount) ~= "number" or amount < 0 or amount > 100 then return end
    -- validated; apply
end)

-- Client
TakeDamage:FireServer(25)
```

- **`OnServerEvent` first arg is always the firing `Player`.** It's authentic — Roblox provides it. Don't trust anything else.
- Type every other parameter as `unknown` and validate at the boundary. Typing as `number` makes the type checker accept exploiter input. (See `luau-expert` skill for the full pattern.)
- **`RemoteFunction` is `:InvokeServer()` / `:InvokeClient()`** — synchronous (yields). Avoid client→server `InvokeClient` when you can; a malicious client can hang the call. Prefer `RemoteEvent` + reply event.
- **Rate-limit every Remote.** Track per-player call counts; reject obvious spam. Default: bounded queue, drop oldest or reject when full.
- **One Remote per logical action.** Don't multiplex with a `kind` field — types stay clearer and validation simpler.

---

## Character Lifecycle

```luau
local function onCharacterAdded(character: Model)
    local humanoid = character:WaitForChild("Humanoid") :: Humanoid
    -- ...
end

Players.PlayerAdded:Connect(function(player)
    if player.Character then onCharacterAdded(player.Character) end
    player.CharacterAdded:Connect(onCharacterAdded)
end)
```

- **A player's first character may already exist** when `PlayerAdded` fires. Check `player.Character` and connect to future `CharacterAdded`.
- **Each respawn is a new `Model`.** References to the old character become stale. Reconnect every per-character signal in `CharacterAdded`; use `character.AncestryChanged` or `humanoid.Died` to clean up the previous set.
- `Humanoid.Died` fires once per character. After death the model lingers (default ~5s, controlled by `Players.RespawnTime`) before automatic respawn destroys it.
- `Player.CharacterRemoving` fires before the model leaves `Workspace` — last chance to read state from it.

---

## Streaming

Modern places enable `Workspace.StreamingEnabled`. Parts of the world load and unload around each player.

- The client may not see a part the server sees. **Never assume client geometry exists** — `WaitForChild` (with timeout) or nil-check.
- Per-Model streaming is controlled via `Model.ModelStreamingMode`:
  - `Default` — model streams normally, descendants stream independently.
  - `Atomic` — the whole model streams in/out as a single unit (no partial loads).
  - `Persistent` — the model is always loaded for every client.
  - `PersistentPerPlayer` — always loaded for players added via the relevant `Add`/`Remove` API; off by default for others.
- Use `Atomic` for objects whose descendants must arrive together (vehicle assemblies, NPC rigs). Use `Persistent` sparingly — it costs memory on every client.
- Replication of property changes still occurs for streamed-out parts; the client just doesn't render them. Don't drive `BasePart.CFrame` updates on streamed-out objects — wasted bandwidth.
- See [`references/streaming-enabled.md`](references/streaming-enabled.md) for chunk semantics and `ModelStreamingMode` interactions.

---

## Physics Ownership

- Each unanchored `BasePart` has a network owner. Default: server. When a player's character touches/steps on/holds a part, ownership transfers to that player's client.
- The owner simulates physics; the result replicates back. **A client-owned part is not server-authoritative for position** — never trust its `CFrame` for game-state decisions.
- Force ownership server-side: `part:SetNetworkOwner(player)` — pass `nil` to give it back to the server. `:GetNetworkOwner()` reads it.
- **Anchored parts have no owner.** `SetNetworkOwner` errors on an anchored part. Check with `BasePart:CanSetNetworkOwnership()` first if you don't control the input.
- **Auto-transfer is the default.** Once you call `:SetNetworkOwner(player)` or `:SetNetworkOwner(nil)`, auto-transfer is **off** for that part — ownership stays where you set it. Call `:SetNetworkOwnershipAuto()` to put it back on auto.
- For anything the player must not be able to teleport (chests, NPCs, projectiles, anti-cheat-relevant parts) — `SetNetworkOwner(nil)` once, never `SetNetworkOwnershipAuto()`.

---

## Cloud Services (Persistence & Cross-Server)

Roblox offers several storage options. Pick by access pattern, not by reflex.

| Service | Persistence | Scope | Use for |
|---|---|---|---|
| **Standard data stores** (`DataStoreService:GetDataStore`) | Permanent | Cross-server | User progress, inventory, save data. Numbers/strings/booleans/tables. NoSQL-like. |
| **Ordered data stores** (`:GetOrderedDataStore`) | Permanent | Cross-server | All-time leaderboards (numbers only, sortable). |
| **Memory stores** (`MemoryStoreService`) | ≤ 45 days | Cross-server | Matchmaking, daily/monthly leaderboards, ephemeral cross-server queues. Faster than data stores. |
| **Configs** (Creator Hub) | Permanent | Cross-server | Feature flags, tunable values. Read-only from in-game. |
| **Secrets stores** | Permanent | Cross-server | API keys, third-party tokens. Read-only from in-game. |
| **In-memory Luau table** | Session | Single server | Temporary state (timers, status effects, current health). Free, instant. |

**Cloud services are server-only.** Clients can't read DataStores, MemoryStores, etc. Route any client need through a RemoteEvent.

### Data-store core rules

- **Always `pcall`.** Reads/writes throw on network failure, throttling, and quota exhaustion.
- **`UpdateAsync` for concurrent state** (not `SetAsync`) — gives you the previous value and merges atomically. Return `nil` from the transform to abort without burning quota.
- **Session-lock pattern**: read once on `PlayerAdded`, mutate in-memory for the session, save on `PlayerRemoving` + `BindToClose`. Don't read on every change.
- **`game:BindToClose`** has a ~30-second total budget across all players. Save in parallel via `task.spawn`.
- **Rate limits are per-key + per-game**, refilled over time. There's also a hard ~6-second-per-key rule.

### Memory-store core rules

- **Ephemeral**: data expires after up to 45 days. Don't put save data here.
- Useful primitives: queues, sorted maps, hash maps. Higher write throughput than data stores.
- Server-only API.

See [`references/cloud-services.md`](references/cloud-services.md) for the full picker (when to use which) and [`references/datastore-rules.md`](references/datastore-rules.md) for data-store rate limits, retry/backoff, and session-locking patterns.

Source: [create.roblox.com/docs/cloud-services/data-stores-vs-memory-stores](https://create.roblox.com/docs/cloud-services/data-stores-vs-memory-stores).

---

## Task Scheduling

The `task` library replaces classic `wait`/`spawn`/`delay`. Use it.

| Call | When |
|---|---|
| `task.spawn(f, ...)` | Run `f` on a new thread immediately (resumes after current resumption point). Use to detach a yielding body from an event handler. |
| `task.defer(f, ...)` | Run `f` after the current resumption cycle finishes — later than `spawn`. Use to coalesce work without yielding. |
| `task.delay(t, f, ...)` | Run `f` after `t` seconds on a new thread. Replaces the legacy `delay`. |
| `task.wait(t)` | Yield current thread for `t` seconds (or one frame if omitted). Replaces `wait`. |
| `task.cancel(thread)` | Kill a thread started by `task.spawn`/`task.delay`. Pair with explicit cleanup. |
| `task.synchronize()` / `task.desynchronize()` | Parallel-Luau actor coordination. See the [Parallel Luau](#parallel-luau-multithreading) section below. |

- **Don't use the legacy globals** `wait`, `spawn`, `delay`. They throttle (`wait` clamps to ~30 Hz) and leak in patterns the `task` versions don't.
- **`task.spawn` inside an event handler** lets fast-firing events run concurrently. Add your own queue/lock if the body mutates shared state.
- **`task.defer` before `task.spawn`** when you want the work to happen after the current event-handling pass — useful inside `:Connect` bodies that mutate the world and trigger more signals.
- Track threads from `task.spawn`/`task.delay` if they need cancellation; nothing auto-cancels on Instance destruction.

---

## Buffer Library (Binary Data)

`buffer` is Luau's fixed-size mutable byte block. Source: [`buffer.yaml` in creator-docs](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/libraries/buffer.yaml).

Use it for:

- Compact RemoteEvent payloads (a packed buffer is smaller than a Luau table over the wire).
- Custom binary serialization for DataStore values you want to keep small.
- Reading/writing existing binary formats.
- Replacing `string.pack` / `string.unpack` use cases.

```luau
local b = buffer.create(16)        -- 16-byte buffer, zero-initialized
buffer.writeu32(b, 0, 0xCAFEBABE)  -- 4 bytes at offset 0
buffer.writef32(b, 4, 1.5)         -- 4 bytes at offset 4
buffer.writestring(b, 8, "abc")    -- 3 bytes at offset 8

local magic = buffer.readu32(b, 0)
local payload = buffer.readstring(b, 8, 3)
```

Key rules:

- **All offsets are byte offsets from 0.** Reading/writing past the buffer raises an error.
- **Little-endian** for every numeric read/write.
- **Max buffer size: 1 GiB** (`buffer.create` rejects larger; allocations near that may fail anyway).
- **Sent across Roblox APIs (RemoteEvents, etc.) by copy.** Identity is not preserved on the receiver. Don't share a buffer between Actor scripts (Parallel Luau).
- **Fixed size.** No grow/shrink — allocate the right size, or copy into a new one (`buffer.copy`).

Functions in three groups:

- **Lifecycle:** `buffer.create(size)`, `buffer.fromstring(s)`, `buffer.tostring(b)`, `buffer.len(b)`.
- **Read/write fixed-width numerics:** `readi8`/`u8`/`i16`/`u16`/`i32`/`u32`/`f32`/`f64` and matching `write*`.
- **Bit-level + bulk:** `readbits(b, bitOffset, bitCount)` / `writebits` (0–32 bits per call), `readstring(b, offset, count)` / `writestring(b, offset, value, count?)`, `buffer.copy(target, targetOffset, source, sourceOffset?, count?)`, `buffer.fill(b, offset, value, count?)`.

Full signature reference in [`references/buffer-library.md`](references/buffer-library.md).

---

## Parallel Luau (Multithreading)

By default Luau is single-threaded. **Parallel Luau** lets independent work run on multiple OS threads via the `Actor` model. Use it for CPU-bound work that can be split: per-player raycast validation, procedural generation, large per-instance computations.

### Actor model

- Scripts under an `Actor` Instance are eligible to run in parallel.
- **One thread per actor.** Multiple scripts in the *same* actor still run serially with respect to each other.
- More actors = better load balancing, even on devices with fewer cores than actors.
- Don't nest actors as descendants of other actors — a script's owning actor is its closest ancestor.

### Phases: serial vs parallel

Code runs **serially** by default. Switch in/out:

```luau
-- Inside an Actor's script
RunService.Heartbeat:ConnectParallel(function()
    -- parallel phase
    local result = computeExpensive()
    task.synchronize()
    -- serial phase
    applyResult(result)
end)
```

- **`task.desynchronize()`** — switch current thread to parallel. Yields, resumes at next parallel-execution opportunity.
- **`task.synchronize()`** — switch back to serial. Required before mutating most Instances.
- **`Signal:ConnectParallel(callback)`** — schedule a signal callback to run in parallel automatically; no need for `desynchronize` inside.
- **`require()` is not allowed in a parallel phase.** Require modules in serial first.

### Thread safety levels

API members carry a thread-safety tag:

| Level | Properties | Functions |
|---|---|---|
| **Unsafe** | No parallel read or write | No parallel call |
| **Read Parallel** | Read OK, write not | n/a |
| **Local Safe** | Same-actor any; cross-actor read-only | Same-actor only |
| **Safe** | Read + write | Call from anywhere |

Default is `Unsafe` if untagged. Most read-heavy access (geometry queries, raycasts) is safe; most mutations are not. Check the API reference per-member.

### Cross-thread communication

- **`Actor:SendMessage(topic, ...)`** + **`Actor:BindToMessage(topic, fn)`** / **`:BindToMessageParallel(topic, fn)`** — async one-way messaging. Multiple bindings per topic allowed.
- **`SharedTable`** — table-like structure shared across actors with atomic updates. No copy on send. Use for "common world state not stored in DataModel".
- **Direct DataModel writes** in serial phases work but force frequent synchronization.

### When **not** to use it

- **Long uninterrupted computations.** Even on a parallel thread, a 100ms unyielding loop still blocks that thread for 100ms. Break work up.
- **Cheap per-frame work.** Actor overhead dwarfs the savings for trivial tasks.
- **Code that mostly mutates the DataModel.** You'll spend most of your time `task.synchronize`'d, defeating the point.

Full deep-dive: [`references/parallel-luau.md`](references/parallel-luau.md). Source: [create.roblox.com/docs/scripting/multithreading](https://create.roblox.com/docs/scripting/multithreading).

---

## Performance

Performance optimization is a cycle: **design** for it up front, **identify** hot spots with the MicroProfiler, **mitigate**, **monitor**. Below is the high-signal subset; full pitfall list in [`references/performance-optimization.md`](references/performance-optimization.md).

### Frame budget

- Target: **60 FPS = 16.67 ms per frame** for the client. Server has no frame rate but `RunService.Heartbeat` plays the same role.
- Anything Luau-side that consistently runs >1 ms per frame is a candidate for optimization.

### Top mistakes

- **Heavy work on `RunService.Heartbeat`** (or `PreSimulation`/`PostSimulation`/`PreRender`/`PreAnimation`). Heartbeat fires every frame — gate by interval (`if now - last < 0.1 then return end`) or move work to a slower loop.
- **Server-side `TweenService`.** Replicates the tweened property every frame; stutters under latency. Tween on the client unless the result must be authoritative.
- **Connections to `Player` / character that never disconnect.** `Player` Instances aren't auto-destroyed on leave (see `Workspace.PlayerCharacterDestroyBehavior` to opt in to auto-destroy). Track and disconnect explicitly, or destroy manually in `PlayerRemoving`.
- **Tables that grow without bounds.** `playerInfo[player] = ...` on join without `playerInfo[player] = nil` on leave is a classic server leak.
- **Deep cloning large tables.** Use shallow copy; mutate only the path that changed (cross-link `luau-expert` skill).
- **Large RemoteEvent payloads.** Send deltas, not whole inventories. For high-frequency state, pack into a `buffer`.
- **Excessive instance creation/destruction.** Cloning large rigs at runtime replicates the entire descendant tree to clients. Pre-instance pools beat per-event instantiation.
- **Unanchored parts that don't move.** `Anchored = true` removes them from physics simulation entirely.
- **High `CollisionFidelity`.** `Precise` is expensive in CPU and memory. Use `Box`/`Hull` for anything where the player won't notice.
- **Asset duplication.** Same mesh/texture uploaded multiple times = same content in memory multiple times. Reuse asset IDs.
- **Animation metadata in published rigs.** Animation Editor data on a cloned rig replicates with every clone. Strip it before publish.
- **`PreloadAsync` over the entire Workspace** for a "no pop-in" loading screen. Preload only what the loading screen and starting area need.
- **Native code generation** (`--!native`) for hot, unyielding compute paths is a low-effort win — verify the function actually runs hot first.

### MicroProfiler scopes worth knowing

- `RunService.Heartbeat` / `PreRender` / `PreSimulation` / `PostSimulation` — your scripts.
- `physicsStepped` / `worldStep` — physics cost.
- `ProcessPackets` / `Allocate Bandwidth` — network cost.
- `updateInvalidatedFastClusters` — humanoid/skinned-mesh churn.

Tag your own scopes with `debug.profilebegin("Name")` / `debug.profileend()`.

Sources: [create.roblox.com/docs/performance-optimization](https://create.roblox.com/docs/performance-optimization), [/improve](https://create.roblox.com/docs/performance-optimization/improve).

---

## Bug Catalog

### Duplicate Connections

```luau
-- ❌ every CharacterAdded adds another connection; old ones never disconnect
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        char.Humanoid.Died:Connect(function() ... end)   -- leaks per respawn
    end)
end)
```

Track and disconnect connections per scope. A common pattern: store `{ RBXScriptConnection }` keyed by the lifecycle owner (player, character, instance), iterate and `:Disconnect()` on cleanup.

### Stale References

```luau
local character = player.Character
task.wait(5)
character.Humanoid.Health = 0     -- ❌ player may have respawned; old model is destroyed
```

Re-fetch `player.Character` after any yield, or capture+verify with `if character.Parent == nil then return end`.

### Yielding in Event Handlers

```luau
RemoteEvent.OnServerEvent:Connect(function(player)
    task.wait(1)              -- ❌ all subsequent fires from this player wait behind this one
    grantReward(player)
end)
```

Either don't yield in handlers, or `task.spawn` the body so each fire runs independently. Be careful with `task.spawn` — concurrent state updates need a lock.

### Memory Leaks

- `Instance:Destroy()` disconnects events and removes from the DataModel, but doesn't break Lua-side references. Set the variable to `nil` if it's long-lived.
- Connections to *non*-Roblox signals (custom signals, libraries) don't auto-clean. Track and disconnect them.
- Closures capturing large tables in `:Connect(...)` keep those tables alive as long as the connection exists.

### CollectionService Cleanup

```luau
-- ❌ tag handler runs once per existing tagged instance, then once per new one
CollectionService:GetTagged("Door"):forEach(setupDoor)
CollectionService:GetInstanceAddedSignal("Door"):Connect(setupDoor)
```

Always pair with `GetInstanceRemovedSignal` for cleanup. Track per-instance state in a `{ [Instance]: State }` map, not in closures. Use `instance.AncestryChanged` (when `parent == nil`) or the removed signal.

### Race: Player Joining Mid-Setup

`PlayerAdded` fires for players already in the server when your script starts (binding via `:Connect` only catches future fires) — handle existing players manually:

```luau
for _, player in Players:GetPlayers() do onPlayerAdded(player) end
Players.PlayerAdded:Connect(onPlayerAdded)
```

---

## Architecture Rules

- **Validate every server boundary.** RemoteEvent params, DataStore reads, MessagingService payloads, HttpService responses, anything user-influenced.
- **Server-authoritative checks beat client checks.** Client-side validation is UX (instant feedback). Server-side validation is security. Never one without the other.
- **One ModuleScript = one concern.** Don't aggregate into giant "Manager" modules — stack focused modules with clear ownership. (See `luau-expert` for module/file structure rules.)
- **One owner per piece of state.** A field is server-owned, replicated-only, or client-owned. Never two writers. If multiple actors must update something, route through one module that serializes the writes.
- **Centralize replication.** One module per replicated domain (inventory, currency, quest progress) — not Remotes scattered through the codebase. Easier to audit, easier to add validation/rate-limit.
- **Don't trust client-supplied UserIds.** A `UserId` you read off any real `Player` Instance (the `OnServerEvent` first arg, `Players:GetPlayers()`, `Players:GetPlayerByUserId`) is authentic. A `UserId` the client sends as a RemoteEvent argument is just a number — validate or ignore.
- **Idempotent server handlers.** Replays from network stutter or replays from exploiters are real. Design RemoteEvent handlers so two identical fires produce the same end state.
- **Expensive work goes server-side.** Pathfinding, large queries, anything CPU-heavy. Client devices vary wildly; server is uniform.
- **Don't build cross-server state on `MessagingService` alone.** It's best-effort, not guaranteed delivery, and rate-limited per-game. Use it for "interesting events" notifications, not for synchronizing state.
- **Match script container to runtime.** Server logic in `ServerScriptService`/`ServerStorage`; client logic in `StarterPlayerScripts`/`StarterCharacterScripts`/`StarterGui`; shared modules in `ReplicatedStorage`. Don't put server-only logic in `ReplicatedStorage` — clients can read it.

---

## Verification Rules

- **Don't quote API signatures from memory** for properties beyond the most stable surface (`Instance.Parent`, `BasePart.CFrame`, `Humanoid.Health`, etc.). Roblox renames, deprecates, and adds. When unsure, point the user at [create.roblox.com/docs](https://create.roblox.com/docs) and state your uncertainty.
- **Behavior beats API.** Phrase rules as "the server is authoritative for…" rather than "use `Workspace.StreamingMinRadius = 256`" — the property may be renamed; the principle won't.
- **Distinguish stable from changing.** DataModel hierarchy, services, replication direction, character lifecycle: stable for years. New APIs (e.g. recent `Workspace` properties, new `RunService` methods, scripting-related betas): verify before recommending.
- **Don't conflate engine and language.** If the question is about typing or `--!strict` behavior, defer to `luau-expert`. If it's about Rojo or filesystem layout, defer to `roblox-toolchain`. If it's about UI libraries, defer to `roblox-ui`.

---

## Anti-Patterns

| ❌ Don't | ✅ Do |
|---|---|
| `game.Workspace` / `workspace` global | `game:GetService("Workspace")` |
| `game.Players.PlayerAdded:Connect(f)` only | Iterate `:GetPlayers()` then `:Connect` for joins-during-startup |
| `child = parent:FindFirstChild("X")` on client | `:WaitForChild("X", timeout)` |
| Trust client RemoteEvent args by type annotation | Type as `unknown`, validate, narrow |
| `RemoteFunction:InvokeClient` | `RemoteEvent` round-trip |
| One Remote multiplexing many actions via `kind` field | One Remote per action |
| `SetAsync` for concurrent state | `UpdateAsync` |
| DataStore call without `pcall` | Always `pcall` + retry/backoff |
| Read DataStore on every change | Session-cached; write on PlayerRemoving + BindToClose |
| Store character ref across yields | Re-fetch `player.Character` after any yield |
| Connect-without-disconnect across respawns | Track + disconnect connections per character |
| `Instance.Parent = nil` for cleanup | `:Destroy()` |
| `WaitForChild` without timeout | `:WaitForChild("X", 5)` and handle nil |
| Client-side validation only | Always validate on server |
| Yield inside an event handler that fires often | `task.spawn` the body; serialize via your own queue |
| Auto network ownership for sensitive parts | Explicit `SetNetworkOwner(nil)` |
| `pairs` over a tag set without removed-signal pair | Pair `GetInstanceAddedSignal` with `GetInstanceRemovedSignal` |
| Server logic in `ReplicatedStorage` | `ServerScriptService` / `ServerStorage` |
| `LocalScript` in `Workspace` | Client containers (`StarterPlayerScripts`, etc.) or `Script` with `RunContext = Client` in `ReplicatedStorage` |
| `wait` / `spawn` / `delay` legacy globals | `task.wait` / `task.spawn` / `task.defer` / `task.delay` |
| Heavy work directly on `RunService.Heartbeat` | Throttle / move to slower loop / `task.delay` |
| Server-side `TweenService` for visual tweens | Tween on the client; replicate target only |
| Cloning large rigs at runtime per event | Pool / pre-instance |
| `CollisionFidelity = Precise` on small parts | `Box` / `Hull` |
| Mutating Instances inside a parallel phase | `task.synchronize()` first |
| Storing API keys in DataStores | Secrets stores |
| Save data in MemoryStore | Standard data stores |

---

## Examples

- [`examples/services-header.luau`](examples/services-header.luau) — canonical service-import block.
- [`examples/character-lifecycle.luau`](examples/character-lifecycle.luau) — joining, character add/remove, per-character cleanup.
- [`examples/remote-handler.luau`](examples/remote-handler.luau) — RemoteEvent server handler with validation and rate limiting.
- [`examples/datastore-session.luau`](examples/datastore-session.luau) — load on join, session-cached, save on remove + BindToClose.
- [`examples/connection-tracker.luau`](examples/connection-tracker.luau) — disposable scope for batched `:Disconnect()`.
