# Literal Conventional Commits 1.0.0 policy

Use this branch only when the user wants the specification rather than a stricter Angular-style
team convention. Commitlint can enforce its parseable requirements, but not semantic judgments such
as whether the type is actually a noun or whether `feat` versus `fix` describes the change.

## Minimal configuration

Install `@commitlint/cli` and the Conventional Commits parser preset as exact dev dependencies.
The config below disables restrictions that the specification does not make and keeps the rules
that map directly to its required structure.

```js
// commitlint.config.mjs
export default {
  parserPreset: "conventional-changelog-conventionalcommits",
  rules: {
    "type-empty": [2, "never"],
    "subject-empty": [2, "never"],
    "body-leading-blank": [2, "always"],
    "footer-leading-blank": [2, "always"],

    // The specification does not constrain type/scope/subject case, type
    // vocabulary, description punctuation, or line length.
    "type-case": [0],
    "scope-case": [0],
    "scope-empty": [0],
    "subject-case": [0],
    "type-enum": [0],
    "subject-full-stop": [0],
    "header-full-stop": [0],
    "body-case": [0],
    "body-full-stop": [0],
    "header-max-length": [0],
    "body-max-line-length": [0],
    "footer-max-line-length": [0],

    // The specification permits either ! or BREAKING CHANGE, and also both;
    // this rule would incorrectly require XNOR behavior.
    "breaking-change-exclamation-mark": [0],
  },
};
```

The parser must recognize `BREAKING CHANGE:` and `BREAKING-CHANGE:` as note tokens and Git
trailers. Confirm this with test cases rather than assuming the configuration is correct.

**Important parser/rule interaction:** keep `scope-empty` disabled. An omitted scope is valid, and
Commitlint's `scope-empty` rule reports both an omitted scope and `scope()` as empty. The stock
rule therefore cannot express “scope is optional, but a present scope must not be empty.” Do not
use it in either policy. Detect `type()` in a custom rule/parser if that distinction is worth
enforcing; otherwise leave the semantic check to review.

## Test matrix

Run Commitlint against temporary message files or stdin, not by making temporary commits.

| Case | Expected |
|---|---|
| `feat: add search` | pass |
| `fix(parser): handle empty input` | pass |
| `docs: clarify recovery steps` | pass |
| `housekeeping: replace generated fixture` | pass; the spec allows types beyond `feat` and `fix` |
| `FeAt: add search` | pass; units are not case-sensitive |
| `feat(api)!: remove legacy endpoint` | pass |
| `feat: remove legacy endpoint` plus `BREAKING CHANGE: clients must migrate` | pass |
| `BREAKING-CHANGE: ...` footer | pass |
| `feat: add search` + blank line + body + blank line + `Refs: #12` | pass |
| `Update authentication` | fail: missing type/description structure |
| `feat:` | fail: empty description |
| `feat(): add search` | pass with the stock rules; an empty *present* scope is not mechanically distinguishable from omission, so use a custom rule or review |
| body immediately below the description | fail: missing required blank line |
| footer immediately below the body/description | fail: missing required blank line |
| `feat!():` | fail: empty description; a custom rule is needed to reject the empty present scope separately |
| unknown or mixed-case type | pass unless the user separately chooses an allowlist/lowercase policy |
| description ending in `.` or exceeding 100 characters | pass under this literal policy |

Also test either the `!` marker or a breaking footer **without the other**; both are independently
valid under the specification.

## Stricter team policy branch

If the user wants the common maintained preset instead, extend
`@commitlint/config-conventional` and state that it adds team policy beyond the specification. Pin
and inspect the installed preset version before listing its exact rules. Expect restrictions around:

- an enumerated type vocabulary;
- lowercase types;
- 100-character header/body/footer line limits;
- descriptions that do not end in `.`;
- subject casing exclusions.

Do not call that preset “exact Conventional Commits 1.0.0” unless the extra restrictions are
disabled. Likewise, do not run Commitlint over old history when the request is only to enforce new
commits.
