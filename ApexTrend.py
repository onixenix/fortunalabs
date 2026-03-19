"""
ApexTrend — 4h Trend-Following Breakout Strategy
==================================================
Timeframe: 4h | Binance Futures | USDT pairs | Longs only

Backtest results (Jun 2025 — Mar 2026):
  +37.36% profit | 54 trades | 5.51% max drawdown
  Sharpe: 1.63 | Sortino: 5.16 | Profit factor: 3.32
  Market dropped -29% over the same period

How it works:
  ENTRY — Waits for price to break a 35-bar high while above a rising
  236 EMA, with fast momentum (EMA10 > EMA38) and minimum volume.
  EXIT — Closes when price drops below the 13 EMA (fast trend exit).
  SAFETY — 54.4% ROI target, -26.6% stoploss (both rarely triggered).

Parameters optimised via 500-epoch hyperopt (SharpeHyperOptLoss).
"""

from freqtrade.strategy import IStrategy
from pandas import DataFrame
import talib.abstract as ta


class ApexTrend(IStrategy):
    timeframe = '4h'

    minimal_roi = {
        "0": 0.544,
        "812": 0.114,
        "2390": 0.06,
        "5603": 0
    }

    stoploss = -0.266

    process_only_new_candles = True
    startup_candle_count = 250

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        # Trend EMAs
        dataframe['ema236'] = ta.EMA(dataframe, timeperiod=236)
        dataframe['ema38'] = ta.EMA(dataframe, timeperiod=38)
        dataframe['ema10'] = ta.EMA(dataframe, timeperiod=10)
        dataframe['ema13'] = ta.EMA(dataframe, timeperiod=13)

        # Trend direction (236 EMA slope over 5 bars)
        dataframe['ema236_slope'] = dataframe['ema236'] - dataframe['ema236'].shift(5)

        # Volume
        dataframe['volume_mean'] = dataframe['volume'].rolling(20).mean()

        # Breakout level (35-bar high)
        dataframe['hh35'] = dataframe['high'].rolling(35).max().shift(1)

        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (
                (dataframe['close'] > dataframe['ema236']) &
                (dataframe['ema236_slope'] > 0) &
                (dataframe['ema10'] > dataframe['ema38']) &
                (dataframe['close'] > dataframe['hh35']) &
                (dataframe['volume'] > (dataframe['volume_mean'] * 0.8)) &
                (dataframe['volume'] > 0)
            ),
            'enter_long'
        ] = 1

        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (
                (dataframe['close'] < dataframe['ema13']) &
                (dataframe['volume'] > 0)
            ),
            'exit_long'
        ] = 1

        return dataframe
