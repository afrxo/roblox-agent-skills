# `.project.json` Format Reference

Source: [rojo.space/docs/project-format](https://github.com/rojo-rbx/rojo.space/blob/master/docs/project-format.md).

## Top-level fields

| Field | Type | Required | Default | Purpose |
|---|---|---|---|---|
| `name` | string | yes | — | Build artifact name (used for `.rbxl` / `.rbxm` filenames). |
| `tree` | Instance Description | yes | — | Root Instance description. |
| `servePort` | number | no | `34872` | Port `rojo serve` listens on (`--port` overrides). |
| `servePlaceIds` | `[number]` | no | `null` | Allowlist of place IDs that may live-sync — guards against syncing into the wrong game. |
| `placeId` | number | no | `null` | Sets the current place's place ID when connecting from Studio. |
| `gameId` | number | no | `null` | Sets the current place's game ID when connecting from Studio. |
| `serveAddress` | string | no | `null` | Address override for `rojo serve` (`--address` takes precedence). |
| `globIgnorePaths` | `[string]` | no | `[]` | Globs of paths to ignore (e.g. `**/*.spec.luau`). |
| `emitLegacyScripts` | boolean | no | `true` | Whether `*.server.luau`/`*.client.luau` produce legacy `Script`/`LocalScript` or modern `Script` with `RunContext`. Verify default per Rojo version. |

## Instance Description

Every entry in `tree` (and every nested child) is an Instance Description.

| Key | Required | Purpose |
|---|---|---|
| `$className` | optional if `$path` resolves it OR the parent key is a service name | The Roblox `ClassName`. |
| `$path` | optional if `$className` is set | Filesystem path (relative to project file) to mount. |
| `$properties` | optional | Properties to apply to the Instance. Values are [Instance Property Values](#instance-property-value). |
| `$ignoreUnknownInstances` | optional | If `true`, Rojo doesn't delete Instances it didn't sync. Default: `false` if `$path` is set, otherwise `true`. |
| Any other key | optional | Becomes a child Instance description with that key as its name. |

## Instance Property Value

Two forms.

### Implicit

Rojo uses its own knowledge of the Roblox API to infer the type from the property name + class:

```json
{
  "$className": "Part",
  "$properties": {
    "Anchored": true,
    "Size": [4, 4, 4]
  }
}
```

Rojo validates the value against the expected type. If the property doesn't exist on the class, it errors.

### Explicit

A single-field object where the key is the [property type](https://github.com/rojo-rbx/rojo.space/blob/master/docs/properties.md) and the value is the property value:

```json
{
  "$properties": {
    "Anchored": { "Bool": true },
    "Color": { "Color3": [1, 0, 0] }
  }
}
```

Explicit values **bypass type validation** — useful for properties Rojo doesn't know about (recently added APIs, internal-only properties). The trade-off: typos pass through to Studio rather than failing at build.

## Examples

### Minimal — model project

```json
{
  "name": "AwesomeLibrary",
  "tree": {
    "$path": "src"
  }
}
```

### Place project

```json
{
  "name": "Sisyphus Simulator",
  "globIgnorePaths": ["**/*.spec.luau"],
  "tree": {
    "$className": "DataModel",

    "HttpService": {
      "$className": "HttpService",
      "$properties": {
        "HttpEnabled": true
      }
    },

    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "$path": "src/ReplicatedStorage"
    },

    "StarterPlayer": {
      "$className": "StarterPlayer",
      "StarterPlayerScripts": {
        "$className": "StarterPlayerScripts",
        "$path": "src/StarterPlayerScripts"
      }
    },

    "Workspace": {
      "$className": "Workspace",
      "$properties": {
        "Gravity": 67.3
      },
      "Terrain": {
        "$path": "Terrain.rbxm"
      }
    }
  }
}
```

### Nested projects

A `default.project.json` inside a sub-tree composes:

```json
{
  "tree": {
    "$path": "src",
    "Modules": {
      "$path": "vendor/cool-lib"
    }
  }
}
```

If `vendor/cool-lib/default.project.json` exists, Rojo uses it as the description for `Modules` instead of the directory's raw contents.

## Common pitfalls

- **Nested projects must describe models, not places** — they can't have `$className: "DataModel"` at the root.
- **Invalid property names** with implicit values are caught at build; explicit values aren't validated.
- **Service Instances** (top-level children of `DataModel`) — Rojo can infer `$className` from the key for known services, but being explicit avoids ambiguity when service names change.
