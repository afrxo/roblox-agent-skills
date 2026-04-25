# DataStore Rules Reference

Roblox persistence is rate-limited, eventually-consistent, and unforgiving of careless code. The rules below are the load-bearing ones; for full quotas and current numbers verify against [create.roblox.com/docs/cloud-services/data-stores](https://create.roblox.com/docs/cloud-services/data-stores).

---

## API surface

- **Standard data stores** (`DataStoreService:GetDataStore("name")`) — durable per-key reads/writes.
- **Ordered data stores** (`DataStoreService:GetOrderedDataStore("name")`) — sortable keys; values must be integers; supports `:GetSortedAsync(...)` for leaderboards.
- **`MemoryStoreService`** — fast, ephemeral cross-server data (queues, sorted sets). Cleared on shutdown.

This file covers standard data stores.

---

## Rate limits (verify against current docs before quoting numbers)

Limits are per-game and per-key. There are separate budgets per operation type:

- `GetAsync`
- `SetAsync` / `IncrementAsync`
- `UpdateAsync`
- `RemoveAsync`
- `GetSortedAsync` (ordered stores)

Each budget refills over time. Bursting past the budget queues your request; quota exhaustion drops it. Check `DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.X)` if you need to gate behavior.

**There's also a hard rule: no more than once every ~6 seconds per key.** Faster writes to the same key get throttled.

---

## Always wrap in `pcall`

Every DataStore call can fail (network blip, throttling, quota). Never call without a `pcall`:

```luau
local ok, result = pcall(function()
    return store:GetAsync(key)
end)

if not ok then
    warn(`DataStore read failed for {key}: {result}`)
    return nil
end
```

Don't suppress the error silently in production — log it.

---

## Use `UpdateAsync` for concurrent state

`SetAsync` overwrites. If another server is writing the same key, you can lose its update.

```luau
-- ❌ overwrite — loses concurrent writes
store:SetAsync(key, newValue)

-- ✅ atomic merge — sees previous value, decides
store:UpdateAsync(key, function(prev)
    return mergeOrReject(prev, newValue)
end)
```

`UpdateAsync` also gives you a chance to **reject** the write by returning `nil` from the transform — Roblox does not write and you don't burn the budget.

---

## Session locking pattern

Pattern for player data:

1. **On `PlayerAdded`** — `pcall(store:UpdateAsync(key, ...))` to claim the lock and read the data. The transform writes a `lockedBy = serverJobId` field with a timestamp.
2. **In memory for the session** — keep the data in a Lua table; mutate locally as the player plays.
3. **Periodic autosave** — `task.delay(60, save)` loop; writes the in-memory state back via `UpdateAsync`.
4. **On `PlayerRemoving`** — final save + clear the lock.
5. **`game:BindToClose`** — runs at server shutdown. **Total budget is ~30 seconds across all players**, so save in parallel via `task.spawn`/`task.wait`-coordinated dispatch.

If another server holds the lock when you try to claim it, choose: refuse the join, or wait + retry with backoff (the previous server may be shutting down).

---

## Retry with exponential backoff

```luau
local function retryAsync<T>(fn: () -> T, attempts: number?): T?
    local n = attempts or 5
    local delay = 1
    for i = 1, n do
        local ok, result = pcall(fn)
        if ok then return result end
        warn(`DataStore attempt {i} failed: {result}`)
        task.wait(delay)
        delay = math.min(delay * 2, 30)
    end
    return nil
end
```

Don't retry forever — bounded attempts, then surface the failure.

---

## Value rules

- **Strings, numbers, booleans, tables, `nil`** are valid. Tables can nest.
- **No `Instance`s, `RBXScriptConnection`s, functions, or userdata** in the value.
- **64 KB per value** (compressed). Verify the current limit before relying on it.
- **Keys are strings, ≤ 50 chars, ASCII**. Don't include the user-facing display name; use `UserId`.

For values that approach the size limit, serialize to JSON or to a `buffer` and store as a string.

---

## Common mistakes

- Reading on every change. Read once at session start; mutate in memory.
- Using `SetAsync` instead of `UpdateAsync` for concurrent state.
- Saving without `pcall`.
- Saving in a tight loop (write every X seconds, not every action).
- Storing display names instead of `UserId`.
- Large nested tables full of `Instance` references that get serialized as `nil`.
- Forgetting `BindToClose`. On a shutdown, all in-memory unsaved state is gone.
