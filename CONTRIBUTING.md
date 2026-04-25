# Contributing

## Skill layout

```
skills/<name>/
├── SKILL.md          entry point — loaded into the agent's context
├── references/       deep-dive markdown the agent can pull on demand
└── examples/         runnable code that shows the patterns in use
```

The frontmatter `description` is what decides when this skill loads. Keep it specific and short — say what the skill covers and what it doesn't (which sibling skill owns adjacent topics). A bloated description triggers on more prompts than it should.

## Writing a good skill

A good skill reads like notes from someone who actually uses the thing — not a textbook. Some things that help:

- **Cite real sources.** Link to the canonical docs / repo / yaml file the rule comes from. Don't quote API signatures from memory; verify against creator-docs YAML or upstream source.
- **Slim SKILL.md, deep references.** SKILL.md is loaded into context every time the skill matches; references are only pulled when the agent follows a link. Aim for SKILL.md around 300–500 lines, push details into `references/`.
- **Anti-pattern table at the end.** A scannable cheat-sheet of common mistakes paired with the right pattern is worth more than 200 lines of prose.
- **Verification rules.** Note which APIs / fields evolve. Tell the agent when to check live docs instead of trusting the skill.
- **Examples that run.** Each example file demonstrates one focused pattern. Don't bundle five concepts into one file.

## Examples

- **`.luau` extension** for new code (Rojo accepts legacy `.lua` too; existing repos may use it).
- **`--!strict` is the default**, not a rule. If the skill is about non-strict patterns or migrating legacy code, write examples in the mode that fits.
- **Comments earn their place.** Explain *why*, not *what*. Names beat comments. Don't decorate with banners.
- **Self-contained.** Assume packages exist at conventional paths (`ReplicatedStorage.Packages.X`).

## Integration Policy

Every SKILL.md must include a short `## Integration Policy` section near the top that links to [`shared/integration-policy.md`](shared/integration-policy.md). The shared file is the canonical source; each skill's section is a 2-paragraph summary so the rule loads even if the agent doesn't follow the link.

Template:

```markdown
## Integration Policy

This skill describes preferred patterns; it does **not** authorize rewriting existing code. Apply rules to new code and to changes the user explicitly asks for. Match the codebase's existing style. <one skill-specific line>. Surface conflicts once and default to the existing pattern.

Full rules: [`../../shared/integration-policy.md`](../../shared/integration-policy.md).
```

Why duplicate? Anthropic's skill format loads each SKILL.md as a self-contained unit — there's no `extends` mechanism. The shared file + short copy + link is the closest thing to inheritance that works in practice.

## Naming

- Skills: lowercase, hyphenated, domain-prefixed where useful (`luau-expert`, `roblox-dev`, `roblox-toolchain`, `roblox-ui`).
- References: `references/<topic>.md`.
- Examples: `examples/<scenario>.luau`.

## When to split a skill

If two topics consistently load in the same conversations, keep them together. If they trigger in different contexts, split. The frontmatter description test: if you can't say what the skill covers in 3 lines, it's probably two skills.

Don't split when topics only make sense paired — Rojo sync rules and project format share enough mental model to live in one skill.

## Before merging

- The frontmatter description triggers on representative prompts and not on unrelated ones.
- All references linked from SKILL.md exist.
- Every example file is syntactically valid Luau.
- The anti-pattern table matches what the body actually says.
- The Integration Policy section is present and links to `shared/integration-policy.md`.
