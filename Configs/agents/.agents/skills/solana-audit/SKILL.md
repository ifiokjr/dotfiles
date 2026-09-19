---
name: solana-audit
description: Deep security audit for anything Solana: Anchor programs, native Rust programs, SPL/Token-2022 usage, SDKs, clients, deploy tooling, off-chain infrastructure, and the whole release process (upgrade authority, multisig, verified builds, incident response). Use whenever the user asks for a security audit, security review, vulnerability assessment, exploit post-mortem, or an "is this safe?" check on a Solana codebase, even if the repo contains no on-chain program code, and when reviewing Solana protocol design, oracle setup, key management, or deployment safety. Built from real Solana audit reports (OtterSec, Neodyme, Zellic, Trail of Bits, Kudelski, Sec3) and the full exploit history of Solana and the wider blockchain ecosystem (Wormhole, Mango, Cashio, Drift, Ronin, Euler, Bybit).
---

# Solana security audit

Solana moved the bug surface. On Ethereum, a contract guards its own storage. On Solana, the client hands the program every account it will touch, and the runtime only enforces what the program itself checks: who signed, who owns each account, and whether it is the right account at all. The most common cause of loss on Solana is a program trusting an account supplied by the client. The second is trusting a price. The third is trusting a key.

An audit that only reads Rust will miss two of those three. This skill audits all three layers.

## The three loss layers

Every major Solana loss in history belongs to one of these layers. Review all three, in this order of historical damage:

| Layer | What fails | Canonical losses |
| --- | --- | --- |
| Operations: authorities, keys, process | Upgrade or withdrawal authority misuse, multisig signing hygiene, key leakage, supply chain | Drift Apr 2026 ($285M, durable-nonce pre-signing), Pump.fun 2024 ($1.9M, ex-employee authority), Slope 2022 (~$4M to $8M, logged seed phrases) |
| Code: accounts, CPI, arithmetic | Missing signer, owner, or type validation, PDA misuse, arbitrary CPI, overflow, rounding | Wormhole 2022 ($325M, spoofed signature set), Cashio 2022 (~$50M, fake collateral), Crema 2022 ($8.8M, fake tick array) |
| Economics: oracles, collateral, incentives | Spot-price manipulation in one transaction, junk collateral at full LTV, share-price inflation | Mango 2022 ($114M), Nirvana 2022 ($3.5M), Solend 2022 ($1.26M), Loopscale 2025 ($5.8M) |

Note the pattern in `references/incidents.md`: the code-layer bugs of 2022 are mostly extinct in new Anchor code, while operational losses keep growing. A modern audit that stops at "the constraints look fine" is answering yesterday's question.

## Workflow

### Phase 0: scope

Establish what is actually being audited before reading any code.

1. What is in the repo: Anchor programs (`programs/`, `Anchor.toml`), native Rust, SDKs and clients, scripts, CI.
2. What is deployed: program IDs, upgrade authorities, verified-build status. If the user names a program ID, audit the source of the deployed bytecode, not just repo HEAD.
3. What is the ask: pre-launch full audit, upgrade diff review, incident investigation, or a quick health check. Depth follows the ask, but the checklists below always apply.

If the repo has no program code, say so and audit what exists: client and SDK account handling, transaction construction, key handling, deploy scripts, CI. Most of `references/release-security.md` still applies.

### Phase 1: recon

Build an inventory before forming any judgment:

- Entry points: every instruction (Anchor `#[program]` handlers or `process_instruction` match arms).
- State: every account type, its discriminator, size, authorities, and who can create it.
- Authorities: admin, upgrade, freeze, and mint authority for each program and mint, and where those keys live.
- Oracles: which prices are read, from where, with what staleness and confidence handling.
- Dependencies: `Cargo.toml` and `Cargo.lock` versions of `solana-sdk`, `anchor-lang`, `spl-token`, `ed25519-dalek`, AMM and oracle crates.
- Money paths: every instruction that moves tokens or changes balances. These get the deepest review.

### Phase 2: threat model

Write down the assets, the actors (anonymous user, authority holder, oracle operator, multisig signer, employee with retained access), the entry points each actor reaches, and the invariants that must hold. The invariants are solvency (assets greater than or equal to liabilities), authority (only X can do Y), and accounting (shares times price never overstates). Every finding later in the report should trace back to a broken invariant, and every invariant should have a finding saying whether it holds.

### Phase 3: systematic code review

