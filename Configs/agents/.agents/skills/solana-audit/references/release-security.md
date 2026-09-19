# Release, Deployment, and Operational Security

The layer where Drift lost $285M without a single code bug. Review it for every audit, even "just a program review": who can change the code, who can move the money, and how would anyone notice in time.

## Program identity and keys

- A program address is an ordinary Ed25519 keypair (`solana-keygen new -o target/deploy/<name>.json`, optionally ground for vanity). It must sign the **initial deploy only**; afterwards the upgrade authority controls changes. Keep the program keypair offline/air-gapped — it is needed once.
- If the keypair leaks **before first deploy**, an attacker can deploy their own program at your address and become its upgrade authority (program-id hijack). Mitigate by deploying before publicizing the address. No public incident of this class exists (as of Sep 2026) — it remains a hygiene item.
- Anchor pins the address via `declare_id!` and enforces it in generated validation code; `anchor keys sync` rewrites from the keypair. `declare_id` drift across crates/tests is a real bug class — diff the values and run `keys sync` in CI.
- The **upgrade authority** can be any pubkey: a hardware wallet (CLI accepts `usb://ledger` URLs), a Squads multisig, or a PDA-based timelock (Ellipsis Labs' [timelock-program-authority](https://github.com/Ellipsis-Labs/timelock-program-authority) is the reference design). The upgrade authority **cannot** be left to chance: it is the master key to everyone's funds.

## Deployment mechanics (Agave CLI)

```bash
solana program deploy ./program.so --buffer <KEYPAIR>   # two-phase: write to a buffer account first
solana program deploy <BUFFER_PUBKEY> --program-id <ID> # activate from buffer (resumable after failure)
solana program close --buffers                          # recover lamports from stale buffers
solana program set-upgrade-authority <PROGRAM> --new-upgrade-authority <NEW>
                                                        # NEW must co-sign by default — a mistype guard
                                                        # (opt-out flag exists; never use it casually)
solana program set-upgrade-authority <PROGRAM> --final  # irreversible: program can never be upgraded again
solana program deploy --final                           # deploy immutable from the start
solana program close <PROGRAM> --bypass-warning         # permanently closes the program; address never reusable
```

- `--final` trades upgradeability for immutability. Right for finished, security-critical code (many SPL programs); wrong for anything needing incident response.
- `solana program close` on mainnet is the OptiFi incident ($661k bricked by a developer's mistaken close, Aug 2022): treat close and authority-change commands as production incidents waiting for a bad day — procedure them behind multisig.
- `--max-len` pre-allocates program-data space to avoid expensive extensions later.

## Upgrade authority: the controls that matter

1. **Multisig, not a single key.** Squads V4 (program `SMPLecH534NA9acpos4G6x7UF97GZsaF7Zaomboqvgc` — verify on-chain before relying on it) is the standard; docs at [docs.squads.so](https://docs.squads.so).
2. **Timelock on execution.** Squads supports a global timelock (1h/1d/1w presets) that starts after the approval threshold is met. It buys defenders a window to react to a malicious or coerced approval — and it is exactly what Drift's 2/5 zero-timelock council lacked in April 2026. Timelocks slow incident response; that trade is real, and the answer is a separate, pre-approved emergency-pause path, not removing the timelock.
3. **Threshold sanity.** 2-of-5 with no delay is one phished signer away from catastrophe. Threshold should make individual signer compromise insufficient.
4. **Simulation before signing.** Signing flows must show and simulate the full transaction (accounts, instruction data, diffs). Durable-nonce pre-signing turns any signature into a standing credential — see `solana-vulnerabilities.md` K.
5. **Offboarding = revocation.** Pump.fun's $1.9M was a former employee with retained withdrawal authority. Authority inventories (who can do what, where the key lives) belong in the audit report.

## Verified builds: prove the source matches mainnet

Solana has no native Etherscan-style verification. The stack:

- **solana-verify** ([solana-foundation/solana-verifiable-build](https://github.com/solana-foundation/solana-verifiable-build), originally Ellipsis/OtterSec): `solana-verify build` (deterministic Docker build), `get-program-hash` / `get-executable-hash` (compare on-chain vs built), `verify-from-repo`, and an on-chain PDA registry recording repo URL + commit. The verify program itself is deployed by OtterSec and re-verifies registered programs every 24h, auto-unverifying after upgrades. Results surface in Solana Explorer / Solscan / SolanaFM as the verified badge.
- **anchor verify** — Anchor-flavored deterministic build + hash comparison. The old Anchor Program Registry is deprecated.
- Multisig-gated programs push the verification PDA via Squads (`solana-verify export-pda-tx`).

**Caveats:** the badge proves source↔bytecode equality, not safety; and Accretion demonstrated ways to display a verified badge for programs not built from the claimed source ([accretion.xyz](https://accretion.xyz)). Verification is trust-enhancing, not tamper-proof. For an audit: verify the hash yourself from the pinned commit and record it in the report; if the deployed hash does not match the repo, that is the first finding.

## Upgrades: what breaks when code changes under live state

- Upgrades swap BPF bytecode; accounts persist. Any change to account structs shifts Borsh offsets and corrupts/deserialization-fails old accounts. Anchor discriminators are `sha256("account:<Name>")[..8]` — renaming or merging structs orphans existing accounts.
- Review every upgrade diff for: new instructions (new entry points = new attack surface), changed constraints on existing accounts (tightening can brick old accounts, loosening opens them), `space =` updates for added fields, and `realloc` paths for migrating existing accounts.
- Migration instructions (`migrations/*.ts` via `anchor run migrate`, or on-chain migrate handlers keyed by authority) must themselves be audited — they are privileged code that touches every account.
- Deterministically rebuild both versions (`solana-verify build` at old/new commits) and diff the source; confirm the on-chain hash actually changed to the reviewed build.

## Supply chain

- **Rust dependencies:** `Cargo.lock` committed; `cargo audit` and `cargo deny check` in CI. Solana-relevant advisory: **RUSTSEC-2022-0093 / CVE-2022-50237** — `ed25519-dalek` 1.x malleable/non-strict verification (incl. batch path); pin ≥ 2.0 wherever the program verifies Ed25519 signatures. Also track `curve25519-dalek`, `solana-sdk`, `anchor-lang`, AMM/oracle crates.
- **Toolchain pins:** `rust-toolchain.toml`, pinned `solana`/Agave and `anchor` (avm) versions; build in CI with the same pinned versions that produce the deployable artifact (`solana-verify build` in CI so the CI binary **is** the mainnet binary).
- **CI actions:** pin third-party actions by full commit SHA, minimal `GITHUB_TOKEN` permissions. The tj-actions/changed-files compromise (CVE-2025-30066, Mar 2025) retagged every version to a commit that dumped runner memory — secrets included — into public logs across 23k+ repos.
- **Front-end/signing supply chain:** Bybit's $1.4–1.5B loss was a compromised Safe{Wallet} build showing signers a benign UI while the payload swapped the proxy implementation. Solana analogues: wallet-adapter code, transaction-building libs, anything that renders what a human signer sees. Integrity: SRI/CSP, vendored deps, and on-device verification of transaction contents.

## Post-deploy hygiene

- **security.txt** ([neodyme-labs/solana-security-txt](https://github.com/neodyme-labs/solana-security-txt)): embeds RFC-9116-style contact/policy in the deployed binary via the `security_txt!` macro; readable with `query-security-txt` and by explorers. Required fields: name, project_url, contacts, policy. Ship it with the `auditors` field filled.
- **Bug bounty**: register on Immunefi (or equivalent) once audits are done.
- **Token authorities**: audit every mint the protocol touches — retained mint authority after distribution (infinite-mint risk), freeze authority holders, Token-2022 extensions (permanent delegate especially — see `solana-vulnerabilities.md` E4).

## Monitoring and detection

- **Helius webhooks** (raw or enhanced/parsed) for program events and balance changes; wire to PagerDuty/Discord.
- **Yellowstone gRPC** ([rpcpool/yellowstone-grpc](https://github.com/rpcpool/yellowstone-grpc)) account/transaction subscriptions: watch the program's **ProgramData account** (upgrade authority field) and any `SetUpgradeAuthority`/upgrade instructions touching your program ID — authority movement is the loudest alarm in this ecosystem and almost nothing fires it by default.
- Explorer state (verified badge, authority history) via Solana Explorer/Solscan/SolanaFM for user-facing assurance.
- In-program **circuit breakers**: halt flags, per-oracle deviation/staleness breakers, per-market limits. Drift 2026 had breaker-style machinery and none fired in time; design breakers to trip on the *economic* signals (collateral whitelist changes, limit raises) not just price moves.

## Incident response playbook (what teams actually did)

1. **Pause** via in-program halt flags (Loopscale paused markets via protocol flags; Wormhole guardians halted minting).
2. **Emergency upgrade** through the multisig — this is the legitimate reason to keep a fast path; pre-approve a pause-proposal template so it exists before it is needed.
3. **Contain movement**: SPL freeze authority freezes specific token *accounts* (halts transfers; cannot confiscate — permanent delegate is the confiscation tool, if designed in). Note: Sui validators voted to freeze $162M of Cetus funds in 2025 — Solana has **no such precedent**; do not plan on validator intervention.
4. **Negotiate**: on-chain bounty messages (Wormhole's $10M offer; Loopscale's 90% deal — attacker returned 100%; Crema's negotiated partial return).
5. **Backstop/reimburse**: Jump Crypto covered Wormhole's $325M within days; DAO votes and insurance funds elsewhere.
6. **Trace and engage**: TRM/Chainalysis-style tracing, law enforcement; bridge-out to Ethereum is the point of no return for recovery.

Every one of these steps depends on preparation done before the incident: pause paths coded and tested, multisig quorum reachable, contacts in `security.txt`, RPC/webhook monitoring live. The audit report should state which of these exist and which are missing.
