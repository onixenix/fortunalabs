//+------------------------------------------------------------------+
//| FortunaCoil.mq5                                                  |
//| Volume-confirmed low-volatility coil breakout — Expert Advisor.  |
//|                                                                  |
//| MQL5 port of the Fortuna "coil-volume-breakout" strategy.        |
//| The historical evidence for this logic was measured on Binance   |
//| USDT-M perpetual futures (daily bars, 2023-2026, honest costs).  |
//| It has NOT been validated on forex/CFD tick-volume data — treat  |
//| MT5 results as unvalidated until you run the tester yourself.    |
//|                                                                  |
//| Past performance does not imply future results.                  |
//| Not financial advice. General-information software only.         |
//+------------------------------------------------------------------+
#property copyright "Fortuna Labs"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

CTrade trade;

//--- inputs: signal
input int    InpRangeLookback    = 40;    // Range lookback (bars)
input int    InpVolAvgLookback   = 20;    // Volume average lookback (bars)
input double InpVolSurgeMult     = 2.0;   // Volume surge multiple
input double InpBucketMax        = 0.40;  // Low-vol percentile max (0..1)
input int    InpAtrLookback      = 14;    // ATR lookback (bars)
input int    InpRvolWindow       = 252;   // Regime percentile window (bars)
//--- inputs: exits
input double InpTrailAtrMult     = 3.0;   // ATR trail multiple
input int    InpMaxHoldBars      = 10;    // Max holding bars (time stop)
//--- inputs: direction & risk
input bool   InpAllowLong        = true;
input bool   InpAllowShort       = true;
input double InpRiskFrac         = 0.01;  // Risk fraction of equity per trade
//--- inputs: execution
input ulong  InpMagic            = 20260709;
input string InpComment          = "FortunaCoil";

int    atrHandle = INVALID_HANDLE;
double rvolBuf[];

//+------------------------------------------------------------------+
int OnInit()
  {
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpAtrLookback);
   if(atrHandle == INVALID_HANDLE)
     {
      Print("FortunaCoil: failed to create ATR handle");
      return(INIT_FAILED);
     }
   trade.SetExpertMagicNumber(InpMagic);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
  }

//+------------------------------------------------------------------+
//| Percentile rank of x[1] within the last `window` values of buf   |
//| (excludes the current bar — matches the Python reference).       |
//+------------------------------------------------------------------+
double PercentRankPrev(const double &buf[], int window)
  {
   int n = ArraySize(buf);
   if(n < window + 2) return EMPTY_VALUE;
   double x = buf[n - 2];              // previous bar's value
   if(x == EMPTY_VALUE) return EMPTY_VALUE;
   int count = 0, total = 0;
   for(int i = n - window - 1; i <= n - 2; i++)
     {
      if(buf[i] == EMPTY_VALUE) continue;
      total++;
      if(buf[i] < x) count++;
     }
   if(total == 0) return EMPTY_VALUE;
   return (double)count / total;
  }

//+------------------------------------------------------------------+
//| Build the rvol series (ATR/close) over the window we need.       |
//+------------------------------------------------------------------+
bool BuildRvol(double &out[])
  {
   int need = InpRvolWindow + 2;
   double atr[];
   ArraySetAsSeries(atr, false);
   if(CopyBuffer(atrHandle, 0, 0, need, atr) < need) return false;
   ArrayResize(out, need);
   for(int i = 0; i < need; i++)
     {
      double c = iClose(_Symbol, PERIOD_CURRENT, need - 1 - i);
      out[i] = (c > 0) ? atr[i] / c : EMPTY_VALUE;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Position helper: returns direction of our position, 0 if flat.   |
//+------------------------------------------------------------------+
int MyPositionDir()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      return PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
     }
   return 0;
  }

datetime lastBarTime = 0;

