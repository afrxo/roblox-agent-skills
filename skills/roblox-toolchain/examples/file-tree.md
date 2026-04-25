# Example Repo Layout

Full file tree showing how filesystem maps to DataModel for a typical Roblox place project.

```
my-game/
├── rokit.toml                  # toolchain pinning
├── default.project.json        # Rojo project — defines the DataModel mounts
├── wally.toml                  # package manifest
├── wally.lock                  # lockfile (committed)
├── stylua.toml                 # formatter config
├── selene.toml                 # linter config
├── .luaurc                     # luau type-checker config
├── .gitignore
├── README.md
│
├── sourcemap.json              # generated; .gitignore'd
├── Packages/                   # wally output; .gitignore'd
├── ServerPackages/             # wally output; .gitignore'd
├── DevPackages/                # wally output; .gitignore'd
│
├── .github/workflows/
│   └── ci.yml
│
└── src/
    │
    ├── ReplicatedStorage/                        → game.ReplicatedStorage
    │   ├── Shared/                               → ReplicatedStorage.Shared (Folder)
    │   │   ├── init.luau                          → makes Shared a ModuleScript
    │   │   ├── Inventory/                        → Shared.Inventory (ModuleScript via init.luau)
    │   │   │   ├── init.luau
    │   │   │   ├── add.luau                       → Inventory.add (ModuleScript)
    │   │   │   └── remove.luau                    → Inventory.remove (ModuleScript)
    │   │   ├── Logger.luau                        → Shared.Logger (ModuleScript)
    │   │   └── types.luau                         → Shared.types (ModuleScript)
    │   │
    │   └── Remotes/                              → ReplicatedStorage.Remotes (Folder)
    │       └── Combat.model.json                 → JSON model: a Folder of RemoteEvents
    │
    ├── ServerScriptService/                      → game.ServerScriptService
    │   ├── init.server.luau                       → makes ServerScriptService a Script (server)
    │   ├── Systems/                              → ServerScriptService.Systems (Folder)
    │   │   ├── CombatSystem.server.luau           → Server Script
    │   │   ├── InventorySystem.server.luau        → Server Script
    │   │   └── PlayerData.luau                    → ModuleScript (server-only by location)
    │   └── Boot.server.luau                       → Server Script (entry point)
    │
    ├── StarterPlayerScripts/                     → game.StarterPlayer.StarterPlayerScripts
    │   ├── init.client.luau                       → makes StarterPlayerScripts a LocalScript
    │   ├── Camera.client.luau                     → LocalScript
    │   └── UI/                                   → StarterPlayerScripts.UI (Folder)
    │       ├── App.client.luau                    → LocalScript
    │       └── components.luau                    → ModuleScript
    │
    ├── StarterCharacterScripts/                  → game.StarterPlayer.StarterCharacterScripts
    │   └── CharacterMovement.client.luau          → LocalScript
    │
    ├── StarterGui/                               → game.StarterGui
    │   └── HUD.rbxm                              → Binary model (built in Studio)
    │
    └── ReplicatedFirst/                          → game.ReplicatedFirst
        └── LoadingScreen.client.luau              → LocalScript (runs first on client)
```

## Why this layout

- **Top-level `src/` directory names match DataModel mount points.** Reading the path tells you exactly where the script ends up.
- **`init.luau` collapses a folder into a single script** with submodules — used here for `Shared/` and `Inventory/`.
- **`init.server.luau` / `init.client.luau`** turn entry-point folders into the right script type. `ServerScriptService/init.server.luau` becomes the boot script.
- **Wally output is mounted via `default.project.json`** — `Packages/` under `ReplicatedStorage`, `ServerPackages/` under `ServerScriptService`. The folders themselves stay `.gitignore`'d.
- **`.rbxm` files** are committed for binary content (UI built in Studio, terrain). `.rbxmx` (XML) is preferred for diff-friendly content; `.rbxm` for everything else.

## What's `.gitignore`'d

```gitignore
# Wally output
Packages/
ServerPackages/
DevPackages/

# Rojo
sourcemap.json

# Builds
build/
*.rbxl
*.rbxlx

# Tooling
.lune/
.pesde/

# Editor / OS
.DS_Store
*.log
.vscode/             # if you don't share editor settings
```

Commit `*.rbxm` / `*.rbxmx` (intentional content), `.luaurc`, `wally.lock`, `pesde.lock`, `rokit.toml`, all configs.
