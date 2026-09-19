# Audit Methodology, Tooling, and Reporting

The expansion of the SKILL.md workflow: scoping questions, review order, tooling matrix (maintenance status as of Sep 2026), invariant testing, the pre-mainnet checklist, and the report template.

## Scoping questions (ask before opening the code)

1. Which program IDs are live on mainnet, and does the repo HEAD match the deployed hash? (If not: audit the deployed commit, flag the delta.)
2. Prior audits? Bug bounty? security.txt on the deployed binary? (Missing any of these is itself a finding.)
3. Who holds each authority (upgrade, mint, freeze, admin, pause)? Multisig? Timelock? Threshold?
4. What is the TVL/asset exposure, and what does the protocol promise users (parity, redeemability, price)?
5. What oracles feed it, and what collateral does it accept?
6. What is in scope beyond the programs: clients/SDK, keepers, deploy scripts, CI, front-end?

Deliverable of scoping: a one-paragraph threat model — assets, actors, entry points, invariants — agreed before findings start.

## Review order

1. `Cargo.toml` / `Anchor.toml` / `declare_id!` — `overflow-checks`, dependency pins, program ids.
2. Authority and admin paths (smallest code, largest blast radius).
3. Money paths: every instruction that moves tokens or changes balances.
4. State machine: init/close/reinit, migrations, account layout.
5. Oracles and pricing.
6. CPI surface and remaining accounts.
7. Everything else, then the ops layer (`release-security.md`).

## Tooling matrix

