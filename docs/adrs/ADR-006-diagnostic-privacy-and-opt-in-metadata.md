# ADR-006: Diagnostic privacy and opt-in metadata

## Status

Accepted

## Context

Diagnostic timelines must not leak sensitive application state. Arbitrary state payloads may contain tokens, passwords, personal data or payment information.

## Decision

- Metadata capture is opt-in per fence and per operation.
- Default redaction removes keys such as `password`, `token`, `secret`, `authorisation` and `cookie`.
- A custom redactor callback can be supplied.
- Nested maps and iterables are redacted recursively. A sensitive key redacts its whole subtree, so a structured secret cannot leak through recursion.
- Recursion is bounded by a configurable maximum depth, so cyclic or pathologically nested metadata is truncated rather than looping.
- Redaction and export are total. Non-`String` map keys are stringified and values that JSON cannot represent natively are encoded with `toString`, so a diagnostic export cannot throw because of the shape of caller-supplied metadata.
- State object contents are never automatically serialised.

## Consequences

- Exports are safe by default.
- Users must explicitly enable metadata and pass values they want recorded.
- Redaction rules are documented and tested.
- A diagnostic path never becomes the cause of a crash, which matters because diagnostics are most often read when something is already wrong.
