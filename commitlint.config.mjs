// Literal Conventional Commits 1.0.0 policy:
// https://www.conventionalcommits.org/en/v1.0.0/#specification
//
// This intentionally does not extend @commitlint/config-conventional. That preset
// adds team policy (an allowlisted vocabulary, lowercase types, line limits, and
// other restrictions) beyond the specification itself.
export default {
  parserPreset: "conventional-changelog-conventionalcommits",
  rules: {
    // Parseable requirements from the specification.
    "type-empty": [2, "never"],
    "subject-empty": [2, "never"],
    "body-leading-blank": [2, "always"],
    "footer-leading-blank": [2, "always"],

    // The specification does not constrain case, vocabulary, punctuation, or
    // line length. Commitlint cannot judge whether a noun is meaningful or
    // whether feat/fix accurately describes the change.
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

    // The specification allows either ! or a BREAKING CHANGE footer, and also
    // allows both. This rule would incorrectly require both or neither.
    "breaking-change-exclamation-mark": [0],
  },
};
