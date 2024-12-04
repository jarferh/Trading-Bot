//+------------------------------------------------------------------+
//|                                                EMA_Crossover.mq5 |
//|                               Developed by [Your Name or Company] |
//+------------------------------------------------------------------+
#property copyright "Your Name or Company"
#property link      "Your Website or Contact Info"
#property version   "1.02"
#property strict

//--- Input parameters
input double Lots=0.1;               // Lot size
input double RiskReward=1.2;         // Risk-to-Reward Ratio (1:2)
input int    StopLossPips=0;         // Stop Loss in Pips (0 to calculate dynamically)
input int    MagicNumber=110048;      // Unique identifier for orders
input int    StartHour=0;            // Trading start hour (0-23)
input int    EndHour=24;             // Trading end hour (1-24)

//--- Indicators handles
int EMA9_Handle;
int EMA21_Handle;
int RSI_Handle;

//--- Buffers for indicators
double EMA9[];
double EMA21[];
double RSI[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Create handles for indicators
    EMA9_Handle  = iMA(_Symbol, _Period, 9, 0, MODE_EMA, PRICE_CLOSE);
    EMA21_Handle = iMA(_Symbol, _Period, 21, 0, MODE_EMA, PRICE_CLOSE);
    RSI_Handle   = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
    
    if(EMA9_Handle==INVALID_HANDLE || EMA21_Handle==INVALID_HANDLE || RSI_Handle==INVALID_HANDLE)
    {
        Print("Failed to create indicator handles");
        return(INIT_FAILED);
    }
    
    //--- Set arrays as series
    ArraySetAsSeries(EMA9, true);
    ArraySetAsSeries(EMA21, true);
    ArraySetAsSeries(RSI, true);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Check trading hours
    if(!IsWithinTradingHours())
        return;

    //--- Check for a new bar
    static datetime lastBarTime=0;
    datetime currentBarTime = iTime(_Symbol, _Period, 0);
    if(currentBarTime == lastBarTime)
        return;
    lastBarTime = currentBarTime;
    
    //--- Get indicator values
    CopyBuffer(EMA9_Handle,  0, 0, 3, EMA9);
    CopyBuffer(EMA21_Handle, 0, 0, 3, EMA21);
    CopyBuffer(RSI_Handle,   0, 0, 1, RSI);
    
    //--- Get current and previous EMA values
    double EMA9_Current    = EMA9[0];
    double EMA9_Previous   = EMA9[1];
    double EMA21_Current   = EMA21[0];
    double EMA21_Previous  = EMA21[1];
    double RSI_Current     = RSI[0];
    
    //--- Check for existing orders
    if(PositionSelect(_Symbol))
    {
        ManageExistingTrade();
        return;
    }
    
    //--- Check for buy or sell conditions
    if(CheckBuyCondition(EMA9_Current, EMA9_Previous, EMA21_Current, EMA21_Previous, RSI_Current))
    {
        OpenBuyTrade();
    }
    else if(CheckSellCondition(EMA9_Current, EMA9_Previous, EMA21_Current, EMA21_Previous, RSI_Current))
    {
        OpenSellTrade();
    }
}

//+------------------------------------------------------------------+
//| Check Trading Hours                                              |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
    //--- Get the current server time
    datetime currentTime = TimeCurrent();
    MqlDateTime struct_time;
    TimeToStruct(currentTime, struct_time);
    int currentHour = struct_time.hour;

    //--- Adjust EndHour if needed
    int adjustedEndHour = EndHour;
    if (EndHour == 24)
        adjustedEndHour = 0;

    //--- Check if current time is within trading hours
    if (StartHour < EndHour)
    {
        // Same day
        return (currentHour >= StartHour && currentHour < EndHour);
    }
    else
    {
        // Over midnight
        return (currentHour >= StartHour || currentHour < adjustedEndHour);
    }
}

//+------------------------------------------------------------------+
//| Check Buy Condition                                              |
//+------------------------------------------------------------------+
bool CheckBuyCondition(double EMA9_Curr, double EMA9_Prev, double EMA21_Curr, double EMA21_Prev, double RSI_Curr)
{
    //--- EMA crossover: 9 EMA crosses above 21 EMA
    bool EMA_Crossover = (EMA9_Prev < EMA21_Prev) && (EMA9_Curr > EMA21_Curr);
    
    //--- Price above both EMAs
    double Price_Close = iClose(_Symbol, _Period, 1);
    bool PriceAboveEMAs = (Price_Close > EMA9_Curr) && (Price_Close > EMA21_Curr);
    
    //--- RSI above 50
    bool RSI_Confirm = (RSI_Curr > 50);
    
    return (EMA_Crossover && PriceAboveEMAs && RSI_Confirm);
}

