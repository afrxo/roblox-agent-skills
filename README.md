# roblox-agent-skills

A set of Anthropic Agent Skills for Roblox development. Built because Claude knows Lua but doesn't reliably know Roblox — these skills carry the engine quirks, Luau idioms, Rojo workflow, and UI patterns I keep wanting on hand.

Each skill is self-contained: a slim `SKILL.md` plus deeper `references/` and runnable `examples/`. They're meant to integrate into existing projects without rewriting them — there's a shared [Integration Policy](shared/integration-policy.md) every skill links to.

## Skills

- **[luau-expert](skills/luau-expert/SKILL.md)** — modern, strictly-typed Luau. Idioms, type system, asserts, modules, anti-patterns.
- **[roblox-dev](skills/roblox-dev/SKILL.md)** — runtime behavior. DataModel, replication, RemoteEvents, character lifecycle, streaming, DataStore, parallel Luau, performance.
- **[roblox-toolchain](skills/roblox-toolchain/SKILL.md)** — filesystem workflow. Rojo project format, sync rules, Wally + Pesde, Rokit, Luau LSP, CI.
- **[roblox-ui](skills/roblox-ui/SKILL.md)** — UI engine primitives, Fusion 0.3, design guidelines.

## Install

```bash
/plugin marketplace add afrxo/roblox-agent-skills
/plugin install roblox-agent-skills@roblox-agent-skills
```

One bundled plugin containing all four skills. Or clone the repo and point your agent at it locally.

## Versioning

The plugin is versioned in `.claude-plugin/plugin.json`. Breaking changes bump the minor version (no 1.0 yet — expected to evolve).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). New skills must include the `## Integration Policy` section linking to `shared/integration-policy.md`.