Work through `references/solana-vulnerabilities.md` class by class against every entry point. It contains the detection heuristics and a ripgrep pack. For anything with DeFi mechanics (vaults, lending, AMMs, perps), also apply the economic classes in `references/cross-ecosystem.md`. The ERC-4626 to Solana mapping there is direct.

Order the review: authority and admin paths first (smallest code, largest blast radius), then money paths, then the long tail.

### Phase 4: tooling pass

Run what the repo supports and record the outputs in the report appendix:

```bash
cargo clippy --all-targets -- -D warnings
cargo audit && cargo deny check
rg -n "overflow-checks" Cargo.toml   # must be true in [profile.release]; silent wrap is a Critical waiting to happen
cargo test && anchor test            # or litesvm / solana-program-test rigs
```

Static analyzers (Sec3 X-Ray), fuzzing and invariant campaigns (Trident, proptest with litesvm), and formal methods (Kani, Certora CVLR) are described in `references/methodology.md`. Recommend them where the math is heavy. Run them only if time allows and the harness exists.

### Phase 5: release and operations review

Walk `references/release-security.md`: upgrade authority custody, multisig and timelock configuration, verified builds matching the audited commit, buffer and keypair hygiene, supply-chain pins, monitoring on authority changes, `security.txt`, bounty. The Drift loss of April 2026 ($285M) happened entirely in this layer, with no code bug at all.

### Phase 6: incident cross-check

Compare the codebase against every root cause in `references/incidents.md`. That file is the compressed history of how Solana protocols actually die. A finding backed by "this is the Wormhole pattern" or "this is the Cashio pattern" lands harder and is rarely wrong.

### Phase 7: report

Use the severity rubric and report template in `references/methodology.md`. Summary first: counts by severity, one sentence per Critical and High, and an explicit statement of what was and was not reviewed.

## Severity rubric

| Severity | Test |
| --- | --- |
| Critical | Direct, unconditional path to stealing, freezing, or minting user funds, or full privilege escalation, reachable by an anonymous attacker |
| High | Loss of funds under realistic conditions: manipulable oracle, economic attack with profit, authority misuse by a rogue insider, upgrade that bricks accounts |
| Medium | Limited loss, edge-case conditions, costly griefing or denial of service, value leakage through rounding over time |
| Low | Hygiene and defense in depth: missing staleness checks with low impact, weak monitoring, missing `security.txt` |
| Informational | Code quality, documentation, non-security improvements |

Base severity on exploitability. A missing `has_one` on an admin-only instruction is Low. The same omission on a withdrawal path is Critical.

## Finding format

Every finding needs all five fields. Anything less is an opinion, not a finding:

1. Location: `file:line` plus the instruction and account involved.
2. Mechanism: what the code fails to check or does wrong, stated precisely.
3. Exploit scenario: the step-by-step transaction or instruction sequence an attacker follows.
4. Severity justification: preconditions, actor required, assets at risk.
5. Fix: the constraint, check, or refactor, and how it breaks the exploit path.

For Critical and High, write a proof of concept or the exact instruction sequence, including accounts and arguments. If you cannot construct one, the severity is probably wrong.

## Non-negotiables

- Audit the deployed artifact. Verify the on-chain program hash matches the repo (`solana-verify`, explorer verified badge; see `references/release-security.md`). An audit of source that differs from mainnet is worse than no audit, because it manufactures false confidence.
- Check `[profile.release] overflow-checks = true` first. Release builds wrap silently by default, and overflows of this kind (the Cetus class) live here.
- Never declare the codebase safe or secure. State residual risk and what was out of scope.
- Review diffs after every change. Re-review every upgrade diff against the last audit. Euler and Curve both shipped their losses in newly added code paths after clean audits.
- Treat grep as a starting point, not a finding. Read every heuristic hit from the ripgrep pack in context before it enters the report.

## Reading map

| Reference | Read when |
| --- | --- |
| `references/solana-vulnerabilities.md` | Phase 3. The full Solana taxonomy with detection heuristics and the ripgrep pack |
| `references/cross-ecosystem.md` | The code has DeFi economics, or you need the EVM to Solana mapping and general smart-contract classes (OWASP SC Top 10, SWC) |
| `references/incidents.md` | Phase 6. The exploit history of Solana and the wider ecosystem, with root causes |
| `references/release-security.md` | Phase 5. Deployment, upgrade authority, multisig, verified builds, supply chain, monitoring, incident response |
| `references/methodology.md` | Phase 7 and planning. The phased methodology, tooling matrix, invariant testing, pre-mainnet checklist, report template |
| `references/audited-programs.md` | You need comparable audited codebases, real audit reports to study, the firms active in Solana auditing, or engagement types |
