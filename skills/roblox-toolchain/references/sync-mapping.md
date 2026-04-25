# Filesystem → DataModel Sync Reference

Source: [rojo.space/docs/sync-details](https://github.com/rojo-rbx/rojo.space/blob/master/docs/sync-details.md).

## Full mapping

| File / Directory | Becomes |
|---|---|
| Any directory | `Folder` |
| `*.luau` | `ModuleScript` (also accepts legacy `.lua`) |
| `*.server.luau` | `Script` (server) (also accepts `.server.lua`) |
| `*.client.luau` | `LocalScript` (client) (also accepts `.client.lua`) |
| `dir/init.luau` | The directory becomes a `ModuleScript`; siblings become its children |
| `dir/init.server.luau` | The directory becomes a `Script` |
| `dir/init.client.luau` | The directory becomes a `LocalScript` |
| `*.rbxm` | Binary model |
| `*.rbxmx` | XML model |
| `*.csv` | `LocalizationTable` |
| `*.txt` | `StringValue` |
| `*.json` (not `.model.json` / `.project.json`) | `ModuleScript` returning the JSON as a Lua table |
| `*.toml` | `ModuleScript` returning the TOML as a Lua table |
| `*.model.json` | Hand-written JSON model description |
| `*.project.json` | Nested Rojo project (composes into parent) |
| `*.meta.json` | Metadata sidecar attached to the matching file/dir |

A directory containing `default.project.json` is fully described by that file — its other contents are ignored unless the project file references them.

## Limitations (real-time sync only)

Some property types **can't** be live-synced and need a one-shot `rojo build` to land in Studio:

- Binary data: `Terrain`, CSG parts.
- `MeshPart.MeshId`.
- `HttpService.HttpEnabled` (and similar restricted properties).

For the canonical list of property types Rojo can reason about, see [rbx-dom's type coverage chart](https://github.com/Roblox/rbx-dom#property-type-coverage).

## Scripts — naming details

```
src/
├── Foo.luau            → ModuleScript "Foo"
├── Bar.luau           → ModuleScript "Bar"
├── Baz.server.luau     → Script (server) "Baz"
└── Qux.client.luau     → LocalScript "Qux"
```

Inside a directory:

```
src/Inventory/
├── init.luau           → makes "Inventory" a ModuleScript
├── add.luau            →   ModuleScript "add" (child of Inventory)
└── remove.luau         →   ModuleScript "remove" (child of Inventory)
```

Or to make the directory a server `Script`:

```
src/Setup/
├── init.server.luau    → makes "Setup" a Script (server)
└── helper.luau         →   ModuleScript "helper" (child of Setup)
```

**Only one `init.*` per directory** (`init.luau` xor `init.server.luau` xor `init.client.luau`). Multiple is an error.

## JSON modules

```json
// config.json
{
  "Hello": "world!",
  "bool": true,
  "array": [1, 2, 3],
  "object": {
    "key 1": 1337,
    "key 2": []
  }
}
```

Becomes a `ModuleScript` whose source is:

```luau
return {
    Hello = "world!",
    array = { 1, 2, 3 },
    bool = true,
    object = {
        ["key 1"] = 1337,
        ["key 2"] = {},
    },
}
```

Convenient for config-style data without writing a Luau wrapper.

## TOML modules

Same idea as JSON. `*.toml` files become `ModuleScript`s that return the parsed TOML as a Lua table.

**Caveat:** TOML `DateTime` values get converted to `string`. The two formats don't have a clean datatype mapping.

## JSON models (`*.model.json`)

Hand-written, useful for `RemoteEvent`, `BindableEvent`, `Configuration`, etc. that don't naturally fit as a Lua file:

```json
{
  "ClassName": "Folder",
  "Children": [
    {
      "Name": "RootPart",
      "ClassName": "Part",
      "Properties": {
        "Size": [4, 4, 4]
      }
    },
    {
      "Name": "SendMoney",
      "ClassName": "RemoteEvent"
    }
  ]
}
```

Becomes a Folder with a Part and a RemoteEvent inside.

## Meta files (`*.meta.json`)

Sidecar files attaching extra Rojo data to whatever sits next to them.

| Field | Allowed in | Effect |
|---|---|---|
| `className` | only `init.meta.json` | Changes the parent directory's class from `Folder` to something else. |
| `properties` | any non-model file (not `.rbxm`/`.rbxmx`/`.model.json`, which already have properties) | Sets properties on the Instance. |
| `ignoreUnknownInstances` | any file | Same as `$ignoreUnknownInstances` in `.project.json`. |

### Use cases

**Disable a script:**

```json
// foo.meta.json (next to foo.server.luau)
{
  "properties": { "Disabled": true }
}
```

**Make a folder a Tool:**

```
src/Sword/
├── init.meta.json
├── init.server.luau
└── Handle.rbxm
```

```json
// init.meta.json
{
  "className": "Tool",
  "properties": {
    "Grip": [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]
  }
}
```

The directory becomes a `Tool` (instead of a `Folder`-with-`Script`-inside), with `Handle` as a child.

**Leave Studio-side Instances alone:**

```json
// hello.meta.json
{
  "ignoreUnknownInstances": true
}
```

Rojo won't delete Instances under `hello.txt`'s `StringValue` even if they aren't in the filesystem.

## Common pitfalls

- **Two `init.*` files** in one directory → error.
- **`*.luau` in a `StarterPlayerScripts` mount** → `ModuleScript`, not `LocalScript`. It won't run as client code.
- **`*.json` files where you wanted JSON-as-config** but Rojo treats them as model JSON because they're named `*.model.json` — drop the `.model` segment.
- **Editing a `*.rbxm` model directly on disk** — they're binary; round-trip through Studio.
- **Forgetting that `init.luau` makes its directory a script** — adding an unrelated `init.luau` to a folder will silently change the folder's class.
