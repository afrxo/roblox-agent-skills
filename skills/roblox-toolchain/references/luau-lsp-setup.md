# Luau LSP Setup Reference

Source: [github.com/JohnnyMorganz/luau-lsp](https://github.com/JohnnyMorganz/luau-lsp).

`luau-lsp` is the Language Server Protocol implementation for Luau. It powers in-editor type checking, hover info, autocomplete, and `require` resolution. Editor-agnostic — the same binary runs behind VS Code, Neovim, Helix, Sublime, etc.

## What it needs

To do its job, `luau-lsp` needs three inputs:

1. **A Roblox API definitions file** — describes the Roblox class hierarchy + properties. Auto-fetched on first run by the VS Code extension; can be passed manually via `--definitions=<file>`.
2. **A sourcemap** — produced by Rojo. Tells the LSP "this file on disk lives at `game.ReplicatedStorage.X` in the DataModel" so `require(game.ReplicatedStorage.X)` resolves to the right file.
3. **A `.luaurc` (optional)** — project-level type checker settings.

Without (1) and (2), every Roblox API call is "unknown" and every cross-file `require` fails to resolve.

## Sourcemap generation

```bash
# Watch mode — keep this running during development
rojo sourcemap --watch --output sourcemap.json default.project.json

# One-shot — for CI
rojo sourcemap --output sourcemap.json default.project.json
```

Regenerate after:

- Files added/removed under any mounted folder.
- `wally install` / `pesde install` (new package paths).
- Edits to `default.project.json` mounts.

`sourcemap.json` is generated. **`.gitignore` it.**

## Editor configuration

### VS Code (`luau-lsp` extension)

```json
// .vscode/settings.json (workspace-level)
{
  "luau-lsp.sourcemap.sourcemapFile": "sourcemap.json",
  "luau-lsp.sourcemap.autogenerate": true,
  "luau-lsp.fflags.enableNewSolver": true,
  "luau-lsp.types.roblox": true,
  "luau-lsp.types.robloxSecurityLevel": "PluginSecurity"
}
```

`autogenerate: true` tells the extension to run `rojo sourcemap --watch` for you. Convenient if you don't want a separate terminal.

### Neovim

Configure your LSP client (`nvim-lspconfig`, `lspconfig`) with:

```luau
require("lspconfig").luau_lsp.setup({
    cmd = {
        "luau-lsp",
        "lsp",
        "--definitions=path/to/globalTypes.d.luau",
        "--docs=path/to/api-docs.json",
        "--sourcemap=sourcemap.json",
    },
})
```

Verify exact flag names against `luau-lsp --help` for your installed version.

### Helix / Sublime / other

Any LSP client. Same args — pass the sourcemap path and the Roblox definitions on startup.

## CLI mode (`luau-lsp analyze`)

For CI type-checking without an editor:

```bash
luau-lsp analyze \
    --definitions=globalTypes.d.luau \
    --docs=api-docs.json \
    --sourcemap=sourcemap.json \
    --base-luaurc=.luaurc \
    src/
```

Flag names vary across versions. Always check `luau-lsp --help` on the version pinned in your `rokit.toml`.

## `.luaurc`

Project-level settings the type checker reads at startup:

```json
{
  "languageMode": "strict",
  "lint": {
    "*": true
  },
  "lintErrors": true,
  "globals": []
}
```

| Field | Purpose |
|---|---|
| `languageMode` | `strict`, `nonstrict`, or `nocheck`. Per-file `--!` comments override. |
| `lint` | Per-rule on/off (`*` = all on). |
| `lintErrors` | Whether lint warnings become errors. |
| `globals` | Extra global identifiers the linter shouldn't flag. |

Schema evolves — check [luau.org/lint](https://luau.org/lint) and the luau-lsp release notes before relying on less-common fields.

## Common pitfalls

- **No sourcemap** — every `require(game.X.Y)` is `unknown`. Symptom: the LSP "works" for in-file type checking but autocomplete is dead across files.
- **Stale sourcemap** — sourcemap doesn't auto-update without `--watch` (or the VS Code extension's `autogenerate`). Symptom: you added a file, but the LSP can't see it.
- **Wrong definitions version** — Roblox adds APIs every release; old definitions miss them. Symptom: a property exists in real Roblox but the LSP says it doesn't.
- **Wally packages not in sourcemap** — must run `rojo sourcemap` *after* `wally install` so package paths exist.
- **Per-file `--!nocheck`** silently masks issues. Use sparingly; never on new code.
