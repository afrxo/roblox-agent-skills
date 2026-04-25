# Performance Optimization Reference

Comprehensive pitfall + mitigation list. Sources: [create.roblox.com/docs/performance-optimization](https://create.roblox.com/docs/performance-optimization), [/improve](https://create.roblox.com/docs/performance-optimization/improve).

The cycle: **design** → **identify** (MicroProfiler, Developer Console) → **improve** → **monitor**.

Targets:

- Client: 60 FPS = 16.67 ms/frame.
- Server: `Heartbeat` cadence = the equivalent — keep heartbeat work small.
- Memory: track `LuaHeap`, `InstanceCount`, `PlaceScriptMemory` in the Developer Console.

---

## Script computation

Common problems:

- **Expensive work on every-frame events**: `Heartbeat`, `PreSimulation`, `PostSimulation`, `PreRender`, `PreAnimation`. Anything called from a tight loop body 60×/sec adds up fast.
- **Recursive table operations**: deep clones, deep equality checks, large serialization passes. Cost grows with nesting and table size.
- **Yields in tight per-event handlers** (see `roblox-dev` Bug Catalog).

Mitigations:

- Throttle: keep a `local last = 0` and only do work when `now - last >= interval`.
- Move occasional work off `Heartbeat` to a slower loop:
  ```luau
  task.spawn(function()
      while true do
          task.wait(0.5)
          maintainState()
      end
  end)
  ```
- Break long work across frames with `task.wait()` between chunks.
- Move CPU-bound work to **Parallel Luau** when it doesn't need DataModel mutation (see `parallel-luau.md`).
- For hot computational paths, consider `--!native` (Native Code Generation) — verify with the MicroProfiler before adopting.

---

## Script memory leaks

Common sources:

- **Connections that stay connected.** The engine keeps the connection callback (and everything it captures) alive until the connection is disconnected or its Instance is destroyed.
- **`Player` Instances are not auto-destroyed on leave.** Connections to `Player` and per-character signals survive across the leave unless you disconnect them. Multiplied across hundreds of joins/leaves this is a major server leak source.
- **Tables that grow without removal**: `playerData[player] = {...}` on join without `playerData[player] = nil` on leave.
- **Closures capturing large tables in `:Connect(...)`**: the closure keeps the table alive as long as the connection lives.

Mitigations:

- **Disconnect connections** explicitly, or destroy the owning Instance, or rely on automatic disconnect when the Instance is destroyed.
- **Auto-destroy players/characters**: enable `Workspace.PlayerCharacterDestroyBehavior`, or destroy manually:
  ```luau
  Players.PlayerAdded:Connect(function(player)
      player.CharacterRemoving:Connect(function(character)
          task.defer(character.Destroy, character)
      end)
  end)
  Players.PlayerRemoving:Connect(function(player)
      task.defer(player.Destroy, player)
  end)
  ```
- **Always nil out per-player table entries on leave.**
- **Avoid capturing large tables in long-lived closures**; capture references you actually need.

---

## Physics

Common problems:

- **Excessive simulated parts.** Anything unanchored ticks the physics engine.
- **Fixed-rate physics stepping** at 240 Hz (vs adaptive). Quadruples per-frame physics cost.
- **`CollisionFidelity = Precise`** on every mesh part. Massive CPU and memory overhead.

Mitigations:

- **`Anchored = true`** on anything that doesn't need physics.
- **Adaptive timestepping** (`Workspace` setting) instead of fixed.
- **Reduce constraint and joint count**; reduce ragdoll self-collision.
- **Pick the right `CollisionFidelity`**:
  - Small/non-interactable → `Box`.
  - Small-medium → `Box` or `Hull`.
  - Large complex → custom collision built from invisible Boxes.
  - Non-collidable → `CanCollide=false; CanTouch=false; CanQuery=false` and still pick `Box` (collision geometry is stored in memory regardless).

---

## Humanoids & avatars

Common problems:

- **All `HumanoidStateType`s enabled** on every NPC. Each enabled state has a cost.
- **Frequent re-instantiation of rigs with `Humanoid` + `MeshPart`s** — particularly with **layered clothing**. `updateInvalidatedFastClusters` MicroProfiler tag is the symptom.
- **Server-side animation playback for many NPCs** — replicates every animation update.
- **Static NPCs with `Humanoid`s** that never move.

Mitigations:

- **`Humanoid:SetStateEnabled(state, false)`** for unused states.
- **`AnimationController`** instead of `Humanoid` for static NPCs or NPCs with custom movement.
- **Play NPC animations on the client** — create the `Animator` client-side; saves server simulation + replication. Bonus: only run animations for nearby NPCs.
- **Pool rigs** instead of instantiating per spawn.
- **Avoid runtime size/scale changes** on rigs — they invalidate FastCluster.

---

## Rendering

Common problems:

- **High draw call count** — too many distinct meshes/materials.
- **High-resolution textures**. A 1024×1024 texture costs **4×** the GPU memory of a 512×512.
- **Asset duplication** — same mesh uploaded multiple times under different IDs.
- **Excessive `BillboardGui`s, `ParticleEmitter`s, lights**.

Mitigations:

- **Reuse asset IDs**. Audit for duplicates; consolidate.
- **Cap texture resolution** to actual screen footprint. Most images need ≤ 512×512; minor images ≤ 256×256.
- **Trim sheets / sprite sheets** to reduce draw calls.
- **`SurfaceAppearance.Color`** to tint a single texture rather than uploading colored variants.
- **LODs** (Levels of Detail) for distant geometry — Roblox handles some automatically; mesh import options expose more control.

---

## Networking & replication

Common problems:

- **Excessive RemoteEvent traffic** — high-frequency fires, large payloads, full-state pushes instead of deltas.
- **Server-side `TweenService`** — every property update of the tweened part replicates to every client every frame. Almost always wrong.
- **Large instance trees created/destroyed at runtime** — replicates the entire descendant set.
- **Animation Editor metadata** in published rigs — large hidden data structures replicating with every clone.

Mitigations:

- **Replicate deltas, not state**. Send the change, not the whole inventory.
- **Throttle client→server inputs** — `task.wait` between sends, or accumulate locally and send on a fixed cadence.
- **Tween on the client.** Server sets the target; client interpolates.
- **Use `buffer` for high-frequency remote payloads** — packed bytes are smaller than equivalent Luau tables.
- **Strip animation metadata** before publishing rigs.
- **Chunk large map loads** across frames with `task.wait` between chunks.
- **Skip replicating ephemeral visuals** — explosions, magic blasts, first-person view models. Server tells clients "thing happened at X"; each client makes its own VFX.

---

## Asset memory

Common problems:

- **Streaming disabled.** Especially on large worlds. Direct ticket to client crashes on lower-end devices.
- **Overuse of `Persistent` `ModelStreamingMode`** — every persistent thing loads on every client.
- **Loading every asset upfront** with `ContentProvider:PreloadAsync(...)`.
- **Audio files not chunked** — every music track loaded at once.

Mitigations:

- **Enable `Workspace.StreamingEnabled = true`**. Tune `StreamingMinRadius` and `StreamingTargetRadius` aggressively.
- **Only `Persistent` what every client must always see.** Defaults beat "I'll just make it persistent to be safe".
- **`PreloadAsync` selectively**: loading-screen images, starting-area essentials, button icons. Not the entire Workspace.
- **Provide a "Skip Loading" button** when preloading large sets — networks vary; users will leave.
- **Lazy-load audio** by region or context.

---

## Load times

- **Don't `PreloadAsync(workspace:GetDescendants())`.** Common anti-pattern; multiplies load time for marginal pop-in benefit.
- **`ContentProvider.RequestQueueSize` polling** is unreliable and prolongs load. Don't gate on it.
- **Loading screen images themselves should be tiny**. Big loading-screen art with massive resolution makes the loading screen the slowest thing.

---

## Useful MicroProfiler scopes

Mark up your own:

```luau
debug.profilebegin("InventoryUpdate")
updateInventory(player)
debug.profileend()
```

Built-in scopes worth knowing:

| Scope | What it measures |
|---|---|
| `RunService.PreRender` | Code on PreRender |
| `RunService.PreSimulation` / `PostSimulation` / `Heartbeat` | Code on each frame phase |
| `physicsStepped` / `worldStep` | Physics computation |
| `ProcessPackets` | Incoming network packets |
| `Allocate Bandwidth` / `Run Senders` | Outgoing replication |
| `updateInvalidatedFastClusters` | Avatar/skinned-mesh churn |

If a scope is consistently > 1 ms on the client or > 4 ms on the server, it's a candidate.

---

## Memory monitoring

Developer Console fields to watch:

- **`LuaHeap`** — your scripts' Luau heap. Growing monotonically = leak.
- **`InstanceCount`** — total Instances. Growing without explanation = orphan Instances retained by references.
- **`PlaceScriptMemory`** — per-script breakdown. Find the offender.
- **`PhysicsParts`** — collision-fidelity memory. Reduce fidelity if high.
