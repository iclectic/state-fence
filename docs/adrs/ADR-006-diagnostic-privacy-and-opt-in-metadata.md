# ADR-006: Diagnostic privacy and opt-in metadata

## Status

Proposed

## Context

Diagnostic timelines must not leak sensitive application state. Arbitrary state payloads may contain tokens, passwords, personal data or payment information.

## Proposed Decision

- Metadata capture is opt-in per fence and per operation.
- Default redaction removes keys such as `password`, `token`, `secret`, `authorisation` and `cookie`.
- A custom redactor callback can be supplied.
- Nested maps and lists are redacted recursively.
- State object contents are never automatically serialised.

## Consequences

- Exports are safe by default.
- Users must explicitly enable metadata and pass values they want recorded.
- Redaction rules are documented and tested.