//+------------------------------------------------------------------+
void OnTick()
  {
   // Evaluate once per completed bar (daily-bar logic).
   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool newBar = (barTime != lastBarTime);
   if(!newBar) { ManageOpenPosition(false); return; }
   lastBarTime = barTime;

   ManageOpenPosition(true);

   if(MyPositionDir() != 0) return;   // one position at a time (matches reference)

   // --- range bands (prior bars only)
   double priorHigh = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, InpRangeLookback, 1));
   double priorLow  = iLow (_Symbol, PERIOD_CURRENT, iLowest (_Symbol, PERIOD_CURRENT, MODE_LOW,  InpRangeLookback, 1));
   double closePrev = iClose(_Symbol, PERIOD_CURRENT, 1);
   bool breakUp   = closePrev > priorHigh;
   bool breakDown = closePrev < priorLow;

   // --- volume surge vs trailing average of PRIOR bars
   double volAvg = 0;
   for(int i = 2; i < 2 + InpVolAvgLookback; i++) volAvg += (double)iVolume(_Symbol, PERIOD_CURRENT, i);
   volAvg /= InpVolAvgLookback;
   double volNow = (double)iVolume(_Symbol, PERIOD_CURRENT, 1);
   bool volSurge = (volAvg > 0) && (volNow / volAvg >= InpVolSurgeMult);

   // --- low-vol regime
   double rvol[];
   if(!BuildRvol(rvol)) return;
   double pct = PercentRankPrev(rvol, InpRvolWindow);
   if(pct == EMPTY_VALUE) return;
   bool coilReady = (pct <= InpBucketMax);

   if(!coilReady || !volSurge) return;

   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1) return;
   double trail = InpTrailAtrMult * atr[0];
   if(trail <= 0) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(breakUp && InpAllowLong)
      EnterLong(ask, trail);
   else if(breakDown && InpAllowShort)
      EnterShort(bid, trail);
  }

//+------------------------------------------------------------------+
void EnterLong(double px, double trail)
  {
   double sl = px - trail;
   double lots = LotsForRisk(px - sl);
   if(lots <= 0) return;
   trade.Buy(lots, _Symbol, 0.0, NormalizeDouble(sl, _Digits), 0.0, InpComment);
  }

void EnterShort(double px, double trail)
  {
   double sl = px + trail;
   double lots = LotsForRisk(sl - px);
   if(lots <= 0) return;
   trade.Sell(lots, _Symbol, 0.0, NormalizeDouble(sl, _Digits), 0.0, InpComment);
  }

//+------------------------------------------------------------------+
//| Risk-based sizing: risk InpRiskFrac of equity over stop distance.|
//+------------------------------------------------------------------+
double LotsForRisk(double stopDist)
  {
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmt  = equity * InpRiskFrac;
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0 || tickSize <= 0 || stopDist <= 0) return 0;
   double lossPerLot = stopDist / tickSize * tickVal;
   if(lossPerLot <= 0) return 0;
   double lots = riskAmt / lossPerLot;
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   return lots;
  }

//+------------------------------------------------------------------+
//| ATR trail from best close since entry + time stop.               |
//| `onBarClose` gates the exit decision to completed bars only.     |
//+------------------------------------------------------------------+
void ManageOpenPosition(bool onBarClose)
  {
   if(!onBarClose) return;
   int dir = MyPositionDir();
   if(dir == 0) return;

   if(!PositionSelectByTicket(PositionGetTicket(PositionTotal() - 1))) return;

   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1) return;
   double trail = InpTrailAtrMult * atr[0];

   datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
   int barsHeld = Bars(_Symbol, PERIOD_CURRENT, opened, TimeCurrent()) - 1;

   double closePrev = iClose(_Symbol, PERIOD_CURRENT, 1);

   // Best close since entry (scan completed bars from entry to prev bar)
   int entryShift = iBarShift(_Symbol, PERIOD_CURRENT, opened, false);
   double best = closePrev;
   for(int i = entryShift; i >= 1; i--)
     {
      double c = iClose(_Symbol, PERIOD_CURRENT, i);
      best = (dir == 1) ? MathMax(best, c) : MathMin(best, c);
     }

   bool timeStop = barsHeld >= InpMaxHoldBars;
   bool trailHit = (dir == 1) ? (closePrev <= best - trail)
                              : (closePrev >= best + trail);

   if(trailHit || timeStop)
     {
      double px = (dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                             : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      trade.PositionClose(_Symbol);
      PrintFormat("FortunaCoil exit: %s (%s)", trailHit ? "trail" : "time",
                  _Symbol);
     }
  }
//+------------------------------------------------------------------+
