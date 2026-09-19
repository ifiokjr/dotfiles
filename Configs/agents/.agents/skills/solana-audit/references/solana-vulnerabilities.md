# Solana Vulnerability Taxonomy

The canonical enumeration of Solana-native attack classes is [sealevel-attacks](https://github.com/coral-xyz/sealevel-attacks) (originally by paulx, now under coral-xyz): `0-signer-authorization`, `1-account-data-matching`, `2-owner-checks`, `3-type-cosplay`, `4-initialization`, `5-arbitrary-cpi`, `6-duplicate-mutable-accounts`, `7-bump-seed-canonicalization`, `8-pda-sharing`, `9-closing-accounts`, `10-sysvar-address-checking`. Anchor rehosts it under References → Sealevel Attacks plus a "Footguns" section ([anchor-lang.com](https://www.anchor-lang.com/)). This file extends that list with everything the incident record says matters.

Each class below has: mechanism, exploit, detection, fix, and the historical incident that proves it is real. Read every entry against every entry point; do not sample.

## A. Account validation

The runtime enforces only what the program checks about the accounts the client supplied. This single fact explains Wormhole, Cashio, and Crema.

### A1. Missing signer check (`is_signer`)

- **Mechanism:** the runtime does not require an account to be a signer unless the program checks `account.is_signer` before treating it as an authority.
- **Exploit:** submit the instruction with the authority's pubkey as an unsigned account; the program performs the privileged action for the attacker.
- **Detect:** every use of an `authority`/`admin`/`owner` account not preceded by a signer check. Anchor: `Signer<'info, T>` or `#[account(signer)]`; native: `if !authority.is_signer { return Err(...) }`.
- **Fix:** require the signer and require it matches the stored authority (`has_one = authority` / explicit compare).
- **Evidence:** Kamino (OtterSec, High OS-KAMI-ADV-02, failure to gate a farm-admin update); the access-control Criticals in Mango v4 OtterSec 0.17.0 (`audits/Audit_OtterSec_Mango_v0.17.0.pdf`).

### A2. Missing account ownership check

- **Mechanism:** deserialization does not verify `account.owner`. Any account with a matching discriminator/layout deserializes "successfully" — including ones the attacker created through their own program.
- **Exploit:** pass an attacker-crafted account shaped like a vault/config/state account; the program trusts its contents.
- **Detect:** raw `AccountInfo`, `UncheckedAccount`, `next_account_info` + `.data.borrow()` without an `owner == program_id` (or expected program) check. Anchor's `Account<'info, T>` enforces ownership automatically — raw types do not.
- **Fix:** explicit owner checks in native code; Anchor typed accounts everywhere.
- **Evidence:** Solend (Kudelski 2021, High KS-SOLEND-F-00: reserve account owner never checked); Trail of Bits on Wormhole 2022-09: "No general protection against type cosplay in the bridge".

### A3. Account substitution / type cosplay / role confusion

- **Mechanism:** even with correct ownership, the program must bind each account to its *role* — the vault derived from this caller, the mint this pool holds, the market this order belongs to. A *different valid account of the same type* satisfies a discriminator-only check.
- **Exploit:** pass your own vault, a look-alike mint, another pool's state; balances, authorities, or prices resolve in the attacker's favor.
- **Detect:** for every `Account<T>` lacking `seeds`/`has_one`/`address`/`constraint`/`token::mint`, ask: could any other account of type `T` be passed here? Cross-check multi-account invariants (the "market_vault matches the order side" class of check).
- **Fix:** Anchor constraints (`has_one`, `address`, `seeds`, `token::mint = x`, `mint::decimals = n`) or explicit re-derivation in native code.
- **Evidence:** OpenBook v2 (OtterSec, Critical OS-OBK-ADV-00: `place_order` never validates that `market_vault` matches the order's side); Cashio ($50M: collateral validated only against other user-supplied accounts); Trail of Bits Wormhole: `AccountMeta::new` used for non-writable accounts.

### A4. Missing `is_initialized` / re-initialization

- **Mechanism:** init instructions that don't refuse to run twice let an attacker re-run them on live accounts and reset `authority`, mint, or totals to attacker values. The sibling risk is type confusion via `try_from_unchecked` (any layout-compatible account deserializes).
- **Detect:** native `unpack`/init paths without an `is_initialized` refusal; Anchor `init` is safe by discriminator; audit any `init_if_needed` (below, H3).
- **Fix:** refuse re-init; wipe discriminators on close; Anchor `init` + owner checks.

### A5. Duplicate / aliased mutable accounts

- **Mechanism:** the same account passed in two argument positions (one expected read-only, one mutable) is de-duplicated by the runtime; logic that assumes two distinct accounts misbehaves — commonly it double-counts or nets to zero what should have been two balances.
- **Detect:** for each instruction, check whether any two accounts of the same type could be the same account; Anchor `#[account(mut)]` on both positions is the smell.
- **Fix:** explicit same-pubkey refusal where distinctness is assumed.

### A6. Sysvar substitution

- **Mechanism:** sysvars (Clock, Rent, SlotHashes, Instructions) are accounts like any other. A fake "Clock" with a future `unix_timestamp` unlocks vesting; a spoofed instructions sysvar defeats secp256k1 precompile verification flows.
- **Detect:** any sysvar account not checked against its well-known address (`Rent::id()`, `Clock::id()`) or not obtained via `Sysvar::from_account_info` (which checks).
- **Fix:** use Anchor `Sysvar<'info, Clock>` / `init_if_needed`-free typed sysvars; native code compares `key() == Sysvar::id()`.
- **Evidence:** the Wormhole mechanism (Feb 2022) — the deprecated `verify_signatures` path trusted a spoofable signature-set account; root-cause class is exactly sealevel-attacks #10.

## B. PDA derivation

### B1. Unverified PDA derivation

- **Mechanism:** the program must re-derive `find_program_address(seeds, program_id)` and compare with the passed account. Accepting a PDA on faith lets an attacker route signing power or funds to a PDA of their choosing.
- **Detect:** every PDA-typed argument must be re-derived in-handler or constrained by Anchor `seeds` (which re-derives). Grep `find_program_address` / `create_program_address` and match call sites to instruction paths.
- **Evidence:** Crema ($8.8M: fake tick array account embedding a legit tick address — provenance never checked).

### B2. Non-canonical bump / bump canonicalization

- **Mechanism:** PDA validity is bump-specific; accepting any valid bump (not the canonical top one) or storing a client-supplied bump breaks derivation guarantees and enables collisions with attacker-derived addresses.
- **Detect:** stored `bump` fields written from instruction arguments; `create_program_address` called with client data without comparing to `find_program_address` result.
- **Fix:** derive canonically (`seeds` + `bump` constraints; Anchor stores the canonical bump in the account on `init`).

### B3. PDA sharing / seed collision

- **Mechanism:** reusing one PDA as authority/vault across domains (or omitting a discriminator like owner/mint/nonce from the seeds) mixes funds or lets two logical entities collide on one address.
- **Detect:** map every PDA the program derives; check seeds include all identifying fields; check the same PDA is not authority for unrelated state.
- **Evidence:** Kamino (Ackee 2026, Low L3 "PDA Squatting"; OtterSec High OS-KAMI-ADV-00 elevation-group mismatch).

## C. Cross-program invocation (CPI)

### C1. Arbitrary CPI / privilege escalation

- **Mechanism:** privileges (signer, writable) granted to accounts persist into the CPI, and the program's PDA signature follows the callee. If the invoked program id is read from an instruction account instead of pinned, the attacker passes their own program — which approves everything and returns.
- **Detect:** grep `invoke`, `invoke_signed`, `CpiContext::new` — the program argument must be a constant (`spl_token::ID`, hard-coded pubkey) or an Anchor `Program<'info, T>` (which checks against `declare_id!`), never a raw `AccountInfo`.
- **Fix:** pin program ids; use Anchor typed `Program` accounts.
- **Evidence:** sealevel-attacks #5; a standard finding class in Sec3 and OtterSec reports.

### C2. Return-data spoofing

- **Mechanism:** `set_return_data`/`get_return_data` is unauthenticated; any program can write return data. Parsing CPI results without checking which program produced them trusts attacker data.
- **Detect:** `get_return_data()` call sites; verify the program-id field is checked before use.

### C3. Post-CPI state assumptions (the read-only-reentrancy analogue)

- **Mechanism:** classic EVM reentrancy is structurally mitigated on Solana (writable accounts are locked across the instruction tree; a program cannot be re-entered with overlapping writable accounts). What remains: state written before a CPI and trusted after it — the callee (attacker-controlled or attacker-influenced) observes or influences intermediate state, or balances read after the CPI reflect attacker actions mid-transaction.
- **Detect:** any `invoke`/`invoke_signed` between a state write and a later read of the same accounts; re-read and re-validate health/balances after every CPI in money paths.
- **Note:** the practical Solana analogue of "reentrancy" is single-transaction flash manipulation (see G) — treat it as the real threat, not callback re-entry.

### C4. Close-and-revive pseudo-reentrancy

Covered in F1 — the ordering trap where an account is closed and its address reused within a flow.

## D. Arithmetic

### D1. Overflow / underflow (release profile!)

- **Mechanism:** Rust release builds **wrap silently** on integer overflow unless `overflow-checks = true` is set in `[profile.release]`. Subtraction past zero yields a huge number — the classic vault drain.
- **Detect:** FIRST check `Cargo.toml` for `overflow-checks = true`. Then grep money math for `-`, `*`, `+` without `checked_*`/`saturating_*` or u128 upcasting.
- **Fix:** enable `overflow-checks = true` (it costs a little compute; that is the price) and use checked math in money paths regardless.
- **Evidence:** Cetus (Sui, May 2025, $223M — u256→u64 downcast in shared liquidity math; the canonical illustration even off-Solana); Orca Whirlpools (Neodyme 2022-05, Medium "Integer Overflow when swapping"); Phoenix (OtterSec OS-EPS-ADV-03 overflows "during normal operation under certain parameter configurations"); Trail of Bits Wormhole: "Inconsistent use of checked math".

### D2. Precision loss and rounding direction

- **Mechanism:** division-before-multiplication, truncation, and unfavorable rounding leak value per operation; round-trip cycles (deposit/withdraw) can amplify dust into real losses.
- **Detect:** audit every `a * b / c` in share/price math: upcast to u128 first, round shares **down** on mint, round assets **up** on withdrawals/fees (favor the protocol), and handle zero-share/zero-asset branches.
- **Evidence:** Solend (Kudelski, High F-01: "Loss of precision causing miscalculation of interest rate"); Kamino (Sec3: "inconsistent collateral_exchange_rate_ceil").

### D3. Decimal and cast mismatches

- **Mechanism:** treating a 6-decimal mint as 9 inflates values 1000×; `as u64`/`as u128`/`as i64` casts truncate; f64 in pricing loses cents that compound.
- **Detect:** grep `as u64`, `as u128`, `as i64`, `f64`, `.pow(`; verify mint decimals flow from the mint account (`mint::decimals`), never from instruction args.

## E. SPL Token and Token-2022

### E1. Fake mint / unbound mint

- **Mechanism:** accepting any mint as the pool's/vault's asset lets the attacker pass a worthless look-alike mint they control.
- **Detect:** token accounts must be bound to the expected mint (`token::mint = some_mint` in Anchor, or explicit compare); the mint itself must be validated as the canonical one (`address =` constraint or config-stored pubkey).
- **Evidence:** Cashio's fake-collateral class; Wormhole-adjacent "Token Bridge – Target not Checked" (Neodyme, High).

### E2. Authority and delegate handling

- **Mechanism:** `transfer` from a source token account without verifying `source.owner == payer` (or the PDA derivation), `approve`/delegate lifecycles left dangling, multisig authorities on mints assumed but never checked.
- **Detect:** every `transfer`, `mint_to`, `burn`, `approve`, `close_account` call site: who is the authority, is it derived/validated, is the delegate cleared after use.

### E3. `transfer` vs `transfer_checked`

- **Mechanism:** plain `transfer` trusts the source mint's decimals implicitly; `transfer_checked` passes decimals explicitly and validates against the mint — required for Token-2022 mints and the safe default everywhere.
- **Detect:** grep `transfer(` in CPI helper usage; require `transfer_checked` unless there is a stated reason.

### E4. Mint / freeze / close authorities and Token-2022 extensions

- **Mechanism:** a live mint authority means infinite mint (USDC-look-alike scams); freeze authority halts transfers; Token-2022 adds sharper tools: **permanent delegate** (can confiscate any account of that mint — an immediate Critical if attacker-reachable), transfer fees (recipient math), default account state (frozen), pausable mints, CPI guard (blocks privileged ops via CPI — good defense for user accounts, bypassed by a permanent delegate).
- **Detect:** for every mint the protocol touches, enumerate authorities and extensions; flag any mint with mint authority retained after distribution, and any permanent delegate that is not the protocol's explicit, documented design.
- **Reference:** [Token-2022 extensions docs](https://www.solana-program.com/docs/token-2022/extensions).

### E5. Wrapped SOL lifecycle

- **Mechanism:** create/close of wSOL accounts inside money paths creates ordering traps (sync before transfer, lamport accounting on close) and griefing windows.
- **Detect:** every wSOL account create/transfer/close sequence; require atomic sync-and-transfer patterns.

## F. Account lifecycle

### F1. Close-account revival

- **Mechanism:** "closed" is a convention (lamports zeroed, data cleared, owner reset) — unless every entry point re-checks, an attacker re-lamports the account (a rent-exempt transfer revives it as a System Program account, or re-init revives program state) and resurrects stale state. The ordering trap: front-run a close with a revive so later funds land on the reused address.
- **Detect:** find every close site; verify (a) close is atomic (lamports out + discriminator wipe in the same instruction), (b) every other instruction path re-validates accounts it assumes are closed.
- **Evidence:** sealevel-attacks #9; Neodyme's [Exploring Solana Core](https://neodyme.io/en/blog/solana_core_1) on program-owned lamports/vault subtleties.

### F2. Realloc attacks

- **Mechanism:** `realloc` beyond the 10 KB per-instruction growth limit fails, but realloc without `zero_init` leaves stale cross-type data readable (info leak / type confusion), and realloc-down-then-up games limits. Anchor `init` space miscalculation (`8 + T::space()` not updated when fields are added) truncates accounts.
- **Detect:** grep `realloc`, `space =`, `Loader`/`load_init`; bound `new_len` against `data_len + 10240`; require `zero_init` where cleanliness matters; recompute space on every struct change.

### F3. Rent exemption and lamport accounting

- **Mechanism:** accounts left below rent-exempt minimum get garbage-collected; lamport arithmetic that rounds below the minimum (or drains PDA vaults to exactly zero) breaks assumptions.
- **Detect:** every lamport `transfer`/drain site: does the remainder stay rent-exempt? Are PDA rent lamports accounted on close (refund paths)?

## G. Oracles and economics

This is the layer where audited protocols still lose nine figures. Mango, Nirvana, Solend, and Loopscale were all **economic** failures in code that worked exactly as written.

### G1. Spot-price manipulation (in-transaction)

- **Mechanism:** pricing collateral from an AMM pool (or any on-chain spot) an attacker can move within the same transaction. Solana has no flash-loan primitive and does not need one: any multi-instruction transaction is atomic.
- **Exploit:** manipulate price → borrow/withdraw against inflated collateral → restore (or not even bother) → profit, all in one transaction.
- **Detect:** map every price source to its market; for each, ask "what does it cost to move this price one slot, and what does the protocol extend against it?" Flag any collateral priced from a pool with manipulable liquidity.
- **Fix:** manipulation-resistant sources (TWAP over a meaningful window, Pyth with confidence bounds), collateral haircuts by liquidity, per-asset deposit caps, deviation and staleness circuit breakers.
- **Evidence:** Mango ($114M — thin MNGO market pumped, Pyth mark fed collateral); Nirvana ($3.5M); Loopscale ($5.8M — RateX Pendle-PT valuation); Solend ($1.26M — USDH pumped on Saber, pool write-locked to block same-slot arbitrage so the Switchboard feed carried the inflated price into the next slot).

### G2. Oracle misuse (Pyth / Switchboard / TWAP)

- **Mechanism:** consuming `get_price` without checking status (trading vs halted), confidence interval, or staleness; TWAP windows too short or defeatable when the attacker can hold the price across the window; oracles fed from manipulable pools.
- **Detect:** grep `get_price`, `PriceFeed`, `Twap`, `oracle`; require status==Trading, staleness bound on `pub_slot`/timestamp, confidence-band handling, and a written manipulation-resistance argument for the underlying market. Mango v4's OtterSec Low OS-MNG-ADV-02 (Pyth status not checked) is the exact pattern — and Mango still died in this layer.
- **Evidence (2026):** the Drift April 2026 reports describe a wash-traded fake token whitelisted as collateral — oracle defense-in-depth must include **what** is priced, not just how.

### G3. Collateral quality

- **Mechanism:** illiquid or self-referential collateral (the protocol's own token, an employee's token, a low-float PT) at full LTV is an economic hole no amount of code correctness fills.
- **Detect:** for each collateral type: liquidity, float, who controls supply, correlation to the protocol's own solvency. Flag own-token collateral and any asset whose price the borrower can influence.

### G4. Share-price / vault inflation (ERC-4626 analogue)

- **Mechanism:** `shares = assets * total_shares / total_assets` with round-down and a zero-share edge: a first "depositor" donates assets directly to the vault (direct SPL transfer to the vault's token account) to inflate the ratio, so later small depositors round to zero shares.
- **Detect:** review deposit/withdraw share math for zero-total-shares branches, rounding direction, and whether direct donations to vault token accounts move `total_assets`; mitigate with virtual shares/dead shares/minimum initial liquidity.
- **Cross-ref:** `cross-ecosystem.md` — same math as the EVM ERC-4626 inflation attack.

### G5. Governance and incentive capture

- **Mechanism:** token-weighted governance executable immediately is borrowable (flash-borrow votes, pass the malicious proposal, self-execute). Solana DAOs with Realms and short voting periods have the same exposure.
- **Evidence:** Beanstalk ($182M, EVM, Apr 2022) is the canonical case; see `incidents.md`.

## H. Anchor-specific pitfalls

Anchor's constraint system is the safety layer — most Anchor findings are places where it was bypassed or under-specified. See the [Anchor Footguns](https://www.anchor-lang.com/) reference and [Neodyme's Common Pitfalls](https://neodyme.io/en/blog/solana_common_pitfalls).

1. **`init_if_needed`** — skips initialization on pre-existing accounts, so an attacker pre-creates the PDA with attacker-controlled fields (`authority = attacker`) that the handler then trusts. Every field must be re-validated on the "already exists" path. Verify each use.
2. **`UncheckedAccount` / bare `AccountInfo`** — opts out of all constraints; the surrounding handler must do signer/owner/type/derivation checks manually. Grep and read every one.
3. **Under-constrained `#[account(...)]`** — `mut`/`payer` only, or an empty constraint set: ownership and type hold, but role binding (A3) does not.
4. **`remaining_accounts`** — raw, unconstrained, positionally indexed; classic substitution surface. Read every indexing into it.
5. **`Option<Account<T>>`** — `Some` paths carry constraints, but code that "falls back" to raw checks (or uses `Option<AccountInfo>`) bypasses them.
6. **`declare_id!` drift** — mismatches between crates/tests/IDL make cross-program checks bind to the wrong program id. Diff `declare_id` values across the workspace; run `anchor keys sync` in CI.
7. **Space calculation drift** — adding fields without updating `space =` truncates or fails deserialization on old accounts (upgrade hazard, see `release-security.md`).

## I. Randomness

- **Mechanism:** `SlotHashes`, recent blockhashes, slot numbers, and `Clock::unix_timestamp` are observable/predictable by validators and bots before commitment; raffles and lotteries keyed on them are front-runnable.
- **Detect:** grep `SlotHashes`, `slot_hashes`, `blockhash`, `unix_timestamp` in anything selecting winners or sampling.
- **Fix:** commit-reveal or Switchboard VRF / Orao; see Neodyme's [Secure Randomness](https://neodyme.io/en/blog/secure-randomness-part-1) series.

## J. MEV, front-running, and ordering

- **Mechanism:** Solana has no global public mempool, but Jito bundles reintroduce sandwich/backrun MEV on AMM swaps, and transactions visible to validators/relays can be front-run. Priority fees auction ordering.
- **Detect:** AMM and oracle paths without slippage/price-limit parameters; user-facing flows that reveal intents (open orders, pending cancels) exploitable by block-stuffing.
- **Reference:** [Helius Solana MEV report](https://www.helius.dev/blog/solana-mev-report-trends-insights-and-challenges); Jito's "dontfront" guidance on [solana.com](https://solana.com/docs).

## K. Transaction-level replay and pre-signing

- **Mechanism:** transactions stay valid while the recent blockhash is unexpired (~60s/150 blocks) — UX-layer replays must be guarded on-chain. **Durable nonces remove expiry entirely**: a pre-signed durable-nonce transaction is a live credential that can be submitted weeks later.
- **Detect:** audit multisig/council signing flows for durable-nonce usage and any "pre-sign for convenience" pattern; treat signed-but-unsubmitted transactions as standing key compromise; require full transaction simulation and content review before signing, timelocks on admin execution.
- **Evidence:** Drift, April 2026, $285M — Security Council members pre-signed durable-nonce transactions during a social-engineering campaign; the transactions later whitelisted a fake collateral token and drained vaults. Reference: [Neodyme, Nonce Upon a Time](https://neodyme.io/en/blog/nonce-upon-a-time).

## L. Off-chain components

- **SDK/log spoofing:** the Phoenix OtterSec audit (High OS-EPS-ADV-01) found the SDK parsed failed transactions as successes — a directly-invoked program can emit fake success logs. Clients must verify transaction status and logs, not just emit-and-hope.
- **Key handling:** Slope (2022) logged seed phrases to a centralized Sentry server; ~9,000 wallets drained. Nothing that logs, transmits, or persists key material is in scope-tolerance.
- **Indexers/keepers/bridges:** on-chain code assumes their outputs; audit their failure modes as part of the trust base (see `release-security.md`).

## The ripgrep pack

Run these over `programs/` (or the crate root). Every hit is a lead to read in context, not a finding:

```bash
# Escape hatches from Anchor's constraint system
rg -n "UncheckedAccount|AccountInfo|Option<Account" programs/
rg -n "init_if_needed" programs/
rg -n "remaining_accounts" programs/

# CPI surface
rg -n "\binvoke\b|invoke_signed|CpiContext::new" programs/
rg -n "get_return_data" programs/

# PDA handling
rg -n "find_program_address|create_program_address|bump" programs/

# Arithmetic
rg -n "checked_add|checked_sub|checked_mul|checked_div" programs/   # absence is the smell
rg -n " as u64| as u128| as i64|\.pow\(|f64" programs/
rg -n "overflow-checks" Cargo.toml                                   # must be true for release

# Token ops
rg -n "transfer\(|transfer_checked|mint_to|burn|approve|close_account" programs/

# Lifecycle
rg -n "realloc| lamports" programs/

# Oracles
rg -n "get_price|PriceFeed|Twap|oracle|switchboard|pyth" programs/

# Randomness
rg -n "SlotHashes|slot_hashes|blockhash|unix_timestamp" programs/

# Authority surface (for the ops review)
rg -n "authority|admin|upgrade" programs/ Anchor.toml
```

## What real audits actually find

Concrete findings from public reports (links in `audited-programs.md`) — use these to calibrate severity and phrasing:

- **OpenBook v2** (OtterSec): Critical — `place_order` lacks validation that `market_vault` matches the order side (A3).
- **Solend** (Kudelski): High — reserve account owner never checked (A2); High — interest-rate precision loss (D2); Medium — non-`Pod` fields in `bytemuck::Pod` structs; Low — Pyth product parsing can index out of bounds.
- **Wormhole** (Neodyme, Jan 2022): Critical — signature verification paths not executing verification; Critical — Terra replay; High — token bridge target not checked. Weeks later, the $325M exploit hit the same subsystem.
- **Mango v4** (OtterSec): Critical — HealthRegions access controls absent, enabling bad-debt generation and self-liquidation; Low — Pyth staleness unchecked.
- **Kamino** (OtterSec/Ackee/Sec3): High — instruction-sequence assumptions (improper sequence checking); High — elevation-group ID mismatch; Medium — TOCTOU in token-extension handling; Medium — fee evasion via liquidation timing; Low — PDA squatting.
- **Phoenix** (OtterSec): High — SDK parses failed transactions as success (L); Medium — orderbook overflows under parameter configurations (D1); Medium — account-creation DoS edge case.
- **Orca Whirlpools** (Neodyme/Kudelski/Sec3): Medium — swap-path integer overflow (D1); Low — code did not compile to BPF (toolchain hygiene).
- **Trail of Bits on Wormhole**: "No general protection against type cosplay"; "Insufficient safeguards against destruction in the proxy"; inconsistent checked math (D1).

Cross-cutting: Solana audits concentrate on account-constraint failures, authority/signer checks, overflow/rounding in math libraries, oracle staleness/manipulation, CPI/instruction-sequence assumptions, and PDA collisions — in that order of frequency. The economic layer (G) shows up less in audit PDFs and more in post-mortems; cover it anyway.
