# `pesde.toml` Reference

Source: [pesde-pkg/pesde docs](https://github.com/pesde-pkg/pesde/tree/main/docs/src/content/docs/reference).

Pesde targets multiple Luau runtimes from one tool and bridges to Wally. Manifest format is its own — not Wally-compatible by file shape.

## Top-level fields

```toml
name = "scope/name"            # lowercase letters, numbers, underscores
version = "0.1.0"              # SemVer
description = "..."            # optional
license = "MIT"                # SPDX
authors = ["..."]
repository = "https://..."
private = false
includes = ["src/**", "README.md"]
```

## `[target]`

The single most important section — declares what runtime this package builds for.

```toml
[target]
environment = "roblox"   # one of: luau, lune, roblox, roblox_server
lib = "src/init.luau"    # entry point for `require`
bin = "main.luau"        # entry point for binary execution (luau / lune only)
```

| Environment | Meaning |
|---|---|
| `luau` | Plain Luau, runnable via the standalone `luau` CLI. |
| `lune` | Requires the [Lune](https://lune-org.github.io/docs) runtime. |
| `roblox` | Must run inside Roblox. |
| `roblox_server` | Same as `roblox` but server-only. |

`bin` is allowed only for `luau` and `lune` targets — Roblox doesn't run packages as binaries.

`lib` is allowed for any target. Required if other packages will `require` this one.

### `[target.scripts]`

Scripts that ship with the package and get linked into the consumer's `.pesde` directory:

```toml
[target.scripts]
roblox_sync_config_generator = "scripts/roblox_sync_config_generator.luau"
```

The `roblox_sync_config_generator` name is special — pesde calls it to generate Rojo-compatible sync configs for Wally bridge packages.

## `[scripts]`

Project-level scripts runnable via `pesde run`. Executed under [Lune](https://lune-org.github.io/docs).

```toml
[scripts]
build = "scripts/build.luau"
test = "scripts/test.luau"
```

Special scripts pesde looks for:

- `sourcemap_generator` — generates source maps for installed packages. Required for proper Luau LSP type support on Wally bridge dependencies.

## `[indices]`

Pesde-native registries:

```toml
[indices]
default = "https://github.com/pesde-pkg/index"
acme = "https://github.com/acme/pesde-index"
```

`default` is used when a dep doesn't specify `index`.

## `[wally_indices]`

Wally registries this project pulls from:

```toml
[wally_indices]
default = "https://github.com/UpliftGames/wally-index"
```

Reference these by name from `[dependencies]` to pull Wally packages.

## `[overrides]` and `[patches]`

Override a transitive dep's version (`[overrides]`) or apply a local diff to a specific version (`[patches]`):

```toml
[overrides]
"some/dep" = "^2.0.0"

[patches.acme/foo]
"1.0.0 luau" = "patches/acme-foo-1.0.0-luau.patch"
```

Patches let you fix a bug in a dep without forking. Pesde applies the diff after install.

## `[dependencies]`

Three flavors.

### Pesde-native

```toml
[dependencies]
hello = { name = "pesde/hello", version = "^1.0.0" }
foo = { name = "acme/foo", version = "1.2.3", index = "acme", target = "lune" }
```

| Field | Purpose |
|---|---|
| `name` | `scope/name` of the package. |
| `version` | SemVer requirement. |
| `index` | Which `[indices]` entry to use. Defaults to `default`. |
| `target` | Which target (`environment`) of the package to use. Defaults to the consuming package's target. |

### Wally bridge

```toml
[dependencies]
React = { wally = "jsdotlua/react", version = "^17.1.0" }
Promise = { wally = "evaera/roblox-lua-promise", version = "^4.0.0", index = "default" }
```

The `wally` field replaces `name`, and `index` (if provided) refers to a `[wally_indices]` entry.

### Git

```toml
[dependencies]
cool = { git = "https://github.com/owner/repo.git", rev = "main" }
```

### Workspace

For monorepo workspaces:

```toml
workspace_members = ["packages/*"]

[dependencies]
sibling = { workspace = "scope/sibling", version = "^1.0.0" }
```

### Path

For local development:

```toml
[dependencies]
local = { path = "../my-other-package" }
```

## `[dev_dependencies]` / `[peer_dependencies]`

Same syntax as `[dependencies]`. Dev deps install only for development; peer deps must be provided by the consumer.

## `[engines]`

Pin the pesde / runtime versions a project requires:

```toml
[engines]
pesde = "^0.7.0"
lune = "^0.8.0"
```

## `[place]`

For Roblox projects: declare which DataModel paths Wally bridge deps map to (so the sourcemap generator can produce a valid Rojo config).

## Lockfile

`pesde.lock` — commit it. Same role as `wally.lock`.

## Commands

| Command | Purpose |
|---|---|
| `pesde init` | Interactive manifest scaffold. |
| `pesde add <scope/name>` | Add + install a dep. |
| `pesde install` | Install all deps; write `pesde.lock`. |
| `pesde update [pkg...]` | Bump deps. |
| `pesde run [name]` | Run an entry from `[scripts]` (or `[target.bin]`). Uses Lune. |
| `pesde publish` | Publish to a configured pesde index. |

## Layout

After `pesde install` for a `roblox` target:

```
project/
├── pesde.toml
├── pesde.lock
├── roblox_packages/        # native deps for this target
│   └── ...
└── ...
```

Wally bridge deps install separately, with the sourcemap generator producing a Rojo-compatible mount. Pair with `rojo sourcemap`.

## Common pitfalls

- Forgetting `[target] environment` — pesde won't know which runtime to install for.
- Using `bin` on a `roblox` target — not allowed.
- Mixing pesde and Wally for the same logical project without a strategy — pick one as canonical, bridge the other.
- Forgetting to commit `pesde.lock`.
- Using `target` on a wally bridge dep — only valid for native pesde deps.
