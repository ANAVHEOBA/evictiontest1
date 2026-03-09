# Nebula Yield - Eviction Vault Hardening (Phase 1, Day 1)

This repository tracks the Day 1 hardening milestone for the Eviction Vault smart contract.
The original monolithic contract was decomposed into a modular architecture with layered concerns.
Primary goal: eliminate known critical issues and validate fixes with repeatable tests.

## Day 1 Scope
- Refactor single-file vault logic into a multi-file contract stack.
- Preserve functional behavior while improving safety and maintainability.
- Address critical issues around authorization, fund flow, and execution gating.

## Critical Areas Addressed
- `setMerkleRoot` restricted to authorized council members.
- `emergencyWithdrawAll` restricted to authorized council members.
- Removed `tx.origin` dependency in `receive()` accounting.
- Replaced fragile transfer patterns with safe `call` handling.
- Enforced timelock requirements in multisig execution flow.
- Added pause-state enforcement across sensitive operations.

## Deliverables Implemented
- Modular contracts under `src/` with clear responsibility boundaries.
- OpenZeppelin cryptography integration (`MerkleProof` and `ECDSA`).
- Comprehensive unit/hardening tests and invariant property tests.
- Successful `forge build`, `forge test`, gas report, and gas snapshot.

## Acceptance Status
- Contract is no longer a single-file monolith.
- Listed Day 1 vulnerabilities are implemented and covered by tests.
- Positive and negative test paths pass in local Foundry runs.
