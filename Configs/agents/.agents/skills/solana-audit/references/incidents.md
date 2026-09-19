# Incident history: Solana and the wider ecosystem

The compressed record of real protocol failures. Use it two ways: as a checklist (does this codebase repeat any root cause below?) and as a source of citations for findings ("this is the Cashio pattern"). Sources: [rekt.news](https://rekt.news) leaderboards, OtterSec/Neodyme writeups, Ackee's [2022 Solana Hacks Explained](https://ackee.xyz/blog/category/hacks/) series, official post-mortems.

Amounts vary between trackers with asset prices; figures below are the commonly cited ones.

## Solana incidents

| Incident | Date | Loss | Root-cause class |
| --- | --- | --- | --- |
| Wormhole | Feb 2022 | ~$325M | Code: spoofed guardian signature set (sysvar/precompile-adjacent validation) |
| Cashio | Mar 2022 | ~$50M | Code: fake collateral, accounts validated against other user-supplied accounts |
| Crema | Jul 2022 | $8.8M (~$5.7M returned) | Code: fake tick array account, provenance unverified |
| Nirvana | Jul 2022 | $3.5M | Economics: in-transaction price manipulation of mint/redeem |
| Slope wallet | Aug 2022 | ~$4–8M (9,000+ wallets) | Operations: seed phrases logged to a centralized Sentry server |
| Solend (isolated pools) | Nov 2022 | $1.26M bad debt | Economics: Saber pool pumped + write-locked so the oracle carried the fake price into the next slot |
| Mango Markets | Oct 2022 | ~$114M | Economics: thin MNGO market pumped; oracle mark inflated collateral; treasury borrowed against fictitious value |
| OptiFi | Aug 2022 | $661k locked forever | Operations: developer ran `solana program close` on mainnet during an update |
| Pump.fun | May 2024 | ~$1.9M | Operations: ex-employee retained withdrawal authority over bonding curves |
| Drift | Nov 2024 | ~$5.5M (reported) | Code/economics: deprecated borrow-lend logic allowed effectively uncollateralized, zero-interest borrows (secondary sources; primary post-mortem not public) |
| Loopscale | Apr 2025 | $5.8M (fully recovered) | Economics: RateX Pendle-PT collateral valuation flaw → over-borrowing |
| Drift | Apr 2026 | ~$285M | Operations: social engineering + durable-nonce pre-signed multisig transactions whitelisted a fake collateral token and raised limits; 2/5 council, zero timelock, no breaker fired |

Network-level, security-relevant context: bot-flood outages (Sep 2021 Candy Machine mint bots, a 17h halt; further outages Jan/Apr 2022, Feb 2023, Feb 2024; severe congestion Aug 2024 and Mar 2025) mean programs must tolerate stalled finality, stale oracles, and replayed in-flight transactions. The Oct 2022 "Dragonberry" confidential runtime patch shows validator-coordinated emergency response exists but is not programmable. FTX's collapse (Nov 2022) froze Serum's upgrade authority. That was centralization, not code. Also note common misattributions: Vee Finance was Avalanche, Tinyman was Algorand, and 2023 was quiet on Solana program exploits.

### Root-cause narratives to know cold

**Wormhole: the validation bypass.** The bridge's deprecated `verify_signatures` path trusted a signature-set account whose provenance was not properly verified (an instructions-sysvar-adjacent check discrepancy); the attacker prepared crafted accounts hours ahead, then minted 120,000 wETH on Solana with no Ethereum-side deposit and bridged most of it out. A patch existed but was not deployed to the live program. Jump Crypto backstopped the full loss within days; a $10M on-chain bounty message to the attacker went unaccepted. Lessons: privileged verification paths must be removed as dead code, not deprecated. Deployment lag is an exploit window, and audit findings that ship late are worth nothing. ([rekt](https://rekt.news/wormhole-rekt/), Wormhole post-mortem)

**Cashio: the circular trust.** Collateral validation compared attacker-supplied accounts against each other instead of binding to canonical Saber LP state; the attacker minted 2B CASH against fake collateral. Lesson: never validate user accounts against other user accounts; anchor every value to canonical on-chain state (mints, program ownership, PDA derivation). ([rekt](https://rekt.news/cashio-rekt/))

**Mango Markets: the economics of collateral.** Avi Eisenberg opened offsetting MNGO perp positions, pumped the thin MNGO spot/perp market ~5x so the Pyth-fed mark inflated his collateral and unrealized PnL, then borrowed every real asset in the treasury. There was no code bug. The protocol accepted unacceptable collateral, had no price-deviation circuit breaker, and counted unrealized PnL toward borrowing power. Convicted of fraud in 2024; convictions vacated on venue grounds May 2025 (government appealing). Lessons: collateral quality is a security property, and choosing which assets the protocol will price is an oracle design decision. ([Solidus Labs analysis](https://www.soliduslabs.com), DOJ/SEC filings)

**Solend: the oracle sandwich.** Attacker pumped USDH on Saber with ~100k USDC and write-locked the pool account so same-slot arbitrage couldn't revert the price; the Switchboard feed (reading the pool) carried the inflated price into the next slot, and the attacker borrowed against it. A prior attempt failed because arbitrage reverted in-slot. Lesson: oracles that read manipulable pools assume in-slot arbitrage; attackers can break that assumption with account locks. (Ackee writeup)

**Drift, April 2026: the signing ceremony.** Largest Solana loss on record, and there was no code bug: a ~6-month social-engineering campaign (DPRK-attributed) culminated in Security Council multisig members pre-signing durable-nonce transactions (indefinitely valid) during a rushed migration to a 2/5 council with no timelock; the pre-signed transactions whitelisted a wash-traded fake collateral token ("CVT") and raised withdrawal limits, draining ~$285M across 31 transactions in minutes. Lessons: durable-nonce pre-signatures are standing key compromise. The controls are a multisig threshold, a timelock, and simulation before signing, and collateral whitelisting is an oracle-adjacent trust decision. ([TRM Labs](https://www.trmlabs.com), [Chainalysis](https://www.chainalysis.com))

**Slope: the off-chain key hole.** The mobile wallet logged plaintext mnemonics to a centralized Sentry server; investigators found ~5,400 keys in the database and ~9,000 wallets were drained. Lesson: audit scope includes everything that touches key material, including telemetry, logs, and support tooling. ([Solana incident update](https://solana.com/news/8-2-2022-application-wallet-incident))

**Pump.fun: the offboarding gap.** A former employee used retained privileged access (withdrawal authority) to drain ~$1.9M. Lesson: authority revocation is part of employee offboarding; withdrawal paths belong behind multisig. (The Defiant / Cointelegraph coverage, May 2024)

## Cross-ecosystem incidents worth citing

| Incident | Date | Loss | Class / lesson |
| --- | --- | --- | --- |
| The DAO | Jun 2016 | ~$60M (3.6M ETH) | Reentrancy; ETH/ETC hard fork |
| Parity multisig #1 | Jul 2017 | ~153k ETH | Unauthenticated "constructor" (init race) + signature replay to multisig threshold |
| Parity multisig #2 | Nov 2017 | 513k ETH frozen | `kill()` on uninitialized library (delegatecall/storage risk); permanent |
| BEC token | Apr 2018 | Unknown | batchOverflow (integer overflow mint) |
| bZx | Feb 2020 | ~$1M | First flash-loan oracle manipulations |
| Poly Network | Aug 2021 | $611M | Cross-chain manager tricked into rotating keeper keys; funds returned |
| BadgerDAO | Nov 2021 | ~$120M | Compromised Cloudflare token injected malicious front-end script |
| Beanstalk | Apr 2022 | $182M | Flash-loan governance capture; self-executing proposal |
| Ronin Bridge | Mar 2022 | $624M | 5-of-9 validator keys stolen via fake-job-applied malware; no code bug |
| Harmony Horizon | Jun 2022 | $100M | 2-of-5 multisig compromise |
| Nomad | Aug 2022 | $190M | Upgrade set zero-hash as trusted root; copy-paste exploit for anyone |
| BNB Bridge | Oct 2022 | ~$586M (2M BNB minted) | Forged IAVL Merkle proof |
| dForce | Feb 2023 | ~$3.65M | Read-only reentrancy on Curve `get_virtual_price` |
| Euler Finance | Mar 2023 | $197M (returned) | New `donateToReserves()` path skipped the health check; flash-loan self-liquidation |
| Curve / Vyper | Jul 2023 | ~$69M | Compiler bug (Vyper 0.2.15/16, 0.3.0) broke reentrancy locks; newly-deployed pools |
| Multichain | Jul 2023 | $126M | MPC keys under sole-CEO control; "unauthorized access", CEO detained |
| Bybit | Feb 2025 | ~$1.4–1.5B | Safe{Wallet} front-end supply chain (compromised developer machine, malicious JS, blind Ledger signing); largest theft in history, and the root cause was a signing-UI compromise rather than a contract bug |
| Cetus (Sui) | May 2025 | ~$223M | Integer overflow in shared liquidity math; Sui validators voted to freeze ~$162M (controversial; Solana has no such precedent. Do not plan on one.) |
| tj-actions/changed-files | Mar 2025 | 23k+ repos exposed | CI action retagged to malicious commit dumping runner memory (CVE-2025-30066); pin actions by SHA |

Human-factors pattern to flag in any ops review: Ronin (fake job application malware), Bybit (compromised vendor build chain), Drift 2026 (fake-quant social engineering over months), and the 2024–2026 wave of fake-recruiter "meeting app" malware campaigns (MEETEN/Realst-class infostealers targeting crypto orgs' macOS/Windows machines. See [Cado/Darktrace writeups](https://www.darktrace.com/blog/meeten-malware-a-cross-platform-threat-to-crypto-wallets-on-macos-and-windows) and the [FBI IC3 PSA on Bybit tradecraft](https://www.ic3.gov/PSA/2025/PSA250226)). People with signing power are the attack surface; controls are simulation-before-signing, timelocks, and isolation of signing infrastructure.

## Meta-lessons for audit scoping

1. Immunefi's loss statistics hold on Solana too: compromised keys and operational failures out-rank code bugs ecosystem-wide. A Solana audit that never asks "who holds the upgrade authority and how do they sign" missed the biggest loss class.
2. Audits expire. Wormhole (patch not deployed), Euler (new code path post-audit), and Curve (new compiler version) each lost funds after an audit. Every upgrade re-opens the audit question, and diff review after every change is not optional.
3. "Audited" is not "safe". Mango, Wormhole, Cetus (on Sui), Loopscale, and Drift were all audited protocols. The audit is evidence, not immunity.
4. Deprecation is not removal. Wormhole's dead path was the exploit. Grep for `deprecated`, commented-out guards, and feature-flagged old flows.
5. Oracle losses happen without a code failure. Mango, Nirvana, Solend, and Loopscale all ran code that functioned as written. Model prices as attacker-controlled within any single transaction.
6. Rushing custody changes is its own vulnerability. Drift's 2/5 zero-timelock migration was the precondition for the largest Solana loss ever.
