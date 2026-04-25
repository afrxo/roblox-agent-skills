# `Instance:QueryDescendants`

```
Instance:QueryDescendants(selector: string) -> { Instance }
```

Returns an array of descendants matching the selector string. Empty array on no match (never `nil` for non-matches). Selector grammar is similar to `StyleRule` selectors, with a few differences.

- **Security:** None.
- **Thread safety:** Unsafe.
- **Tag:** CustomLuaState.

Source: [create.roblox.com/docs/reference/engine/classes/Instance#QueryDescendants](https://create.roblox.com/docs/reference/engine/classes/Instance#QueryDescendants).

---

## Selectors

| Syntax | Matches |
|---|---|
| `ClassName` | Instances where `:IsA("ClassName")` is true |
| `.Tag` | Instances tagged with the CollectionService tag `Tag` |
| `#Name` | Instances whose `Name` is `Name` |
| `[property = value]` | Instances with property `property` equal to `value` (boolean, number, or string; `_` and `-` allowed unquoted) |
| `[$attribute]` | Instances with attribute `attribute` set |
| `[$attribute = value]` | Instances with attribute `attribute` equal to `value` |

Selectors stack on the same instance:

```luau
-- Model tagged "Apple" with attribute Variety = Fuji and Flavor = 4
Workspace:QueryDescendants("Model.Apple[$Variety = Fuji][$Flavor = 4]")
```

To check for the **absence** of an attribute, use `:not([$attribute])` — querying `[$attribute = nil]` is invalid.

---

## Combinators

| Syntax | Meaning |
|---|---|
| `A > B` | `B` is a **direct child** of an `A` match |
| `A >> B` | `B` is a **descendant** of an `A` match (this is the default; `B` alone means `>> B`) |
| `A, B` | Union — instances matching `A` OR `B` |

```luau
-- Direct children of any Model that are tagged "SwordPart"
Workspace:QueryDescendants("Model > .SwordPart")

-- Direct children of `Workspace` that are Parts tagged "Apple"
Workspace:QueryDescendants("> Part.Apple")

-- Descendants of any Model that have attribute OnFire = true
Workspace:QueryDescendants("Model >> [$OnFire = true]")

-- MeshPart tagged "SwordPart" OR MeshPart with OnFire = true
Workspace:QueryDescendants("MeshPart.SwordPart, MeshPart[$OnFire = true]")
```

---

## Pseudo-class selectors

| Syntax | Meaning |
|---|---|
| `:not(complex-selector-list)` | Negation — matches instances that don't match any selector in the list |
| `:has(relative-selector-list)` | Containment — matches instances that contain something matching the inner selector(s) |

```luau
-- Not a SpotLight
Workspace:QueryDescendants(":not(SpotLight)")

-- Not SpotLight and not PointLight
Workspace:QueryDescendants(":not(SpotLight, PointLight)")

-- Without OnFire attribute
Workspace:QueryDescendants(":not([$OnFire])")

-- Everything except children of a Model tagged SwordPart
Workspace:QueryDescendants(":not(Model > .SwordPart)")

-- Anything that has a Tool descendant
Workspace:QueryDescendants(":has(Tool)")

-- MeshPart with a direct child tagged SwordPart
Workspace:QueryDescendants("MeshPart:has(> .SwordPart)")

-- MeshPart whose direct children are NOT SurfaceAppearance or Texture
Workspace:QueryDescendants("MeshPart:has(> :not(SurfaceAppearance, Texture))")
```

---

## When to use vs `GetDescendants`

- **Use `QueryDescendants`** when you want a filtered slice — class match, tag match, attribute filter, hierarchy combinator. Filtering happens engine-side; you skip the Luau-side loop.
- **Use `GetDescendants`** when you genuinely need every descendant and will iterate them all anyway.
- **Use `GetChildren`** for direct children only.
- For one named child, use `FindFirstChild`. For one match by class, `FindFirstChildOfClass` / `FindFirstChildWhichIsA` (descendants: pass `true` as second arg or use `FindFirstDescendant`).