//+------------------------------------------------------------------+
//| Check Sell Condition                                             |
//+------------------------------------------------------------------+
bool CheckSellCondition(double EMA9_Curr, double EMA9_Prev, double EMA21_Curr, double EMA21_Prev, double RSI_Curr)
{
    //--- EMA crossover: 9 EMA crosses below 21 EMA
    bool EMA_Crossover = (EMA9_Prev > EMA21_Prev) && (EMA9_Curr < EMA21_Curr);
    
    //--- Price below both EMAs
    double Price_Close = iClose(_Symbol, _Period, 1);
    bool PriceBelowEMAs = (Price_Close < EMA9_Curr) && (Price_Close < EMA21_Curr);
    
    //--- RSI below 50
    bool RSI_Confirm = (RSI_Curr < 50);
    
    return (EMA_Crossover && PriceBelowEMAs && RSI_Confirm);
}

//+------------------------------------------------------------------+
//| Open Buy Trade                                                   |
//+------------------------------------------------------------------+
void OpenBuyTrade()
{
    double SL, TP;
    double Price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    //--- Calculate Stop Loss below 21 EMA
    SL = EMA21[0];
    //--- Calculate Take Profit for 1:2 Risk-Reward
    double RiskPips = (Price - SL) / _Point;
    double RewardPips = RiskPips * RiskReward;
    TP = Price + (RewardPips * _Point);
    
    //--- Create request
    MqlTradeRequest request;
    MqlTradeResult  result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action   = TRADE_ACTION_DEAL;
    request.symbol   = _Symbol;
    request.volume   = Lots;
    request.type     = ORDER_TYPE_BUY;
    request.price    = Price;
    request.sl       = NormalizeDouble(SL, _Digits);
    request.tp       = NormalizeDouble(TP, _Digits);
    request.magic    = MagicNumber;
    request.deviation= 10;
    request.type_filling = ORDER_FILLING_FOK;
    
    if(!OrderSend(request, result))
    {
        Print("Buy OrderSend failed: ", result.comment);
    }
}

//+------------------------------------------------------------------+
//| Open Sell Trade                                                  |
//+------------------------------------------------------------------+
void OpenSellTrade()
{
    double SL, TP;
    double Price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    //--- Calculate Stop Loss above 21 EMA
    SL = EMA21[0];
    //--- Calculate Take Profit for 1:2 Risk-Reward
    double RiskPips = (SL - Price) / _Point;
    double RewardPips = RiskPips * RiskReward;
    TP = Price - (RewardPips * _Point);
    
    //--- Create request
    MqlTradeRequest request;
    MqlTradeResult  result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action   = TRADE_ACTION_DEAL;
    request.symbol   = _Symbol;
    request.volume   = Lots;
    request.type     = ORDER_TYPE_SELL;
    request.price    = Price;
    request.sl       = NormalizeDouble(SL, _Digits);
    request.tp       = NormalizeDouble(TP, _Digits);
    request.magic    = MagicNumber;
    request.deviation= 10;
    request.type_filling = ORDER_FILLING_FOK;
    
    if(!OrderSend(request, result))
    {
        Print("Sell OrderSend failed: ", result.comment);
    }
}

//+------------------------------------------------------------------+
//| Manage Existing Trade                                            |
//+------------------------------------------------------------------+
void ManageExistingTrade()
{
    ulong ticket = PositionGetTicket(0);
    double EMA9_Current  = EMA9[0];
    double EMA21_Current = EMA21[0];
    
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    //--- Check for alternative exit signal
    bool ExitSignal = false;
    
    if(type == POSITION_TYPE_BUY)
    {
        //--- If 9 EMA crosses below 21 EMA, exit buy trade
        if((EMA9[1] > EMA21[1]) && (EMA9[0] < EMA21[0]))
        {
            ExitSignal = true;
        }
    }
    else if(type == POSITION_TYPE_SELL)
    {
        //--- If 9 EMA crosses above 21 EMA, exit sell trade
        if((EMA9[1] < EMA21[1]) && (EMA9[0] > EMA21[0]))
        {
            ExitSignal = true;
        }
    }
    
    if(ExitSignal)
    {
        ClosePosition(ticket);
    }
}

//+------------------------------------------------------------------+
//| Close Position                                                   |
//+------------------------------------------------------------------+
void ClosePosition(ulong ticket)
{
    MqlTradeRequest request;
    MqlTradeResult  result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double volume = PositionGetDouble(POSITION_VOLUME);
    request.action   = TRADE_ACTION_DEAL;
    request.symbol   = _Symbol;
    request.volume   = volume;
    request.magic    = MagicNumber;
    request.position = ticket;
    request.deviation= 10;
    request.type_filling = ORDER_FILLING_FOK;
    
    if(type == POSITION_TYPE_BUY)
    {
        request.type  = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    }
    else if(type == POSITION_TYPE_SELL)
    {
        request.type  = ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    }
    
    if(!OrderSend(request, result))
    {
        Print("Close Position failed: ", result.comment);
    }
}

//+------------------------------------------------------------------+
