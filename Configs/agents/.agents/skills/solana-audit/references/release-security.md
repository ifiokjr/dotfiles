# Release, deployment, and operational security

The layer where Drift lost $285M without a single code bug. Review it for every audit, even "just a program review": who can change the code, who can move the money, and how would anyone notice in time.

## Program identity and keys

- A program address is an ordinary Ed25519 keypair (`solana-keygen new -o target/deploy/<name>.json`, optionally ground for vanity). It must sign the initial deploy only, and afterwards the upgrade authority controls changes. Keep the program keypair offline or air-gapped, because it is needed once.
- If the keypair leaks before the first deploy, an attacker can deploy their own program at your address and become its upgrade authority (program-id hijack). Mitigate this by deploying before publicizing the address. No public incident of this class exists (as of Sep 2026), so it remains a hygiene item.
- Anchor pins the address via `declare_id!` and enforces it in generated validation code; `anchor keys sync` rewrites from the keypair. Drift in `declare_id` across crates or tests is a real bug class, so diff the values and run `keys sync` in CI.
- The upgrade authority can be any pubkey: a hardware wallet (the CLI accepts `usb://ledger` URLs), a Squads multisig, or a PDA-based timelock (Ellipsis Labs' [timelock-program-authority](https://github.com/Ellipsis-Labs/timelock-program-authority) is the reference design). The upgrade authority cannot be left to chance, because it is the master key to everyone's funds.

## Deployment mechanics (Agave CLI)

```bash
solana program deploy ./program.so --buffer <KEYPAIR>   # two-phase: write to a buffer account first
solana program deploy <BUFFER_PUBKEY> --program-id <ID> # activate from buffer (resumable after failure)
solana program close --buffers                          # recover lamports from stale buffers
solana program set-upgrade-authority <PROGRAM> --new-upgrade-authority <NEW>
                                                        # NEW must co-sign by default, a mistype guard
                                                        # (opt-out flag exists; never use it casually)
solana program set-upgrade-authority <PROGRAM> --final  # irreversible: program can never be upgraded again
solana program deploy --final                           # deploy immutable from the start
solana program close <PROGRAM> --bypass-warning         # permanently closes the program; address never reusable
```

- `--final` trades upgradeability for immutability. It is right for finished, security-critical code (many SPL programs) and wrong for anything needing incident response.
- `solana program close` on mainnet is the OptiFi incident ($661k bricked by a developer's mistaken close, Aug 2022), so treat close and authority-change commands as production incidents waiting for a bad day and put them behind multisig.
- `--max-len` pre-allocates program-data space to avoid expensive extensions later.

## Upgrade authority: the controls that matter

1. **Multisig, not a single key.** Squads V4 (program `SMPLecH534NA9acpos4G6x7UF97GZsaF7Zaomboqvgc`, which you should verify on-chain before relying on it) is the standard; docs at [docs.squads.so](https://docs.squads.so).
2. **Timelock on execution.** Squads supports a global timelock (1h/1d/1w presets) that starts after the approval threshold is met. It buys defenders a window to react to a malicious or coerced approval, and it is exactly what Drift's 2/5 zero-timelock council lacked in April 2026. Timelocks slow incident response; that trade is real, and the answer is a separate, pre-approved emergency-pause path, not removing the timelock.
3. **Threshold sanity.** 2-of-5 with no delay is one phished signer away from catastrophe. The threshold should make individual signer compromise insufficient.
4. **Simulation before signing.** Signing flows must show and simulate the full transaction (accounts, instruction data, diffs). Durable-nonce pre-signing turns any signature into a standing credential. See `solana-vulnerabilities.md` K.
5. **Offboarding = revocation.** Pump.fun's $1.9M was a former employee with retained withdrawal authority. Authority inventories (who can do what, and where the key lives) belong in the audit report.

## Verified builds: prove the source matches mainnet

Solana has no native Etherscan-style verification. The stack:

- **solana-verify** ([solana-foundation/solana-verifiable-build](https://github.com/solana-foundation/solana-verifiable-build), originally from Ellipsis and OtterSec): `solana-verify build` (deterministic Docker build), `get-program-hash` / `get-executable-hash` (compare on-chain vs built), `verify-from-repo`, and an on-chain PDA registry recording repo URL and commit. The verify program itself is deployed by OtterSec and re-verifies registered programs every 24h, auto-unverifying after upgrades. Results surface in Solana Explorer / Solscan / SolanaFM as the verified badge.
- **anchor verify** does an Anchor-flavored deterministic build and hash comparison. The old Anchor Program Registry is deprecated.
- Multisig-gated programs push the verification PDA via Squads (`solana-verify export-pda-tx`).

The badge proves source↔bytecode equality, not safety, and Accretion demonstrated ways to display a verified badge for programs not built from the claimed source ([accretion.xyz](https://accretion.xyz)). Verification is trust-enhancing, not tamper-proof. For an audit: verify the hash yourself from the pinned commit and record it in the report; if the deployed hash does not match the repo, that is the first finding.

## Upgrades: what breaks when code changes under live state

- Upgrades swap BPF bytecode; accounts persist. Any change to account structs shifts Borsh offsets and corrupts old accounts or makes them fail deserialization. Anchor discriminators are `sha256("account:<Name>")[..8]`, so renaming or merging structs orphans existing accounts.
- Review every upgrade diff for: new instructions (new entry points are new attack surface), changed constraints on existing accounts (tightening can brick old accounts, loosening opens them), `space =` updates for added fields, and `realloc` paths for migrating existing accounts.
- Migration instructions (`migrations/*.ts` via `anchor run migrate`, or on-chain migrate handlers keyed by authority) must themselves be audited, because they are privileged code that touches every account.
- Deterministically rebuild both versions (`solana-verify build` at old and new commits) and diff the source; confirm the on-chain hash actually changed to the reviewed build.

## Supply chain

- Rust dependencies: keep `Cargo.lock` committed and run `cargo audit` and `cargo deny check` in CI. Solana-relevant advisory: **RUSTSEC-2022-0093 / CVE-2022-50237**, where `ed25519-dalek` 1.x does malleable, non-strict verification (including the batch path); pin ≥ 2.0 wherever the program verifies Ed25519 signatures. Also track `curve25519-dalek`, `solana-sdk`, `anchor-lang`, and AMM/oracle crates.
- Toolchain pins: pin `rust-toolchain.toml`, the `solana`/Agave version, and the `anchor` (avm) version, and build in CI with the same pinned versions that produce the deployable artifact (`solana-verify build` in CI so the CI binary is the mainnet binary).
- CI actions: pin third-party actions by full commit SHA and set minimal `GITHUB_TOKEN` permissions. The tj-actions/changed-files compromise (CVE-2025-30066, Mar 2025) retagged every version to a commit that dumped runner memory, including secrets, into public logs across 23k+ repos.
- Front-end and signing supply chain: Bybit's $1.4–1.5B loss came from a compromised Safe{Wallet} build that showed signers a benign UI while the payload swapped the proxy implementation. Solana analogues are wallet-adapter code, transaction-building libs, and anything that renders what a human signer sees. Enforce integrity with SRI/CSP, vendored deps, and on-device verification of transaction contents.

## Post-deploy hygiene

- **security.txt** ([neodyme-labs/solana-security-txt](https://github.com/neodyme-labs/solana-security-txt)) embeds an RFC-9116-style contact and policy in the deployed binary via the `security_txt!` macro, readable with `query-security-txt` and by explorers. Required fields: name, project_url, contacts, policy. Ship it with the `auditors` field filled.
- Bug bounty: register on Immunefi (or equivalent) once audits are done.
- Token authorities: audit every mint the protocol touches, including retained mint authority after distribution (infinite-mint risk), freeze authority holders, and Token-2022 extensions, especially the permanent delegate (see `solana-vulnerabilities.md` E4).

## Monitoring and detection

- Helius webhooks (raw or enhanced/parsed) for program events and balance changes; wire them to PagerDuty or Discord.
- **Yellowstone gRPC** ([rpcpool/yellowstone-grpc](https://github.com/rpcpool/yellowstone-grpc)) account and transaction subscriptions: watch the program's ProgramData account (upgrade authority field) and any `SetUpgradeAuthority` or upgrade instructions touching your program ID, because authority movement is the loudest alarm in this ecosystem and almost nothing fires it by default.
- Explorer state (verified badge, authority history) via Solana Explorer, Solscan, and SolanaFM for user-facing assurance.
- In-program circuit breakers cover halt flags, per-oracle deviation and staleness breakers, and per-market limits. Drift 2026 had breaker-style machinery and none fired in time; design breakers to trip on the *economic* signals (collateral whitelist changes, limit raises) as well as price moves.

## Incident response playbook (what teams actually did)

1. Pause operations with in-program halt flags (Loopscale paused markets via protocol flags; Wormhole guardians halted minting).
2. Emergency upgrade through the multisig. This is the legitimate reason to keep a fast path; pre-approve a pause-proposal template so it exists before it is needed.
3. Contain the movement. An SPL freeze authority freezes specific token *accounts* (halts transfers; it cannot confiscate, and the permanent delegate is the confiscation tool, if it was designed in). Note: Sui validators voted to freeze $162M of Cetus funds in 2025, but Solana has no such precedent; do not plan on validator intervention.
4. Negotiate with the attacker. On-chain bounty messages work (Wormhole's $10M offer; Loopscale's 90% deal, where the attacker returned 100%; Crema's negotiated partial return).
5. Backstop or reimburse. Jump Crypto covered Wormhole's $325M within days; DAO votes and insurance funds cover losses elsewhere.
6. Trace and engage. Use TRM/Chainalysis-style tracing and law enforcement; bridging out to Ethereum is the point of no return for recovery.

Every one of these steps depends on preparation done before the incident: pause paths coded and tested, multisig quorum reachable, contacts in `security.txt`, RPC/webhook monitoring live. The audit report should state which of these exist and which are missing.
