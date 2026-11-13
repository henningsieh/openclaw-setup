---
name: literal-centralization
description: Centralizing duplicated literals or fixture ids into one constants module across source and tests: mapping, dry run, type widening, zero-literal guard.
---

# Literal Centralization

Replace literals repeated across source and tests (fixture ids, keys, route strings) with one constants module, so each value is declared once and drift fails the compiler instead of a random assertion.

## 1. Build the literal-to-symbol map from the module

Parse the constants module itself rather than grepping the tree by eye: walk its lines, track the enclosing keys, and record every `key: "value"` pair as `value -> SYMBOL.key.path`. Report the pair count before touching code.

## 2. Abort on ambiguity and on unusable positions

- Stop when one literal maps to more than one symbol; a silent pick would miswire a fixture.
- Detect object-key positions (`"<literal>":`) in the target files: a bare constant cannot stand where a key is required, so rewrite those by hand.
- Run the replacement in dry-run mode first and print files, distinct literals and flagged positions. Only apply after a clean dry run.

## 3. Rewrite quoted literals and prove none remain

Match the project's literal shape as a quoted string (`"([a-z0-9]{24})"` for cuid-shaped ids) and substitute the symbol path. Afterwards re-run the same scan and require zero matches in the target files; a leftover match means the pattern missed a form of the literal.

## 4. Insert the import after the import block

Find the last line of the leading import block whose trimmed text ends with `";` and insert the new import after it. Do not insert after the first line that starts with `import `: when that import is a multi-line `import { ... }` block, the insertion lands inside the braces. A parser error means the script's insertion point was wrong; fix the script and re-run from a clean tree rather than patching the broken file.

## 5. Widen literal types at the module, not at every call site

An `as const` module gives every value a literal type, so assigning one constant to a variable inferred from another fails to type-check. Keep key paths checked and widen only the leaves:

```ts
type Widen<T> = {
  readonly [K in keyof T]: T[K] extends string ? string : Widen<T[K]>;
};
const identities = { /* ... */ } as const;
export const IDS: Widen<typeof identities> = identities;
```

Call sites can then assign, collect and pass the values as `string`, while a typo in a key path still fails to compile.

## 6. Type-check through the project script

Run the package's `type-check` script instead of bare `tsc`: Next projects generate route types, and a `.next/dev/types` tree left by an earlier dev run reports unrelated module-not-found errors for routes that no longer exist. Delete the build directory and re-run the script when the checker still reads generated files.

## 7. Guard the invariant with a test

Add a test that scans the target sources, filters the literals matching the constants module, and fails when any match remains. This catches the next hand-written literal, which a one-off rewrite cannot.

## 8. Verify and report

Run, in order: the zero-literal scan, the formatter and linter on the changed files, then the affected tests. Report the number of files and distinct literals rewritten, confirm no fixture value changed, and name the guard that prevents regression.
