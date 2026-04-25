# Parallel Luau Reference

Actor-based multithreading. Source: [create.roblox.com/docs/scripting/multithreading](https://create.roblox.com/docs/scripting/multithreading).

By default Luau runs on a single thread. Parallel Luau lets independent work run on multiple OS threads, gated through `Actor` Instances.

---

## When to use it

Good fits:

- **Server-side hit validation** — one actor per character, parallel raycasting on RemoteEvent fires.
- **Procedural generation** — terrain chunks, dungeon rooms, large world-build passes.
- **Large independent computations** — pathfinding many NPCs, AI sims.
- **Anything CPU-bound that doesn't need to mutate the DataModel often.**

Bad fits:

- Code that mostly mutates Instances (you'll spend time `task.synchronize`'d).
- Cheap work — actor overhead exceeds the parallelism win.
- Long unyielding loops — even on a parallel thread, they still block that thread.
- Code that needs `require()` at runtime in the parallel phase (not allowed).

---

## Actor model

- An **`Actor`** is an Instance. Scripts that are descendants of an actor are eligible to run in parallel.
- A script's "owning actor" is its closest `Actor` ancestor. Don't nest actors.
- **Scripts in the same actor still run serially with respect to each other.** To get parallelism, split into multiple actors.
- Use **more actors than cores** for load balancing — the engine distributes them. 64 actors on a 4-core box is fine.
- Don't use *too* many — divide by logic units, not micro-units.

Place actors:

```
ServerScriptService/
  CombatActors/
    Actor (one per character)
      HitValidator.luau
```

---

## Phases

### Switching to parallel

```luau
-- Inside a script under an Actor
local function compute()
    task.desynchronize()              -- now parallel
    local result = expensiveMath()
    task.synchronize()                -- back to serial
    Workspace.Score.Value += result   -- safe DataModel write
end
```

`task.desynchronize()` yields and resumes at the next parallel-execution opportunity. `task.synchronize()` yields and resumes when the engine reaches the next serial point.

### Parallel-by-default connections

```luau
RunService.Heartbeat:ConnectParallel(function()
    -- already parallel; no need for task.desynchronize
    local hit = doRaycast()
    task.synchronize()
    applyDamage(hit)
end)
```

Most signals support `:ConnectParallel(...)`. The callback runs in parallel automatically. Saves the manual `desynchronize`.

### Hard rule

**`require()` cannot run in a parallel phase.** Require modules in serial first; pass them in or call from the serial portion.

---

## Thread safety

API members carry a thread-safety tag. The four levels:

| Level | Properties (parallel) | Functions (parallel) |
|---|---|---|
| Unsafe (default if untagged) | No read, no write | No call |
| Read Parallel | Read OK | n/a |
| Local Safe | Same-actor any; cross-actor read-only | Same-actor only |
| Safe | Read + write | Call from anywhere |

Most reads are safe; most writes are not. Common safe-in-parallel APIs: `Workspace:Raycast`, `BasePart.CFrame` (read), most math/CFrame/Vector3 work, `Random.new` instances.

Common unsafe-in-parallel: parenting changes, `:Destroy()`, `Instance.new` then parenting, most signal-firing operations.

The engine prevents unsafe access at runtime — you'll get an error rather than a corrupted state.

---

## Cross-thread communication

Three mechanisms.

### Actor messaging

```luau
-- Sender (anywhere)
workerActor:SendMessage("GenerateChunk", x, y, z, seed)

-- Receiver (script under workerActor)
local actor = script:GetActor()
actor:BindToMessageParallel("GenerateChunk", function(x, y, z, seed)
    local data = generate(x, y, z, seed)
    task.synchronize()
    writeChunk(data)
end)
```

- Async one-way. Sender doesn't block.
- Each topic can have multiple bindings on the same actor.
- Only descendants of an actor can bind for that actor.
- `:BindToMessage(topic, fn)` for serial callbacks; `:BindToMessageParallel(topic, fn)` for parallel.

### `SharedTable`

Table-like data structure shared across actors. Atomic updates. Sending to another actor doesn't copy the data.

```luau
local SharedTable = require(...)  -- or from globals depending on context

local state = SharedTable.new({ score = 0 })
workerActor:SendMessage("Tick", state)

-- in the worker
actor:BindToMessageParallel("Tick", function(state)
    SharedTable.increment(state, "score", 1)
end)
```

Use for "common world state not stored in DataModel" — large grids, voting tallies, accumulated counters.

### Direct DataModel reads/writes

Works in serial phases. In parallel phases, most writes are blocked by thread safety. Falling back to this for cross-thread comm forces frequent synchronization and erodes the parallelism gain.

---

## Pattern: per-character parallel raycasting

```luau
-- One actor per character, scripts placed under it on character spawn.
-- Each character's hit validation runs on its own thread.

remoteEvent.OnServerEvent:Connect(function(player, clickLocation: CFrame)
    local character = player.Character
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }

    task.desynchronize()
    local origin = tool.Handle.CFrame.Position
    local result = Workspace:Raycast(origin, (clickLocation.Position - origin) * 1.01, params)

    if result and result.Instance.Name == "block" then
        task.synchronize()
        if result.Instance.Parent then
            local explosion = Instance.new("Explosion")
            explosion.DestroyJointRadiusPercent = 0
            explosion.Position = clickLocation.Position
            explosion.Parent = Workspace
            result.Instance:Destroy()
        end
    end
end)
```

Multiple characters firing simultaneously each get their own thread; only the final mutation runs in serial.

---

## Best practices

- **Avoid long computations** — break work up with `task.wait` even in parallel.
- **More actors > fewer**, within reason. Divide by logic unit (one actor per NPC, one per chunk worker).
- **Don't share buffers across actors** (`buffer` library limitation; use `SharedTable` instead).
- **Pre-require modules in serial** — design for the parallel-no-require constraint.
- **Test with the actor count you'll ship with** — single-actor mode (the default behavior of code without actors) doesn't surface parallelism bugs.
