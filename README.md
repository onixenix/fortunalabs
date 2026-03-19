# ApexTrend

4h trend-following breakout strategy for Binance futures.

## Performance (backtest Jun 2025 – Mar 2026)

- **Return:** +37.36% (+373.61 USDT on 1000 USDT)
- **Trades:** 54 (avg 1.87% profit per trade)
- **Win rate:** 53.7%
- **Max drawdown:** 5.51%
- **Sharpe:** 1.63 | **Sortino:** 5.16 | **Profit factor:** 3.32
- **Market:** fell -29% over the same period

## How it works

**Entry** — all conditions must be true:
1. Price is above a rising 236 EMA (macro uptrend)
2. EMA 10 is above EMA 38 (momentum confirmation)
3. Price breaks the 35-bar high (breakout trigger)
4. Volume is above 0.8x the 20-bar average (minimum activity)

**Exit:**
- Price closes below the 13 EMA (fast trend exit)

**Safety nets:**
- ROI: 54.4% take-profit (tiered down over time)
- Stoploss: -26.6% (rarely triggered)

## Setup

1. Copy `ApexTrend.py` into:
   ```
   C:\Users\timot\freqtrade\user_data\strategies\
   ```

2. Copy `config.json` into:
   ```
   C:\Users\timot\freqtrade\user_data\
   ```
   (Back up your existing config first)

3. Delete any leftover hyperopt JSON:
   ```
   del C:\Users\timot\freqtrade\user_data\strategies\GenericTrendStrategy.json
   ```

## Commands

```powershell
# Start dry-run trading
freqtrade trade --config user_data/config.json --strategy ApexTrend

# Backtest
freqtrade backtesting --config user_data/config.json --strategy ApexTrend --timerange 20250601-20260316

# Download fresh data
freqtrade download-data --config user_data/config.json --timeframe 4h --days 290

# Web dashboard
# http://127.0.0.1:8080
# Username: Freqtrader
# Password: SuperSecret1!
```

## Pairs

BTC/USDT, ETH/USDT, SOL/USDT, XRP/USDT — all profitable in backtest.

## Notes

- Strategy is long-only (no shorts)
- Trades hold for ~2 days on average
- ~0.19 trades per day (patient, selective)
- Parameters were optimised via 500-epoch hyperopt (SharpeHyperOptLoss)
- Backtest used isolated futures mode with 1000 USDT dry-run wallet
- **This is dry-run only** — add Binance API keys to config when ready to go live
