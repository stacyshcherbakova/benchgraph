# Initial Documentation Spec

Working name: BenchGraph. Provisional.

## Goal

Create the initial documentation and research base for a macOS DMG desktop app inspired by GraphPad Prism: a modern, Mac-native tool for scientific data tables, common statistical analyses, publication-quality plots, and figure export.

## Current State

- Repository is empty except for `.git`.
- No existing docs, source code, package metadata, or conventions were present.

## Constraints

- Documentation only.
- No commit or push.
- Keep the research concise, technical, and useful.
- Avoid public-facing brand dependence on GraphPad Prism.
- Prefer source-backed market notes over generic positioning.
- Assume direct macOS distribution by DMG unless product strategy changes.

## Proposed Structure

```text
docs/
  README.md
  project-spec.md
  research/
    market-research.md
  product/
    mvp-roadmap.md
```

## Files Created

- `docs/README.md`: documentation index and naming note.
- `docs/project-spec.md`: this implementation spec.
- `docs/research/market-research.md`: competitor and gap analysis.
- `docs/product/mvp-roadmap.md`: MVP, V1/V2/V3 roadmap, workflows, feature floor, and risks.

## Risks And Edge Cases

- Market data changes quickly, especially pricing and licensing. Treat prices as research snapshots.
- User pain points are partly inferred from official positioning and public user discussion; validate with interviews before product commitment.
- Scientific statistics software requires high trust. Any later implementation must use validated calculations, documented assumptions, and regression test fixtures.
- macOS direct distribution requires Apple Developer ID signing, notarization, update infrastructure, and support outside the Mac App Store.

## Test Plan

- Verify Markdown files render and links are reachable.
- Confirm docs are separated by research vs product/technical planning.
- Confirm no source code, commits, or pushes are made.

## Follow-Up Work

- Interview 10-15 target users across wet labs, academic core facilities, biotech, and computational users.
- Build a test corpus of Prism-like workflows: t test, ANOVA, nonlinear curve fit, dose-response, standard curve, and multi-panel figure export.
- Decide whether the statistics engine is native Swift, embedded R, Rust/C++ core, or hybrid.
