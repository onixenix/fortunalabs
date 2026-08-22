# Fortuna Coil — Methodology Note

This document exists so you can check our work. Most indicator sellers can't (or won't)
tell you where their logic came from. Here is the full provenance.

## Where the logic comes from

Fortuna Coil is a faithful port of a strategy from the Fortuna research system: an
automated pipeline that generates candidate trading strategies, then forces each one
through a fixed gauntlet before it's allowed near real money:

1. **Pre-registration** — the hypothesis, parameters, and success criteria are locked
   in writing before any test runs.
2. **Falsification battery** — cheap statistical checks (event counts, frequency-matched
   controls, lead/lag tests, expected value vs. transaction costs) that kill weak ideas
   in minutes of compute.
3. **Canonical-engine backtest** — one engine, realistic costs (taker fees + slippage
   per side, funding), daily mark-to-market performance. No per-trade annualisation
   (a convention that inflates results ~3x — we measured that on our own data).
4. **Lookahead audit** — an automated check that no future information leaks into
   signals.
5. **Out-of-sample testing** — the strategy is run on a data window it was never
   developed on.
6. **Forward observation** — the surviving strategy is tracked on genuinely new data
   before admission to a portfolio.

Of more than 1,800 strategies the system generated, roughly a quarter showed *some*
real signal, and a handful survived everything. Two of our own flagship "validated"
strategies were killed by our own re-audit in May 2026 — the measurement, not the
market, had been wrong. We publish that history because it's the reason to trust the
one that survived.

## The surviving logic

**Hypothesis:** when price is coiled in a low-volatility regime, the first breakout
confirmed by an abnormal volume surge marks genuine informed participation rather than
noise. Volume is the discriminator: a level break on flat volume is mostly a fakeout;
a break on 2–3× average volume reflects order-flow imbalance that takes days to clear.

**Mechanics** (all causal — every input uses only past data):

- Range: highest/lowest high/low of the prior 40 bars, shifted one bar.
- Volume surge: current volume ≥ 2.0× the prior 20-bar average.
- Coil regime: ATR/close (scale-free realised volatility) in the bottom 40th percentile
  of its trailing 252-bar window, measured on the bar before the break.
- Entry: coil + break + surge, both directions, only while flat.
- Exit: 3×ATR trail from the best close since entry, plus a 10-bar time stop.

## What it measured (the honest numbers)

- **Instrument:** Binance USDT-M perpetual futures, 10 largest alt pairs (BTC, ETH,
  SOL, BNB, DOGE, XRP, ADA, HYPE, ZEC, 1000PEPE), daily bars.
- **Windows:** in-sample 2023-01 → 2025-05; out-of-sample 2025-06 → 2026-05; plus a
  forward observation window (2026-05-21 → 2026-07-08) the strategy had never touched.
- **Costs:** 10bp taker fee + 2bp slippage per side (~24bp round trip), funding applied.
- **Results:** out-of-sample Sharpe ≈ 1.27 annualised, profit factor 2.50 over 21
  trades; forward window held Sharpe flat (1.274 → 1.263) with 12 additional trades.
- **Lookahead audit:** passed.

## What we deliberately do NOT claim

- **No forward expectation of 1.27.** Standard shrinkage for a strategy selected from
  a large candidate pool puts the honest forward expectation around 0.4–0.7 Sharpe at
  ~2 trades/month. That is what we'd expect, not promise.
- **No other-market claims.** The evidence is crypto perps on daily bars. Forex,
  equities, intraday timeframes — unvalidated.
- **No income claims, ever.** Historical simulations describe the past. They are not a
  forecast and not advice.
