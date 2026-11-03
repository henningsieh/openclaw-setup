---
name: react-query-change-review
description: "Reviewing commits that add React Query hooks, prefetching, or selector preloads: direct tests, mock coverage, gating, and caps."
---

# React Query change review

Use when reviewing a commit or PR that adds or changes `useQuery`, `useSuspenseQuery`, `useMutation`, `queryClient.query`/`prefetchQuery`, or a selector's `preload` data source.

## 1. Review the commit that is actually on the branch

```bash
git fetch origin
git switch <branch>
git pull --ff-only
git log -1 --oneline
```

Confirm the HEAD hash matches the commit under review. A stale checkout gives false test results.

Re-run `git status --short --branch` and `git reflog -5` before and after a long test run. A shared checkout can be switched by another session, so attribute test artifacts only to the HEAD you actually tested. Prefer `git worktree add` for a long review.

## 2. Map the data flow

Read the diff and list:

- new or changed hooks and their `queryOptions` inputs
- server prefetches and their query keys
- props or permission flags that control whether the consuming UI renders
- the preload source: full entity list or derived from existing relations

## 3. Run the direct component tests

```bash
pnpm --filter <package> exec vitest run <changed-component>.test.tsx
pnpm --filter <package> run type-check
```

Check: the component's own test file runs and passes. Route, page, or streaming tests can pass while the component test fails because they mock the data layer at a different boundary.

A new suspense query that is not mocked usually renders an empty body rather than a query error; inspect the first failing `findBy*` assertion.

## 4. Audit the component test mock

- If the mock spreads the original module and overrides only the imperative client, a new generated query-options hook still calls the original query function.
- Override the exact query-options accessor and replace only `queryFn`; keep the original `queryKey`.
- When one function serves both preload (`search: ""`) and typed search, make the mock read the input. One static return breaks one of the two paths.

## 5. Check render and prefetch gating

- Prefetch only when the consuming UI renders. An unconditional `useSuspenseQuery` in a parent fetches for users who never see the form and can take down the surrounding error boundary.
- Match the gate with `useQuery({ ..., enabled: gate })` or a child component mounted only under the gate.
- Use the same query key and input on server prefetch and client hook; otherwise the client refetches.

## 6. Check the preload source and endpoint cap

- Preload selectors from the full entity list, not from existing relations; otherwise new entities are missing until the user types a search.
- Read the endpoint's `limit` and output `max`. "All entities" may mean the first 20. State the cap or switch to a paginated list endpoint.
- Assert the preload in the component test: an unlinked entity appears before typing, and the gated query does not run when the gate is false.

## 7. Report

Lead with blocking findings. Include the exact test command, pass/fail counts, and type-check result. Distinguish a broken direct test from passing route tests. Do not call the change merge-ready while a direct component test fails.

Name the failing suite exactly; a Playwright `merge` config is a cross-app test suite, not a Git merge.

When asked to file the finding as an issue, follow `references/review-finding-issue.md`.
