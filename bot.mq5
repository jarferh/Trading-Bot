//+------------------------------------------------------------------+
//|                                                    bot.mq5   |
//|                        Copyright 2023, Your Name                 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Name"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Include necessary libraries
#include <Trade\Trade.mqh>

// Define Input Parameters
input int EMA_Fast_Period = 9;    // Fast EMA period
input int EMA_Slow_Period = 21;   // Slow EMA period
input int RSI_Period = 14;        // RSI period
input double RiskRewardRatio = 2; // Risk to Reward ratio (1:2)
input double RiskPercent = 1.0;   // Risk percentage per trade
input int RSI_Level = 50;         // RSI confirmation level
input ENUM_TIMEFRAMES Timeframe = PERIOD_M5; // Select timeframe (M5, M15)

// Define global variables
int fast_ema_handle, slow_ema_handle, rsi_handle;
CTrade trade;

//+------------------------------------------------------------------+
// Initialize the Expert Advisor
int OnInit()
  {
   // Initialize indicator handles
   fast_ema_handle = iMA(_Symbol, Timeframe, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   slow_ema_handle = iMA(_Symbol, Timeframe, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   rsi_handle = iRSI(_Symbol, Timeframe, RSI_Period, PRICE_CLOSE);

   // Check if handles are created successfully
   if(fast_ema_handle == INVALID_HANDLE || slow_ema_handle == INVALID_HANDLE || rsi_handle == INVALID_HANDLE)
     {
      Print("Error creating indicator handles");
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
// The main function called on every new tick
void OnTick()
  {
   // Get the latest price
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Get indicator values
   double fast_ema_buffer[];
   double slow_ema_buffer[];
   double rsi_buffer[];
   
   ArraySetAsSeries(fast_ema_buffer, true);
   ArraySetAsSeries(slow_ema_buffer, true);
   ArraySetAsSeries(rsi_buffer, true);
   
   // Copy indicator data
   if(CopyBuffer(fast_ema_handle, 0, 0, 2, fast_ema_buffer) <= 0 ||
      CopyBuffer(slow_ema_handle, 0, 0, 2, slow_ema_buffer) <= 0 ||
      CopyBuffer(rsi_handle, 0, 0, 2, rsi_buffer) <= 0)
     {
      Print("Error copying indicator buffers");
      return;
     }
   
   double fast_ema = fast_ema_buffer[0];
   double slow_ema = slow_ema_buffer[0];
   double rsi_value = rsi_buffer[0];

   double fast_ema_prev = fast_ema_buffer[1];
   double slow_ema_prev = slow_ema_buffer[1];

   // Debug: Print current values
   PrintFormat("Current Price: %.5f, Fast EMA: %.5f, Slow EMA: %.5f, RSI: %.2f", currentPrice, fast_ema, slow_ema, rsi_value);
   PrintFormat("Previous Fast EMA: %.5f, Previous Slow EMA: %.5f", fast_ema_prev, slow_ema_prev);

   // BUY CONDITION: Fast EMA crosses above Slow EMA and RSI is above RSI_Level
   if(fast_ema > slow_ema && fast_ema_prev <= slow_ema_prev && rsi_value > RSI_Level)
     {
      Print("Buy condition met - EMA Crossover and RSI above ", RSI_Level);
      // Check if price is above both EMAs
      if(currentPrice > fast_ema && currentPrice > slow_ema)
        {
         Print("Price is above both EMAs. Attempting to open Buy order.");
         // Calculate Stop-Loss and Take-Profit
         double stop_loss = NormalizeDouble(slow_ema, _Digits);
         double risk_size = NormalizeDouble(currentPrice - stop_loss, _Digits);
         double take_profit = NormalizeDouble(currentPrice + (risk_size * RiskRewardRatio), _Digits);

         // Open a Buy order
         if(!OpenBuyOrder(currentPrice, stop_loss, take_profit))
           {
            Print("Failed to open Buy order");
           }
        }
      else
        {
         Print("Price is not above both EMAs. Buy order not opened.");
        }
     }
   else
     {
      PrintFormat("Buy condition not met: Fast EMA > Slow EMA: %s, Fast EMA crossover: %s, RSI > %d: %s",
                  BoolToString(fast_ema > slow_ema),
                  BoolToString(fast_ema > slow_ema && fast_ema_prev <= slow_ema_prev),
                  RSI_Level,
                  BoolToString(rsi_value > RSI_Level));
     }

   // SELL CONDITION: Fast EMA crosses below Slow EMA and RSI is below RSI_Level
   if(fast_ema < slow_ema && fast_ema_prev >= slow_ema_prev && rsi_value < RSI_Level)
     {
      Print("Sell condition met - EMA Crossover and RSI below ", RSI_Level);
      // Check if price is below both EMAs
      if(currentPrice < fast_ema && currentPrice < slow_ema)
        {
         Print("Price is below both EMAs. Attempting to open Sell order.");
         // Calculate Stop-Loss and Take-Profit
         double stop_loss = NormalizeDouble(slow_ema, _Digits);
         double risk_size = NormalizeDouble(stop_loss - currentPrice, _Digits);
         double take_profit = NormalizeDouble(currentPrice - (risk_size * RiskRewardRatio), _Digits);

         // Open a Sell order
         if(!OpenSellOrder(currentPrice, stop_loss, take_profit))
           {
            Print("Failed to open Sell order");
           }
        }
      else
        {
         Print("Price is not below both EMAs. Sell order not opened.");
        }
     }
   else
     {
      PrintFormat("Sell condition not met: Fast EMA < Slow EMA: %s, Fast EMA crossover: %s, RSI < %d: %s",
                  BoolToString(fast_ema < slow_ema),
                  BoolToString(fast_ema < slow_ema && fast_ema_prev >= slow_ema_prev),
                  RSI_Level,
                  BoolToString(rsi_value < RSI_Level));
     }
  }

//+------------------------------------------------------------------+
// Function to open a Buy Order
bool OpenBuyOrder(double price, double stopLoss, double takeProfit)
  {
   double lotSize = CalculateLotSize(price, stopLoss);
   
   if(trade.Buy(lotSize, _Symbol, NormalizeDouble(price, _Digits), NormalizeDouble(stopLoss, _Digits), NormalizeDouble(takeProfit, _Digits)))
     {
      Print("Buy order opened successfully. Ticket: ", trade.ResultOrder());
      return true;
     }
   else
     {
      Print("Error opening Buy order: ", GetLastError());
      return false;
     }
  }

//+------------------------------------------------------------------+
// Function to open a Sell Order
bool OpenSellOrder(double price, double stopLoss, double takeProfit)
  {
   double lotSize = CalculateLotSize(price, stopLoss);
   
   if(trade.Sell(lotSize, _Symbol, NormalizeDouble(price, _Digits), NormalizeDouble(stopLoss, _Digits), NormalizeDouble(takeProfit, _Digits)))
     {
      Print("Sell order opened successfully. Ticket: ", trade.ResultOrder());
      return true;
     }
   else
     {
      Print("Error opening Sell order: ", GetLastError());
      return false;
     }
  }

//+------------------------------------------------------------------+
// Function to calculate lot size based on risk percentage
double CalculateLotSize(double entryPrice, double stopLoss)
  {
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * RiskPercent / 100;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double pointValue = tickValue / tickSize;
   
   double riskInPoints = MathAbs(entryPrice - stopLoss) / tickSize;
   double lotSize = NormalizeDouble(riskAmount / (riskInPoints * pointValue), 2);
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   Print("Calculated lot size: ", lotSize);
   return lotSize;
  }

//+------------------------------------------------------------------+
// Function to convert bool to string for debugging
string BoolToString(bool value)
  {
   return value ? "true" : "false";
  }

//+------------------------------------------------------------------+
// Deinitialization function
void OnDeinit(const int reason)
  {
   // Clean up indicator handles
   IndicatorRelease(fast_ema_handle);
   IndicatorRelease(slow_ema_handle);
   IndicatorRelease(rsi_handle);
  }
//+------------------------------------------------------------------+
