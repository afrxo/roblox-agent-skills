# Integration Policy

**Canonical source.** Every skill in this repo links here. If the rule changes, update this file; each SKILL.md carries a short summary that defers to this document.

---

## Don't rewrite working code

These skills describe **preferred** patterns. They do not authorize unsolicited rewrites.

- **Apply skill rules to new code** you write, and to code the user explicitly asks to refactor.
- **Existing code stays.** A file using `pairs(t)` stays on `pairs(t)` while you make unrelated edits — don't modernize untouched code as a side effect.
- **Don't weaken stricter files.** If a file is `--!strict`, keep it strict. If it's `--!nonstrict`, don't promote it without ask.
- **Don't introduce tooling.** If the project doesn't use Wally / Pesde / Rokit / a particular library, don't add it because the skill mentions it.
- **Don't add new patterns.** If the codebase already has a logger / signal library / state container, use it. Don't introduce a competing one.

---

## Match the codebase's style

Read what's there. Match it.

- **Casing**: variable / function / type names follow the repo's existing convention (`camelCase`, `PascalCase`, `snake_case`, etc.).
- **Indentation**: tabs vs spaces, width — match the file you're editing.
- **Quote style**: single vs double — match.
- **Imports**: ordering, grouping (or lack thereof) — match. If the project doesn't use `sort_requires`, don't reorder imports.
- **Comments**: terseness, language, formality — match.
- **Module shape**: if every existing module returns `module.X` style, follow it. If they return single functions, follow that. Don't refactor for symmetry with the skill's example.

If the codebase has a `STYLE.md` / `.editorconfig` / `stylua.toml` / `selene.toml`, treat those as ground truth. They override this skill.

---

## Code should be clean and human-readable

- **No filler comments.** Code that explains itself doesn't need a comment. Comments should explain *why*, not *what*.
- **No history comments.** No `-- TODO from 2023-04` / `-- old: x = 5` / `-- changed by Bob`. Use git.
- **No banner comments.** No `-- ===== SECTION ===== ` dividers. Section structure should be obvious from the code.
- **No restating obvious.** `-- Increment counter` next to `counter += 1` is noise.
- **Comments earn their place.** Hidden constraints, surprising edge cases, workarounds for engine bugs — those are worth explaining.
- **Names beat comments.** Rename `local x = ...` to `local pendingCount = ...` instead of writing `-- x is the pending count`.
- **Don't comment out dead code.** Delete it. Git remembers.

---

## Surface conflicts, don't silently resolve

If the codebase contradicts this skill:

- **Mention it once.** "This file uses `pairs(t)` everywhere; the skill prefers generalized iteration. I'll match the existing style — let me know if you want me to migrate."
- **Default to the codebase's style.** When in doubt, the existing pattern wins.
- **Don't lecture.** One line of context, then proceed.

---

## When in doubt

Adapt. Skills exist to inform, not to enforce.
