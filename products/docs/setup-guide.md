# Fortuna Coil — Setup Guide

Thank you for buying Fortuna Coil. This guide gets you running in five minutes.

**Reminder:** this software is general information only, not financial advice. Trading
involves substantial risk of loss. Historical figures quoted in the marketing describe
what the system did with stated assumptions — not what you will get.

---

## 1. TradingView indicator

1. Open a chart on TradingView (any plan, including free).
2. Open the Pine Editor (bottom panel), delete the placeholder code.
3. Open `FortunaCoil.pine`, copy everything, paste into the editor.
4. Click **Add to chart**. Done.
5. Optional: click the alarm-clock icon → condition "Fortuna Coil [Fortuna Labs]" →
   choose "Fortuna Coil LONG" / "SHORT" / "unconfirmed break" → create alert.
   Alerts fire once per bar close (daily logic → at most one signal per bar).

### What you'll see

- **Teal bands** — the prior 40-bar high/low range. A close outside either is a level break.
- **Orange shaded zone + blue background** — the low-volatility "coil" regime: current
  realised volatility (ATR/close) sitting in the bottom 40% of its trailing year.
- **COIL triangle (green up / red down)** — coil regime + level break + volume surge
  ≥ 2× its 20-bar average. This is the full setup.
- **Grey crosses (optional, off by default)** — breaks that failed the volume check.
  Watchlist material, not entries.

### Recommended usage

The reference evidence is daily bars on liquid crypto perps. Start there. The indicator
works on any symbol/timeframe but was not validated elsewhere.

## 2. Strategy version (TradingView backtester)

Paste `FortunaCoilStrategy.pine` the same way. It includes ~6% round-trip commission to
mirror the cost model used in the reference backtest (10bp taker fee + 2bp slippage per
side). Use **Bar Replay** or the Strategy Tester tab to inspect historical behaviour.

## 3. MetaTrader 5 EA

1. MT5 → File → Open Data Folder → `MQL5/Experts/` → copy `FortunaCoil.mq5` there.
2. In MetaEditor (F4), open the file and press **Compile** (F7) — should be 0 errors.
3. Back in MT5: drag the EA from Navigator onto a chart, allow Algo Trading.
4. Inputs are pre-set to the canonical parameters (see below). Risk per trade defaults
   to 1% of equity measured to the ATR stop.

**Honest caveat repeated:** the historical validation was done on Binance perpetual
futures data with real traded volume. MT5 symbols report tick volume; treat any MT5
result as unvalidated until your own tester run says otherwise. The EA ships with source
precisely so you can audit and adapt it.

## 4. Canonical parameters

| Parameter | Value | Meaning |
|---|---|---|
| Range lookback | 40 bars | breakout band formed by prior highs/lows |
| Volume avg lookback | 20 bars | surge denominator |
| Volume surge multiple | 2.0× | break must carry 2× average volume |
| Low-vol percentile max | 0.40 | coil = rvol in bottom 40% of trailing window |
| Regime percentile window | 252 bars | ~trading year |
| ATR lookback / trail multiple | 14 / 3.0 | exit trail from best close since entry |
| Max holding bars | 10 | time stop |

These are the exact parameters from the validated research run. They were chosen by the
research pipeline before out-of-sample testing, not tuned afterwards — that's part of why
the result held up. We recommend not touching them until you've watched the tool work.

## 5. Support & refund

14-day money-back guarantee — email hello@fortunalabs.net, no questions asked.
Questions and bug reports go to the same address; we usually reply within a day.
