# StreamingEnabled Reference

`Workspace.StreamingEnabled = true` is the modern default. The world streams to each client based on radius and chunks; clients only see and have to download what's near them.

Source: [create.roblox.com/docs/workspace/streaming](https://create.roblox.com/docs).

---

## Workspace properties

| Property | Effect |
|---|---|
| `StreamingEnabled` | Master switch. |
| `StreamingMinRadius` | Minimum loaded radius around each player. Larger = more memory + bandwidth. |
| `StreamingTargetRadius` | Target loaded radius; the engine streams up to this when bandwidth allows. |
| `StreamingIntegrity` (newer) | Tunes how aggressively the engine guarantees content is loaded vs prioritizes bandwidth. |
| `StreamingPauseMode` | What the client does when content is streaming in (`Default`, `ClientPhysicsPause`, `Disabled`). |

Verify exact names + defaults at [docs](https://create.roblox.com/docs) — these have shifted across releases.

---

## `Model.ModelStreamingMode`

Per-Model control over streaming behavior:

| Value | Meaning |
|---|---|
| `Default` | Model streams normally; descendants stream independently. |
| `Atomic` | Model streams in/out as a single unit. Descendants are always present together or absent together. Use for assemblies (vehicles, NPC rigs) where partial loads are broken. |
| `Persistent` | Model is always loaded for every client, regardless of radius. Costs memory on every client; use sparingly. |
| `PersistentPerPlayer` | Always loaded for players added via the per-player API; behaves like `Default` for others. |

Don't set `Persistent` on large geometry. Reserve for things every client must always see (e.g. UI props, anchors for global systems).

---

## Client-side rules

- **`WaitForChild` with timeout** for any descendant that may not be loaded yet. Without timeout, you risk hanging forever if the part never arrives in your radius.
- **Listen to `workspace.PersistentLoaded`** if your client logic depends on persistent content being present.
- Use `Player:RequestStreamAroundAsync(position)` to nudge a region into streaming for the local player (e.g. before teleporting).

---

## Server-side rules

- The server always sees every Instance — `:FindFirstChild` is sufficient.
- Don't drive `CFrame` updates on parts you know are streamed-out for a player; it's bandwidth without visible effect. There's no API to query "is this part streamed in for player X" at high frequency, but designing systems so updates only fire while a player is in range mitigates this.

---

## Common mistakes

- Assuming a part exists on the client because it exists on the server.
- Making a player's `HumanoidRootPart` non-`Persistent` and getting odd behavior when they fall out of their own streaming radius (rare but possible).
- Setting `Persistent` on a large environment and wondering why memory blew up on low-end devices.
- Using `Atomic` on a Model that legitimately should stream piece-by-piece (e.g. a large detailed environment with independent props).
- Calling `WaitForChild` without a timeout in production code.
