# Roadmap

This page contains intentionally deferred work. Active implementation work is
tracked in Beads, not here.

## Golden tests

Golden tests are not configured. Add them after the feed, post card, sheets,
offline, empty, and error states are stable in a released build and match the
Figma reference in a manual overlay review. Until then, widget structure and
behaviour tests provide faster, less brittle feedback.

## Commitlint

Commitlint is deferred until the first verified release. Current commits use
Conventional Commit messages by convention. Add local and CI enforcement only
when it protects an established release workflow rather than delaying product
work.
