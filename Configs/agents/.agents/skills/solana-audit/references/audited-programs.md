# Audited Solana programs, firms, and engagement types

Where to find real audit reports and comparable audited code. Links verified September 2026, but repos in this ecosystem churn (several major programs have gone closed-source; noted below), so re-verify before citing.

## Where audits live

- In-repo `audits/`, `audit/`, `.audits/`, or `security_audits/` folders are the dominant convention (Mango v4, OpenBook, Phoenix, Orca, Wormhole, Squads, Kamino, Jupiter, Jito restaking, Light, Pyth).
- Dedicated audit repos for orgs with many products: [Kamino-Finance/audits](https://github.com/Kamino-Finance/audits), [MeteoraAg/audits](https://github.com/MeteoraAg/audits), [jup-ag/docs `static/files/audits`](https://github.com/jup-ag/docs/tree/main/static/files/audits), [pyth-network/audit-reports](https://github.com/pyth-network/audit-reports).
- Firm sites: [osec.io/audits](https://osec.io/audits) (OtterSec), [Zellic publications](https://github.com/Zellic/publications).
- Anza's canonical archive for SPL/core: [anza-xyz/security-audits](https://github.com/anza-xyz/security-audits) (50+ PDFs: Token-2022, stake pool, runtime series).

## Major open-source programs with public audits

| Program | What it is | Repo | Audits (firm, year) |
| --- | --- | --- | --- |
| Squads V4 (multisig) | On-chain multisig | [Squads-Protocol/v4](https://github.com/Squads-Protocol/v4) | OtterSec 2022/2024, Neodyme 2024, Certora (audit + formal verification) 2023–2024, Trail of Bits; audited commit recorded in README |
| Mango v4 | Perpetuals DEX | [blockworks-foundation/mango-v4](https://github.com/blockworks-foundation/mango-v4) | OtterSec per-version (v0.17.0 → v0.23.0+), Sherlock contest 2022 |
| Mango v3 | Spot/margin (exploited Oct 2022) | [blockworks-foundation/mango-v3](https://github.com/blockworks-foundation/mango-v3) | Neodyme May 2022 (in repo root) |
| OpenBook v2 | CLOB (Serum successor) | [openbook-dex/openbook-v2](https://github.com/openbook-dex/openbook-v2) | OtterSec 2023 |
| Phoenix | Spot CLOB | [Ellipsis-Labs/phoenix-v1](https://github.com/Ellipsis-Labs/phoenix-v1) | OtterSec, OShield (ex-MadShield) |
| Orca Whirlpools | CLMM AMM | [orca-so/whirlpools](https://github.com/orca-so/whirlpools) | Kudelski 2022, Neodyme 2022, Sec3 2024–2026 (incl. PR-scoped) |
| Wormhole | Cross-chain bridge | [wormhole-foundation/wormhole](https://github.com/wormhole-foundation/wormhole) | Neodyme 2022, Kudelski 2022, Trail of Bits 2022–2023, OtterSec 2025, Zellic, CertiK, Runtime Verification, Coinspect |
| Kamino (klend etc.) | Lending/liquidity | [Kamino-Finance/klend](https://github.com/Kamino-Finance/klend) + [audits repo](https://github.com/Kamino-Finance/audits) (40+ PDFs) | OtterSec (version-differential), Sec3, Ackee (+ dedicated fuzz report), Certora (multiple FV), Offside Labs, Runtime Verification |
| Jupiter (Lend/Perps/Swap...) | On-chain programs of the aggregator | [jup-ag/docs audits hub](https://github.com/jup-ag/docs/tree/main/static/files/audits) (26 PDFs) | Offside Labs, OtterSec, Sec3, Certora, Code4rena (Lend contest 2026), MixBytes, Zenith, Neodyme, Cantina |
| Meteora (DLMM/DAMM) | AMMs | [MeteoraAg/audits](https://github.com/MeteoraAg/audits); DAMM v2 source [MeteoraAg/damm-v2](https://github.com/MeteoraAg/damm-v2) | OtterSec, Offside Labs, Sec3, Sherlock (contest), Zenith |
| Jito (restaking) | Restaking vaults/VRTs | [jito-foundation/restaking](https://github.com/jito-foundation/restaking) | OtterSec, Offside Labs, Certora; `jito-solana` validator client: Neodyme, Halborn, OtterSec per-release |
| Marinade | Liquid staking | [marinade-finance/liquid-staking-program](https://github.com/marinade-finance/liquid-staking-program) (audits on [docs site](https://docs.marinade.finance/marinade-protocol/security/audits.md)) | Kudelski 2021, Ackee 2021, Neodyme 2021/2023/2024/2026, Sec3 2023 |
| Light Protocol | zk compression | [Lightprotocol/light-protocol](https://github.com/Lightprotocol/light-protocol) | Neodyme 2024, Accretion 2025, Hashcloak 2025, Certora 2025–2026 |
| Metaplex (token-metadata, Core, Bubblegum...) | NFT standards | [metaplex-foundation](https://github.com/metaplex-foundation) ([security page](https://metaplex.com/docs/security)) | Sec3, Accretion, OtterSec (ongoing partners; per-program dates on the security page) |
| SPL / Token-2022 / core (Anza) | System programs | [anza-xyz/security-audits](https://github.com/anza-xyz/security-audits) | Kudelski 2020, Halborn, OtterSec, Zellic, NCC Group, Trail of Bits, Certora FV, Least Authority, ZK Security; Code4rena × Solana Foundation contest 2025 |
| Pyth | Oracle | [pyth-network/audit-reports](https://github.com/pyth-network/audit-reports) | Zellic, OtterSec, CertiK |
| Sanctum router "S" | Liquid staking router | [igneous-labs/S](https://github.com/igneous-labs/S) | OtterSec 2024 |
| Solend | Lending | [solendprotocol/solana-program-library](https://github.com/solendprotocol/solana-program-library) | Kudelski 2021 (in-repo) |
| Anchor framework | Program framework | [otter-sec/anchor](https://github.com/otter-sec/anchor) (coral-xyz redirects here; OtterSec maintains it) | No comprehensive public audit located, so treat the framework itself as trusted-but-not-audited infrastructure |

Gone closed-source or unwound (audits remain public via the firms): Drift v2 (`drift-labs/drift-v2` is 404; Zellic and Trail of Bits reports public, OtterSec listings on osec.io), Tensor (OtterSec/Neodyme reports), Zeta v1, Raydium AMM v4 (OtterSec reports), Jet, Larix, Friktion. Serum DEX v3 is archived with no public audit PDF ever located, though one is often claimed and never verified. Pump.fun and Lifinity are closed-source.

## Solana audit firms

- **OtterSec** ([osec.io](https://osec.io)) is the dominant Solana-native firm. It investigated Wormhole, Cashio, Mango, and Slope, and it maintains Anchor. Report index at osec.io/audits.
- **Neodyme** ([neodyme.io](https://neodyme.io)) is Solana-native. It audited Wormhole 2022 (and flagged the signature-verification critical weeks before the exploit), Squads, Light, and the Jito client, wrote security.txt, and runs the best public Solana security blog.
- **Zellic** ([zellic.io](https://zellic.io), [publications repo](https://github.com/Zellic/publications)) audited Drift, the Pyth suite, Wormhole, the LayerZero Solana endpoint, and SPL.
- **Halborn** ([halborn.com](https://halborn.com)) audited the Jito validator client, the Solana runtime series, and SPL.
- **Trail of Bits** ([trailofbits.com](https://www.trailofbits.com)) audited Wormhole, Drift, Squads, and SPL Token-2022, and also maintains Solana lints (crytic/solana-lints).
- **Kudelski Security** ([kudelskisecurity.com](https://kudelskisecurity.com)) did early Solana work on SPL Token 2020, Marinade, Solend, Orca, and the Wormhole node.
- **Sec3** ([sec3.dev](https://www.sec3.dev), ex-Soteria) audited Kamino, Marinade, Meteora, and Jupiter, reviewed Orca PRs, and builds the X-Ray static analyzer.
- **Ackee Blockchain** ([ackeeblockchain.com](https://ackeeblockchain.com)) audited Kamino (including the fuzzing report) and Marinade, builds the Trident fuzzing tooling, and runs the Solana auditors bootcamp.
- **Certora** ([certora.com](https://www.certora.com)) does formal verification on Solana (CVLR for Rust) for Kamino, Jupiter Lend, Squads, Jito, and SPL.
- **Offside Labs** is the de-facto retainer auditor for Meteora, Jupiter, and Jito, with dozens of per-version reports in those audit repos.
- **Accretion** ([accretion.fi](https://accretion.fi)) audited Light and zk compression, partners with Metaplex, and published the "verified builds can be spoofed" research.
- Contest platforms: Sherlock, Code4rena, Cantina, and Immunefi audit competitions have all run Solana scopes.
- Others appearing in verified audit folders: Runtime Verification, CertiK, NCC Group, Least Authority, Quantstamp, SlowMist (incident response), Zenith, MixBytes, OShield/MadShield, Hashcloak, Qedit, ZK Security, Coinspect, Fuzzing Labs, Decurity.

## Kinds of engagements

- Full-scope audit. A time-boxed review of the whole program at a pinned commit, before mainnet or a major upgrade. Output: a findings report with severity counts.
- Targeted review. One component or risk area, such as Offside Labs' "Lend Oracle and Flashloan" report for Jupiter. Appropriate for new modules on a mature codebase.
- Fix review / re-audit / version-differential. A re-review of diffs between versions (Kamino's per-version OtterSec series; Squads' `_final` PDFs; Orca's PR-scoped Sec3 reports). Required after every material change. Euler and Curve shipped their losses in new paths.
- Audit contest (competitive). Paid crowd review (Sherlock, Code4rena, Cantina, Immunefi competitions). Complements, and does not replace, a private audit on high-TVL code.
- Bug bounty. Ongoing paid disclosure, usually on Immunefi. A program with audits but no bounty is missing its cheapest defense.
- Continuous/retainer auditing. The firm reviews each release (Offside Labs for Meteora/Jupiter; OtterSec per Jito release; Metaplex's PR-gated model). This is the 2024+ norm for fast-shipping Solana teams.
- Fuzzing / invariant campaign. Targeted automated testing (Ackee's Kamino fuzz report; Pyth shipped an AFL harness inside its audit repo).
- Formal verification. Machine-checked invariants (Certora on vaults/multisig/token logic; Kani case studies by OtterSec). Best for small, security-critical cores.
- Infra / pentest. Validators, keepers, APIs, and front-ends (Halborn/Neodyme on jito-solana; Tensor's off-chain audit; Neodyme's operational-security review for Jupiter).
- Incident response / forensics. Post-exploit investigation and remediation verification (OtterSec/Neodyme frequently).

## How to use this list during an audit

1. Find the comparables. Auditing a CLMM? Read Orca's `.audits/` and Meteora's DLMM reports first, because your codebase's bug classes are in there. Lending? Kamino/Solend reports. CLOB? OpenBook/Phoenix. Multisig? Squads plus its Certora FV specs.
2. Check the target's own audit trail. If the protocol has prior audits, diff the audited commit against HEAD and review the delta as a minimum. If it has none, that fact leads the report.
3. Calibrate severity against precedent. "Orca had this exact class as a Medium in 2022" is stronger than an abstract argument.