| Tool | What it does | Status (Sep 2026) |
| --- | --- | --- |
| `cargo clippy` | Baseline linting | Always |
| `cargo audit` / `cargo deny` | RustSec advisories, license/source checks | Always; flags `ed25519-dalek` 1.x (RUSTSEC-2022-0093) |
| Sec3 X-Ray ([sec3-product/x-ray](https://github.com/sec3-product/x-ray)) | Solana static analysis: missing account verification, type confusion, bump seeds, PDA sharing, arbitrary CPI | Live, low activity; rules encode the classic classes |
| crytic/solana-lints | Trail of Bits lints derived from sealevel-attacks | Useful Clippy supplement |
| `solana-program-test` / BanksClient | In-process integration tests | Official baseline |
| **litesvm** ([LiteSVM/litesvm](https://github.com/LiteSVM/litesvm)) | Fast in-process VM (`add_program`, `warp_to_slot`, `set_account`) | The 2025+ default for fast deterministic test rigs; `anchor-litesvm` integration exists |
| **Trident** ([Ackee-Blockchain/trident](https://github.com/Ackee-Blockchain/trident), ex-Trdelnik) | Anchor-aware fuzzing/invariant framework (TridentSVM), ~12k tx/s, regression testing between versions | Actively maintained; used on Kamino |
| `cargo-fuzz` / `proptest` + litesvm | Hand-rolled invariant/stateful fuzzing | Common practitioner pattern |
| Kani | Bit-precise Rust model checking | OtterSec has a published Solana case study; effortful |
| Certora CVLR ([Certora/cvlr-solana](https://github.com/Certora/cvlr-solana)) | Formal verification of Rust/Solana programs incl. SPL token patterns | Real (used on Squads, Jito, SPL); commercial |
| `solana-verify` ([solana-foundation/solana-verifiable-build](https://github.com/solana-foundation/solana-verifiable-build)) | Deterministic builds + on-chain hash verification + registry | The verification standard; see `release-security.md` caveats |
| Helius webhooks / Yellowstone gRPC | Runtime monitoring, authority-change alarms | See `release-security.md` |

EVM tools (Echidna, Halmos, Foundry) do not apply. Names that do **not** exist (do not recommend): "Vega" build tool, "yakfuzz", a `solana-auditors-book` repo.

## Invariant testing that is worth the effort

Write the protocol's invariants as executable properties, then attack them:

- **Solvency:** for random operation sequences, `total assets ≥ total liabilities + dust` in every reachable state.
- **Share math:** no sequence of deposit/withdraw/donate rounds value to an early depositor beyond fees (the ERC-4626 first-depositor attack — see `cross-ecosystem.md`).
- **Conservation:** tokens in − tokens out = inventory, per pool/vault, across swaps including fee edges.
- **Authority immutability:** authority fields change only via the admin instruction set, reachable only by the authority signer.
- **Liquidity math:** swap/liquidity operations never overflow at max-parameter corners (the Cetus class — fuzz the corners of the parameter space deliberately).

Harness: litesvm in-process, proptest-style sequences of adversarial instruction mixes (the attacker model: one wallet, unlimited capital, atomic multi-instruction transactions). Trident when the Anchor integration fits. Keep the harness in-repo afterward as a regression suite — it is the cheapest long-term defense an audit can leave behind.

## Pre-mainnet checklist

Code layer:

- [ ] `[profile.release] overflow-checks = true`; checked math in money paths
- [ ] Every instruction: signer/owner/type/derivation validated for every account (no `UncheckedAccount` without compensating checks)
- [ ] Every `init_if_needed`, `remaining_accounts`, and `Option<Account>` read and justified
- [ ] Every CPI program id pinned; post-CPI state re-validated
- [ ] Token paths: mints bound, `transfer_checked`, authorities enumerated
- [ ] Close/realloc paths reviewed; rent-exemption preserved
- [ ] Oracles: status, confidence, staleness, and manipulation-resistance argument per collateral; collateral quality review
- [ ] Share math: zero-share branches, rounding direction
- [ ] Randomness (if any): commit-reveal or VRF

Ops layer:

- [ ] Upgrade authority on a multisig with a sane threshold; timelock on execution; emergency-pause path pre-approved
- [ ] Deployed hash verified against the audited commit (record the hash in the report)
- [ ] Program keypair offline; buffers closed; no authority on any employee keyring
- [ ] `security.txt` embedded with contacts + policy; bug bounty registered
- [ ] Monitoring on ProgramData/authority changes and anomalous flows; alerting tested
- [ ] CI: pinned toolchains, SHA-pinned actions, minimal token permissions, `solana-verify build` artifact
- [ ] Upgrade-diff review process documented (every future change re-audited)

## Report template

```markdown
# Security Audit: <Protocol>
Auditor / engagement / date
Scope: <programs, commits, deployed program IDs + verified hashes>
Out of scope: <explicit list — clients, infra, dependencies, unaudited modules>

## Executive summary
<n> findings: <c> Critical, <h> High, <m> Medium, <l> Low, <i> Informational.
One paragraph: overall posture, the single biggest risk, and the state of the ops layer.
What was reviewed vs not; residual risk statement.

## Findings summary
| ID | Title | Severity | Status |
| --- | --- | --- | --- |

## Findings
### <ID> <Title> — <Severity>
- **Location:** file:line, instruction, account
- **Mechanism:** what is missing/wrong, precisely
- **Exploit scenario:** step-by-step instruction sequence an attacker follows
- **Proof:** PoC code or exact transaction construction (Critical/High mandatory)
- **Impact:** assets at risk, preconditions, actor required
- **Recommendation:** the fix, and how it breaks the exploit path
- **References:** prior incidents of this class (Wormhole/Cashio/Mango/Drift/...)

## Coverage and method
Instructions reviewed (x of y), threats modeled, invariants tested, tools run (outputs in appendix)

## Appendix
Tool outputs, verified-build evidence, authority inventory
```

Severity tests (from SKILL.md, with the calibration question): would this finding have stopped the nearest historical incident? A missing owner check is "the Cashio class"; an unguarded collateral whitelist is "the Mango/Drift class"; a zero-timelock multisig is "the Drift signing ceremony". Tying findings to history is the most persuasive thing a Solana report can do.

## After the report

- Re-review every fix (fix review is its own engagement — see `audited-programs.md`).
- Re-verify the deployed hash after the patched upgrade ships; confirm the fix is live, not merged.
- Leave the invariant/fuzz harness in-repo; recommend continuous auditing or per-release diff review for anything with TVL growth.
