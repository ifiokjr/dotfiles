# Cross-Ecosystem Smart Contract Security (EVM and general)

Solana did not invent new ways to lose money; it inherited most of them and added an account-shaped twist. This file catalogs the general/EVM vulnerability classes (each with its canonical incident — full narratives in `incidents.md`), maps every class to its Solana analogue, and lists the Solana classes with no EVM equivalent. Use it when the codebase has DeFi economics, bridges, vaults, or governance — the math and the incentives transfer 1:1 even where the runtime differs.

## Standards and classifications to cite

- **OWASP Smart Contract Top 10 (2025)** — [scs.owasp.org](https://scs.owasp.org/): SC01 Access Control; SC02 Price Oracle Manipulation; SC03 Logic Errors; SC04 Lack of Input Validation; SC05 Reentrancy; SC06 Unchecked External Calls; SC07 Flash Loan Attacks; SC08 Integer Overflow/Underflow; SC09 Insecure Randomness; SC10 Denial of Service. (A 2026 refresh is previewed on the site: Business Logic rises to #2; Proxy & Upgradeability and Arithmetic Errors appear.)
- **SWC registry** ([swcregistry.io](https://swcregistry.io/)) — the classic 37-item classification (SWC-100..136): no longer actively maintained; successors are the **EEA EthTrust Security Levels** spec and OWASP **SCSVS**. Still useful as vocabulary: SWC-101 overflow, SWC-105 unprotected withdrawal, SWC-107 reentrancy, SWC-112 delegatecall to untrusted callee, SWC-115 `tx.origin` authorization, SWC-116 timestamp dependence, SWC-117/121 signature malleability/replay, SWC-120 weak randomness.
- **Immunefi loss statistics** ("Ecosystem Vulnerability Scoreboard") — across years of DeFi losses the dominant vectors are, in order: **compromised private keys/MPC infrastructure**, **smart-contract logic vulnerabilities**, **oracle/validation weaknesses**. Key compromise has out-paced code bugs ecosystem-wide — the operations layer (`release-security.md`) is not optional scope.

## EVM vulnerability classes with canonical incidents

Each entry: mechanism → canonical incident → Solana note.

1. **Reentrancy.** External call hands control to attacker code before state updates complete; the classic checks-effects-interactions violation. *The DAO, June 2016, ~3.6M ETH (~$60M), forced the ETH/ETC hard fork.* Solana: structurally mitigated (runtime locks writable accounts across the instruction tree) — the live analogue is post-CPI state assumptions and single-transaction manipulation (`solana-vulnerabilities.md` C3/G1).
2. **Read-only reentrancy.** A view function used as an oracle is read mid-mutation during a callback; the reading protocol mis-prices collateral even though its own contracts are untouched. *dForce, Feb 2023, ~$3.65M, via Curve `get_virtual_price`.* Solana: any state read after an attacker-influenced CPI; re-read health after CPIs.
3. **Access control failure.** Privileged functions unprotected, or privilege protected only by weak key custody. *Parity multisig, July 2017, ~153k ETH: the "constructor" (`initWallet`) was publicly callable; Ronin, Mar 2022, $624M: 5-of-9 validator keys socially engineered — no code bug at all.* Solana: missing `is_signer` checks and authority custody (`release-security.md`).
4. **Integer overflow/underflow.** Pre-Solidity-0.8 `uint256` wraps silently. *BEC token, Apr 2018, `batchTransfer` overflow minted 57.8B tokens (PeckShield's batchOverflow).* Solana: identical class — release Rust wraps unless `overflow-checks = true` (Cetus on Sui, $223M, May 2025, is this class in Move).
5. **Oracle/price manipulation with flash loans.** Spot prices from thin pools used as truth, moved capital-free within a transaction. *bZx, Feb 2020 (first flash-loan exploits); Euler, Mar 2023, $197M — `donateToReserves()` skipped the health check that transfers enforced.* Solana: Mango ($114M), Nirvana, Solend, Loopscale — see G1 in `solana-vulnerabilities.md`.
6. **Bridge/cross-chain verification failure.** Forged validator signatures/consensus proofs mint unbacked assets. *Poly Network 2021, $611M (cross-chain manager tricked into replacing keeper keys); Nomad 2022, $190M (zero hash trusted as a valid message root — copy-paste exploit); BNB Bridge 2022, $586M (forged IAVL Merkle proof); Harmony 2022, $100M (2-of-5 multisig compromised); Multichain 2023, $126M (MPC keys under one CEO's control); Wormhole 2022, $325M (Solana side — spoofed signature set).* Solana: Wormhole is the native case; any program verifying external signatures (guardian sets, precompiles) owns this class.
7. **delegatecall / storage collision.** Library code executing in the caller's storage context; upgrades shifting slots corrupt live state. *Parity, Nov 2017: `kill()` on an uninitialized library froze ~513k ETH permanently.* Solana: the upgrade-authority + account-layout analogue — Borsh offsets shift when structs change across upgrades (`release-security.md`).
8. **Uninitialized proxy / constructor race.** `initialize()` left unguarded on a deployed proxy; first caller takes ownership. Solana: the deploy-then-`initialize` gap and re-init (A4/H1).
9. **ERC-4626 vault inflation / round-trip.** First-depositor donation inflates the share ratio; later depositors round to zero. Solana: identical math on vault share code (G4) — direct SPL transfers to the vault's token account play the donation.
10. **Precision/rounding loss.** Truncation and mul/div ordering leak value; round-trips amplify it. Solana: D2.
11. **Signature replay/malleability.** Signatures not bound to nonce/chainid/contract replay across chains or within a transaction set; ECDSA `(s,v)` flips produce a second valid signature. *The July 2017 Parity theft reused the same owner signature multiple times to reach the multisig threshold.* Solana: any Ed25519/secp256k1 verification in-program (note `ed25519-dalek` 1.x malleability, RUSTSEC-2022-0093 — pin ≥ 2.0) and instruction-introspection flows.
12. **Weak on-chain randomness.** `blockhash`/`block.timestamp` observable by validators and conditional-transaction bots. *Meebits mint, May 2021 — attacker submitted only mint transactions whose blockhash yielded rare NFTs.* Solana: identical class — slot hashes (`solana-vulnerabilities.md` I); use commit-reveal or VRF.
13. **Front-running/MEV/sandwich.** Public mempool exposes intents; attackers reorder/insert transactions. Solana: no public mempool, but Jito bundles restore sandwiching (J).
14. **Flash-loan governance capture.** Token-weighted voting executable immediately is borrowable. *Beanstalk, Apr 2022, $182M — flash-borrowed ~$1B of LP, passed the malicious proposal, self-executed.* Solana: Realms DAOs with short/no delays have the same exposure; timelock governance actions.
15. **Approval scams / phishing / rugs.** Standing transfer approvals harvested by drainer kits; insider liquidity pulls. Solana: smaller surface (no infinite approvals) but the same signature-phishing economics; rug tokens on Solana typically retain freeze/mint authority (E4).
16. **Admin key / centralization risk.** Upgrade authority, pausers, bridge signers behind one key or a thin multisig collapse every on-chain guarantee. *Ronin, Harmony, Multichain above; FTX/Serum on Solana (upgrade authority centralization).* The standard control set: multisig + timelock + documented rotation; on Solana see Squads (`release-security.md`).
17. **Compiler/toolchain bugs.** *Curve/Vyper, Jul 2023, ~$69M — a Vyper bytecode bug (broken reentrancy locks from storage-slot misalignment; affected 0.2.15/0.2.16/0.3.0, fixed by 0.3.1 — frequently misreported as "0.3.7").* Solana: pinned toolchains are a security control — pin `solana`/Agave, `anchor` (avm), and Rust versions; deterministic builds via `solana-verify`.
18. **Stablecoin depeg as systemic risk.** *Terra UST, May 2022 (~$40B); USDC/SVB, Mar 2023.* Solana: audit what happens to solvency, liquidations, and oracles under a collateral depeg; it is a scenario test, not a hypothetical.
19. **DoS / griefing.** Unbounded loops, external-call reverts, block-gas exhaustion. Solana: compute-budget exhaustion (CU limits) and oversized-transaction design bugs; OtterSec's severity rubric explicitly counts "computational limit exhaustion" (Phoenix DoS finding).
20. **Unchecked external call results.** SWC-104 class. Solana: ignored CPI errors / `ProgramError` swallowing; the Phoenix SDK finding (parsing failed transactions as success) is this class off-chain.

## EVM → Solana mapping table

| EVM mechanism | Solana analogue | What differs |
| --- | --- | --- |
| `msg.sender` / `tx.origin` / modifiers | `AccountInfo.is_signer`, Anchor `Signer`/`has_one` | The program must ask; the runtime does not volunteer. Missing signer checks ≈ missing `onlyOwner` |
| Contract storage | Accounts passed by the client | Everything is attacker-choosable: owner, type, role, uniqueness must be program-checked |
| CREATE/CREATE2 addresses | PDA derivation (`find_program_address`) | New failure modes: seed collisions, non-canonical bumps, PDA sharing |
| Proxy + upgrade admin | Program upgrade authority on ProgramData | Upgrade swaps code, state persists → account-layout (Borsh/discriminator) migration bugs replace storage-collision bugs |
| Constructor race / uninitialized proxy | Deploy-then-`initialize` gap; re-init | Same class; Anchor's discriminator `init` mitigates when used |
| Arbitrary external call | CPI to an unverified program id | Privilege escalation: caller's PDA signature + writable grants persist into the callee |
| Gas / gas griefing | Compute budget (200k CU default; ~1.4M requestable), tx size limit | CU exhaustion and 1,232-byte tx limits are the griefing surfaces |
| Reentrancy | Structurally mitigated (writable-account locks) | Residual: post-CPI state assumptions; single-tx manipulation is the real analogue |
| ERC-20 approvals | SPL delegate (one per token account), Token-2022 | Phishing surface smaller; permanent delegate is sharper than any EVM approval |
| ERC-4626 share math | Vault share math | Identical math and identical first-depositor attack |
| Flash loans | No primitive needed — atomic multi-instruction tx | Any transaction is a flash loan; threat-model intrablock prices always |
| Public mempool MEV | Leader/relay ordering, Jito bundles | Sandwiching exists; priority fees replace gas auctions |
| Etherscan verification | `solana-verify` / otter-verify registry | Not native, not tamper-proof — see `release-security.md` |
| Multisig (Safe) | Squads | Squads timelocks exist but are optional — Drift 2026 ran 2/5 with zero timelock |

## Solana classes with no real EVM analogue

- Account substitution/type cosplay (A2/A3) — EVM's `msg.sender`-scoped storage has no equivalent failure.
- Sysvar substitution (A6) — "passing a fake `block.timestamp` as an account".
- Close-account revival (F1) — no EVM parallel to reviving a zeroed account by re-funding it.
- Durable-nonce pre-signing (K) — an EVM signature is also replayable within its nonce regime, but Solana durable nonces make pre-signed transactions *indefinitely live credentials*, which is how Drift lost $285M without a code bug.
- PDA canonical bump (B2) and duplicate-account aliasing (A5) — runtime-account-model specific.
- Rent-exemption garbage collection (F3) — storage is rented; under-funded accounts disappear.

## How to use this file in a Solana audit

1. Take the protocol's mechanics (vault? lending? AMM? bridge? governance?) and pull the matching EVM classes above — their exploit playbooks translate directly.
2. For each, run the Solana-side detection heuristic from `solana-vulnerabilities.md`.
3. Cite the canonical incident in the finding (see `incidents.md` for details and links) — "this is the Euler `donate` pattern on a Solana vault" communicates more than a paragraph of abstract risk.
