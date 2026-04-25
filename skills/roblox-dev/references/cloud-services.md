# Cloud Services Picker

Sources: [data-stores-vs-memory-stores](https://create.roblox.com/docs/cloud-services/data-stores-vs-memory-stores).

| Service | Persistence | Scope | In-game access | Closest analogy |
|---|---|---|---|---|
| Standard data stores | Permanent | Cross-server | Read/write | NoSQL DB |
| Ordered data stores | Permanent | Cross-server | Read/write | Sorted DB index |
| Memory stores | ≤ 45 days | Cross-server | Read/write | In-memory cache (Redis-ish) |
| Configs | Permanent | Cross-server | Read-only | Feature flags |
| Secrets stores | Permanent | Cross-server | Read-only | Secrets manager |
| In-memory Luau | Session | Single server | Read/write | Server RAM |

**Cloud services are server-only.** Clients can't call any of them.

---

## Standard data stores — when

- Long-term player data: progression, inventory, settings.
- Cross-server: the same key reads the same value on every server.
- Automatic version backup: 30 days of past versions retained.
- Values can be numbers, strings, booleans, tables.

Don't use for: hot in-server state (use in-memory Luau), high-frequency cross-server signals (use memory stores).

## Ordered data stores — when

- Sortable numeric data only — typically all-time leaderboards.
- `:GetSortedAsync(...)` returns top-N.
- No automatic version backup.

Don't use for: anything non-numeric. Don't use a separate ordered store for transient leaderboards (use memory store).

## Memory stores — when

- Cross-server low-latency state with TTL ≤ 45 days.
- Matchmaking queues, party invites, daily/monthly leaderboards.
- Higher write throughput than data stores.
- Primitives: hash maps, sorted maps, queues.

Don't use for: anything that must persist beyond 45 days. Don't use as the primary save layer.

## Configs — when

- Tunable in-game values controlled from the Creator Hub.
- Feature flags, A/B test parameters, event toggles, balance numbers.
- Read-only at runtime; updates propagate over ~5 minutes.

Don't use for: anything that needs instant updates or per-player customization. Don't use for: storing user data.

## Secrets stores — when

- Third-party API keys, tokens, passwords used by HttpService calls.
- Read-only from the game; managed via Creator Hub.

Don't use for: anything other than secrets. Storing keys in regular DataStores is a security risk.

## In-memory Luau — when

- Anything that doesn't outlive the server session: status effects, current health, timers, in-flight match state, per-player session caches.
- Free, instant, zero quota.

Don't use for: anything that must survive a server restart. Don't share across servers (it can't).

---

## Decision tree

1. **Can the data be lost when the server shuts down?** → in-memory Luau.
2. **Must it survive forever and persist per-player or per-game?** → standard data stores.
3. **Must it persist forever and sort numerically?** → ordered data stores.
4. **Cross-server, fast, ephemeral (TTL ≤ 45 days)?** → memory stores.
5. **Tunable game-wide setting / feature flag?** → configs.
6. **API key for an external service?** → secrets store.

---

## Common combinations

- **Player save** = standard data store (canonical) + in-memory Luau cache (session) + memory store (cross-server presence/lock if needed).
- **Matchmaking** = memory store sorted map (queue by skill) + standard data store (player MMR).
- **Leaderboard** = ordered data store (all-time) or memory store sorted map (daily/weekly).
- **Live event** = config flag (toggle) + standard data store (per-player progress in event).

---

## Common mistakes

- Storing API keys in data stores → use secrets stores.
- Saving long-term progress to memory stores → expires.
- Using standard data stores for high-frequency cross-server signals → throttling. Use memory stores or messaging service.
- Using ordered data stores for transient leaderboards → no TTL, fills up. Use memory store sorted map.
- Hitting data stores on every player change → session-cache and write on `PlayerRemoving` + `BindToClose`.

For data-store-specific rules (rate limits, retry/backoff, session-locking) see [`datastore-rules.md`](datastore-rules.md).
