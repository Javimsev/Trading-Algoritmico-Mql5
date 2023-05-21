//+------------------------------------------------------------------+
//|                              Media Móvil Simple AE Cobertura.mq5 |
//|                                                             Javi |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
// Información del Asesor
//+------------------------------------------------------------------+

#property copyright "Javi"
#property description "Asesor experto que aplica el sistema de media móvil y es provisto como parte del curso de trading algorítmico"
#property link      ""
#property version   "1.00"



//+------------------------------------------------------------------+
// Notas del Asesor
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
// AE Enumeraciones
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
// Variables Input y Globales
//+------------------------------------------------------------------+
sinput group                                   "### AE AJUSTES GENERALES ###"
input ulong                                    MagicNumber = 101;

sinput group                                   "### AE AJUSTES MEDIA MÓVIL ###"
input int                                      PeriodoMA = 30;
input ENUM_MA_METHOD                           MetodoMA = MODE_SMA;
input int                                      ShiftMA = 0;
input ENUM_APPLIED_PRICE                       PrecioMA = PRICE_CLOSE;

sinput group                                   "### GESTIÓN MONETARIA ###"
input double                                   VolumenFijo = 0.1;

sinput group                                   "### GESTIÓN DE POSICIONES ###"
input ushort                                   SLPuntosFijos = 0;
input ushort                                   SLPuntosFijosMA = 0;
input ushort                                   TPPuntosFijos = 0;
input ushort                                   TSLPuntosFijos = 0;
input ushort                                   BEPuntosFijos = 0;


datetime glTiempoBarraApertura;
int ManejadorMA;


 

//+------------------------------------------------------------------+
// Procesadores de Eventos
//+------------------------------------------------------------------+


int OnInit()
 {

  
 
   glTiempoBarraApertura = D'1971.01.01 00:00';
   
   ManejadorMA = MA_Init(PeriodoMA, ShiftMA, MetodoMA, PrecioMA);
   
   if(ManejadorMA == -1)
   {
    return(INIT_FAILED);
   }
      
   return(INIT_SUCCEEDED);
 }
 
void OnDeinit(const int reason)
 {
   Print("Asesor eliminado");
   
 }
 
void OnTick()
{
  

  //------------------------//
  // CONTROL DE NUEVA BARRA //
  //------------------------//

  bool nuevaBarra = false;
  
  //Comprobación de nueva barra
  if(glTiempoBarraApertura != iTime(_Symbol, PERIOD_CURRENT, 0))
  {
    nuevaBarra = true;
    glTiempoBarraApertura = iTime(_Symbol, PERIOD_CURRENT, 0);
  }
  
  if(nuevaBarra == true)
  {
  
  

  //------------------------//
  // PRECIO E INDICADORES   //
  //------------------------//
  
  //Precio
  double cierre1 = Close(1);
  double cierre2 = Close(2);
   
  
  
  
  
  //Normalización a tick size (tamaño del tick)
  double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);        
  cierre1 = round(cierre1/tickSize) * tickSize;     
  cierre2 = round(cierre2/tickSize) * tickSize;     
  
  // Media Móvil (MA)
  double ma1 = ma(ManejadorMA,1);
  double ma2 = ma(ManejadorMA,2);
 
  
  
  
  //------------------------//
  // CIERRE DE POSICIONES   //
  //------------------------//
  
  // Señal de cierre && Cierre de posiciones
  
  string exitSignal = MA_ExitSignal(cierre1,cierre2,ma1,ma2);
  
  if(exitSignal == "CIERRE_LARGO" || exitSignal == "CIERRE_CORTO")
 {
   CierrePosiciones(MagicNumber, exitSignal);
 }
 
 
 
 
  Sleep(1000);
  
  
  //------------------------//
  // COLOCACIÓN DE ÓRDENES  //
  //------------------------//
  
 
   
 
  
  
  // Señal de entrada && colocación de posiciones
  string entrySignal = MA_EntrySignal(cierre1,cierre2,ma1,ma2);
  Comment("A.E #", MagicNumber," | ", exitSignal," | ",entrySignal," | ", "SEÑALES DETECTADAS");
  
  if((entrySignal == "LARGO" || entrySignal == "CORTO") && RevisionPosicionesColocadas(MagicNumber) == false)
  {
     ulong ticket = AperturaTrade(entrySignal, MagicNumber, VolumenFijo);
     
     //Modificación de SL y TP
     if(ticket > 0)
     {
      double stopLoss = CalculaStopLoss(entrySignal, SLPuntosFijos, SLPuntosFijosMA, ma1);
      double takeProfit = CalculaTakeProfit(entrySignal,TPPuntosFijos);
      ModificacionPosiciones(ticket, MagicNumber, stopLoss, takeProfit);
     }
     
     
     
  }
 
  
  
  //------------------------//
  // GESTIÓN DE POSICIONES  //
  //------------------------//
  
  
  if(TSLPuntosFijos > 0) TrailingStopLoss(MagicNumber, TSLPuntosFijos);
  if(BEPuntosFijos > 0) BreakEven(MagicNumber,BEPuntosFijos);
  
  }
}

//+------------------------------------------------------------------+
// AE Funciones
//+------------------------------------------------------------------+

//+---------------+// Funciones del Precio //+---------------------+//

double Close(int pShift)
{
  MqlRates barra[];                             // Crea un objeto array del tipo estructura MqlRates
  ArraySetAsSeries(barra,true);                 // Configura nuestro array en serie (La vela actual se copiara en el indice 0, la vela 1 en el indice 1 y así sucesivamente)
  CopyRates(_Symbol,PERIOD_CURRENT,0,3,barra);  // copia el precio de barra 0, 1 y 2 a nuestro array barra

  return barra[pShift].close;                   // Retorna el precio de cierre del objeto barra
}

double Open(int pShift)
{
 MqlRates barra[];                               // Crea un objeto array del tipo estructura MqlRates
 ArraySetAsSeries(barra,true);                   // Configura nuestro array en serie (La vela actual se copiara en el indice 0, la vela 1 en el indice 1 y así sucesivamente)
 CopyRates(_Symbol,PERIOD_CURRENT,0,3,barra);    // copia el precio de barra 0, 1 y 2 a nuestro array barra
                                    
 return barra[pShift].open;                      // Retorna el precio de apertura del objeto barra
}


//+---------------+// Funciones de la Media Móvil //+---------------------+//

int MA_Init(int pPeriodoMA, int pShiftMA, ENUM_MA_METHOD pMetodoMA, ENUM_APPLIED_PRICE pPrecioMA)
{
  //En caso de error al iniciar el MA, GetLastError() nos dará el código de error y los almacenará en _lastError
  //ResetLastError cambiará el valor de la variable :Lasterror a 0 
  ResetLastError();
  
  // El manejador es un identificador único para el indicador, se utiliza para todas las acciones relacionadas con este, como obtener datos o eliminarlo
  int Manejador = iMA(_Symbol, PERIOD_CURRENT,pPeriodoMA, pShiftMA, pMetodoMA, pPrecioMA);
  
  if(Manejador == INVALID_HANDLE)
  {
    return -1;
    Print("Alerta: Ha habido un error creando el Manejador MA: ",GetLastError());
  }
  
  
  Print("Manejador se ha creado con éxito");
  return Manejador;
}
  
  
  double ma(int pManejadorMA, int pShift)
  {
    ResetLastError();
    
    // Creamos un array que llenaremos con los precios del indicador
    double ma[];
    ArraySetAsSeries(ma,true);
    
    // llenamos el array con los 3 valores mas recientes del MA
    bool resultado = CopyBuffer(pManejadorMA,0,0,3,ma);
    if(resultado == false)
    {
    Print(" Error al copiar datos: ", GetLastError());
    }
    
    
    // Preguntar por el valor del indicador almacenado en pShift
    double valorMA = ma[pShift];
    
    // Normalizamos el valor a los digitos de nuestro simbolo
    valorMA = NormalizeDouble(valorMA,_Digits);
    
    return valorMA;
  }
  
  
  
 string MA_EntrySignal(double pPrecio1, double pPrecio2, double pMA1, double pMA2)
 {
   string str = "";
   string valores;
   
   if(pPrecio1 > pMA1 && pPrecio2 <= pMA2)
   {
     str = "LARGO";
   }
   else if(pPrecio1 < pMA1 && pPrecio2 >= pMA2)
   {
     str = "CORTO";
   }
   else
   {
     str = "NO_OPERAR";
   }
   
   
   StringConcatenate(valores,"MA 1: ", DoubleToString(pMA1,_Digits), " | ", "MA 2: ", DoubleToString(pMA2,_Digits)," | "
                     "Cierre 1: ", DoubleToString(pPrecio1,_Digits)," | ", "Cierre 2: ",DoubleToString(pPrecio2,_Digits));
   Print("Valores del precio e indicadores: ", valores);
   
   return str;
 }
 
 
 string MA_ExitSignal(double pPrecio1, double pPrecio2, double pMA1, double pMA2)
 {
   string str = "";
   string valores;
   
   if(pPrecio1 > pMA1 && pPrecio2 <= pMA2)
   {
     str = "CIERRE_CORTO";
   }
   else if(pPrecio1 < pMA1 && pPrecio2 >= pMA2)
   {
     str = "CIERRE_LARGO";
   }
   else
   {
     str = "NO_CIERRE";
   }
   
   
   StringConcatenate(valores,"MA 1: ", DoubleToString(pMA1,_Digits), "|", "MA 2: ", DoubleToString(pMA2,_Digits),"|"
                     "Cierre 1: ", DoubleToString(pPrecio1,_Digits),"|", "Cierre 2: ",DoubleToString(pPrecio2,_Digits));
   Print("Valores del precio e indicadores: ", valores);
   
   return str;
 }
 
  
 
  

//+---------------+// Funciones de las Bandas de Bollinger //+---------------------+//

int BB_Init(int pPeriodoBB, int pShiftBB, double pDesviacionBB, ENUM_APPLIED_PRICE pPrecioBB)
{
  //En caso de error al iniciar las BB, GetLastError() nos dará el código de error y los almacenará en _lastError
  //ResetLastError cambiará el valor de la variable :Lasterror a 0 
  ResetLastError();
  
  // El manejador es un identificador único para el indicador, se utiliza para todas las acciones relacionadas con este, como obtener datos o eliminarlo
  int Manejador = iBands(_Symbol, PERIOD_CURRENT,pPeriodoBB, pShiftBB, pDesviacionBB, pPrecioBB);
  
  if(Manejador == INVALID_HANDLE)
  {
    return -1;
    Print("Alerta: Ha habido un error creando el Manejador BB: ",GetLastError());
  }
  
  
  Print("Manejador del indicador BB se ha creado con éxito");
  return Manejador;
  
  }
  
  
  double BB(int pManejadorBB,int pBuffer, int pShift)
  {
    ResetLastError();
    
    // Creamos ubn array que llenaremos con los precios del indicador
    double BB[];
    ArraySetAsSeries(BB,true);
    
    // llenamos el array con los 3 valores mas recientes del BB
    bool resultado = CopyBuffer(pManejadorBB,pBuffer,0,3,BB);
    if(resultado == false){
    Print(" Error al copiar datos: ", GetLastError());}
    
    
    // Preguntar por el valor del indicador almacenado en pShift
    double valorBB = BB[pShift];
    
    // Normalizamos el valor a los digitos de nuestro simbolo
    valorBB = NormalizeDouble(valorBB,_Digits);
    
    return valorBB;
  }
  
  
  

//+---------------+// Funciones para la colocación de Órdenes //+---------------------+//  
 
 
 ulong AperturaTrade( string pEntrySignal, ulong pMagicNumber, double pVolumenFijo)
 {
    //Compramos al ASK pero cerramos al BID
    //Vendemos al BID pero cerramos al ASK
    
    
    double precioAsk = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
    double precioBid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
    double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
        
    //Precio debe ser normalizado a digitos o tamaño del tick
    precioAsk = round(precioAsk/tickSize) * tickSize;
    precioBid = round(precioBid/tickSize) * tickSize;    
    
    string comentario = pEntrySignal + " | " + _Symbol + " | " + string(pMagicNumber);
    
    //Declaración e inicialización de los objetos solicitud y resultado
    MqlTradeRequest solicitud = {};
    MqlTradeResult resultado  = {};
 
    if(pEntrySignal == "LARGO")
    {
    //Parámetro de la solicitud
        
    solicitud.action    = TRADE_ACTION_DEAL;
    solicitud.symbol    = _Symbol;
    solicitud.volume    = pVolumenFijo;
    solicitud.type      = ORDER_TYPE_BUY;
    solicitud.price     = precioAsk;
    solicitud.deviation = 10;
    solicitud.magic     = pMagicNumber;
    solicitud.comment   = comentario;
        
    //Envio de la solicitud
     if(!OrderSend(solicitud, resultado))
       Print("Error en el envio de la orden: ",GetLastError());    //Si la solicitud no se envia, imprimimos código de error
    
    //Información de la operación
     Print("Abierta ",solicitud.symbol," ",pEntrySignal," orden #", resultado.order,":",resultado.retcode,", Volumen: ",resultado.volume,", Precio: ", DoubleToString(precioAsk,_Digits));
    }
    
    else if(pEntrySignal == "CORTO")
    {
    //Parámetro de la solicitud
     solicitud.action    = TRADE_ACTION_DEAL;
    solicitud.symbol    = _Symbol;
    solicitud.volume    = pVolumenFijo;
    solicitud.type      = ORDER_TYPE_SELL;
    solicitud.price     = precioAsk;
    solicitud.deviation = 10;
    solicitud.magic     = pMagicNumber;
    solicitud.comment   = comentario;
        
    //Envio de la solicitud
     if(!OrderSend(solicitud, resultado))
       Print("Error en el envio de la orden: ",GetLastError());    //Si la solicitud no se envia, imprimimos código de error
    
    //Información de la operación
     Print("Abierta ",solicitud.symbol," ",pEntrySignal," orden #", resultado.order,":",resultado.retcode,", Volumen: ",resultado.volume,", Precio: ", DoubleToString(precioBid,_Digits));
    }
    
    if(resultado.retcode == TRADE_RETCODE_DONE || resultado.retcode == TRADE_RETCODE_DONE_PARTIAL || resultado.retcode == TRADE_RETCODE_PLACED || resultado.retcode  == TRADE_RETCODE_NO_CHANGES)
    {
      return resultado.order;
    }
    else return 0;
 }
 
 void ModificacionPosiciones(ulong pTicket, ulong pMagicNumber,double pSLPrecio, double pTPPrecio)
 {
   double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   
   MqlTradeRequest solicitud  = {};
   MqlTradeResult resultado   = {};
   
   solicitud.action = TRADE_ACTION_SLTP;
   solicitud.position = pTicket;
   solicitud.symbol = _Symbol;
   solicitud.sl = round(pSLPrecio/tickSize) * tickSize;
   solicitud.tp = round(pTPPrecio/tickSize) * tickSize;
   solicitud.comment = "MOD. " + " | " + _Symbol + " | " + string(pMagicNumber) + ", SL: " + DoubleToString(solicitud.sl,_Digits) + ", TP: " + DoubleToString(solicitud.tp,_Digits);
   
   if(solicitud.sl > 0 || solicitud.tp > 0)
   {
     Sleep(1000);
     bool send = OrderSend(solicitud, resultado);
     Print(resultado.comment);
     
     if(!send)
     {
       Print("Error de modificación Ordersend: ",GetLastError());
       Sleep(1000);
       
       send = OrderSend(solicitud, resultado);     
       Print(resultado.comment);
       Print("2º intento error de modificación Ordersend: ", GetLastError());
     }
   }
   
 
 }
 
 
 
 
 
 bool RevisionPosicionesColocadas(ulong pMagicNumber)
 {
   bool posicionColocada = false;
   for(int i = PositionsTotal() -1; i >= 0; i--)
   {
     ulong posicionTicket = PositionGetTicket(i);
     PositionSelectByTicket(posicionTicket);
     
     ulong posicionMagico = PositionGetInteger(POSITION_MAGIC);
     if(posicionMagico == pMagicNumber)
     {
       posicionColocada = true;
       break;
     }
   }
   
   
   return posicionColocada;
 }
 
 
 void CierrePosiciones(ulong pMagicNumber, string pExitSignal)
 {
    //Declaración e inicialización de los objetos solicitud y resultado
    MqlTradeRequest solicitud = {};
    MqlTradeResult resultado  = {};
    
     for(int i = PositionsTotal() -1; i >= 0; i--)
     {
       //Resetear los valores de objetos solicitud y resultados
       ZeroMemory(solicitud);
       ZeroMemory(resultado);
       
       ulong posicionTicket = PositionGetTicket(i);
       PositionSelectByTicket(posicionTicket);
     
       ulong posicionMagico = PositionGetInteger(POSITION_MAGIC);
       ulong posicionTipo = PositionGetInteger(POSITION_TYPE);
       
       if(posicionMagico == pMagicNumber && pExitSignal == "CIERRE_LARGO" && posicionTipo == POSITION_TYPE_BUY)
       {
         solicitud.action = TRADE_ACTION_DEAL;
         solicitud.type = ORDER_TYPE_SELL;
         solicitud.symbol = _Symbol;
         solicitud.position = posicionTicket;
         solicitud.volume = PositionGetDouble(POSITION_VOLUME);
         solicitud.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         solicitud.deviation = 10;
         
         bool sent = OrderSend(solicitud, resultado);
         if(sent == true)(Print("Posición #",posicionTicket," cerrada"));
       } 
         else if(posicionMagico == pMagicNumber && pExitSignal == "CIERRE_CORTO" && posicionTipo == POSITION_TYPE_SELL)
       {
         solicitud.action = TRADE_ACTION_DEAL;
         solicitud.type = ORDER_TYPE_BUY;
         solicitud.symbol = _Symbol;
         solicitud.position = posicionTicket;
         solicitud.volume = PositionGetDouble(POSITION_VOLUME);
         solicitud.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         solicitud.deviation = 10;
         
         bool sent = OrderSend(solicitud, resultado);
         if(sent == true)(Print("Posición #",posicionTicket," cerrada"));
       }
     
     
     }
 }
 
 
 //+---------------+// Funciones para la gestión de posiciones  //+---------------------+//
 
 double CalculaStopLoss(string pEntrySignal, int pSLPuntosFijos, int pSLPuntosFijosMA, double pMA)
{
   double stopLoss = 0.0;
   double precioAsk = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double precioBid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   
 
  if(pEntrySignal == "LARGO")
  {
   if(pSLPuntosFijos > 0){
   stopLoss = precioBid - (pSLPuntosFijos * _Point);}
   else if(pSLPuntosFijos > 0){
   stopLoss = pMA - (pSLPuntosFijosMA * _Point);}
   
   if(stopLoss > 0) stopLoss = AjusteNivelStopDebajo(precioBid, stopLoss);
  }
  if(pEntrySignal == "CORTO")
  {
   if(pSLPuntosFijos > 0){
   stopLoss = precioAsk + (pSLPuntosFijos * _Point);}
   else if(pSLPuntosFijos > 0){
   stopLoss = pMA + (pSLPuntosFijosMA * _Point);}
   
   if(stopLoss > 0) stopLoss = AjusteNivelStopArriba(precioAsk, stopLoss);
  }
  
  stopLoss = round(stopLoss/tickSize) * tickSize;
  return stopLoss;
 
}
 
  
  double CalculaTakeProfit(string pEntrySignal, int pTPPuntosFijos)
{
   double takeProfit = 0.0;
   double precioAsk = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double precioBid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   
 
  if(pEntrySignal == "LARGO")
  {
   if(pTPPuntosFijos > 0){
   takeProfit = precioBid + (pTPPuntosFijos * _Point);}
   
   if(takeProfit > 0) takeProfit = AjusteNivelStopArriba(precioBid, takeProfit);

   
  }
  if(pEntrySignal == "CORTO")
  {
   if(pTPPuntosFijos > 0){
   takeProfit = precioAsk - (pTPPuntosFijos * _Point);}
   
   if(takeProfit > 0) takeProfit = AjusteNivelStopDebajo(precioAsk, takeProfit);

  }
  
  takeProfit = round(takeProfit/tickSize) * tickSize;
  return takeProfit;
 
}
 
void TrailingStopLoss(ulong pNumeroMagico, int pTSLPuntosFijos)
{
  //Declaración e inicialización de los objetos solicitud y resultado
    MqlTradeRequest solicitud = {};
    MqlTradeResult resultado  = {};
    
    for(int i = PositionsTotal() -1; i >= 0; i--)
     {
       //Resetear los valores de objetos solicitud y resultados
       ZeroMemory(solicitud);
       ZeroMemory(resultado);
       
       ulong posicionTicket = PositionGetTicket(i);
       PositionSelectByTicket(posicionTicket);
     
       ulong posicionMagico = PositionGetInteger(POSITION_MAGIC);
       ulong posicionTipo = PositionGetInteger(POSITION_TYPE);
       double stopLossActual = PositionGetDouble(POSITION_SL);
       double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
       double stopLossNuevo;
       
       if(posicionMagico == pNumeroMagico && posicionTipo == POSITION_TYPE_BUY)
       {
         double precioBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         stopLossNuevo = precioBid - (pTSLPuntosFijos * _Point);
         stopLossNuevo = AjusteNivelStopDebajo(precioBid, stopLossNuevo);
         stopLossNuevo = round(stopLossNuevo/tickSize) * tickSize;
         
         
         if(stopLossNuevo > stopLossActual)
         {
           solicitud.action = TRADE_ACTION_SLTP;
           solicitud.position = posicionTicket;
           solicitud.comment = "TSL. " + _Symbol + " | " + string(pNumeroMagico);
           solicitud.sl = stopLossNuevo;
           
           bool sent = OrderSend(solicitud, resultado);
           if(!sent) Print("OrderSend TSL error: ",GetLastError());
         }
               
       }
       else if(posicionMagico == pNumeroMagico && posicionTipo == POSITION_TYPE_SELL)
       {
         double precioAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         stopLossNuevo = precioAsk + (pTSLPuntosFijos * _Point);
         stopLossNuevo = AjusteNivelStopArriba(precioAsk, stopLossNuevo);
         stopLossNuevo = round(stopLossNuevo/tickSize) * tickSize;
        
         if(stopLossNuevo < stopLossActual)
         {
           solicitud.action = TRADE_ACTION_SLTP;
           solicitud.position = posicionTicket;
           solicitud.comment = "TSL. " + _Symbol + " | " + string(pNumeroMagico);
           solicitud.sl = stopLossNuevo;
           
           bool sent = OrderSend(solicitud, resultado);
           if(!sent) Print("OrderSend TSL error: ", GetLastError());
         }
       }
    }
}
void BreakEven(ulong pNumeroMagico, int pBEPuntosFijos)
{
  //Declaración e inicialización de los objetos solicitud y resultado
    MqlTradeRequest solicitud = {};
    MqlTradeResult resultado  = {};
    
    for(int i = PositionsTotal() -1; i >= 0; i--)
     {
       //Resetear los valores de objetos solicitud y resultados
       ZeroMemory(solicitud);
       ZeroMemory(resultado);
       
       ulong posicionTicket = PositionGetTicket(i);
       PositionSelectByTicket(posicionTicket);
     
       ulong posicionMagico = PositionGetInteger(POSITION_MAGIC);
       ulong posicionTipo = PositionGetInteger(POSITION_TYPE);
       double stopLossActual = PositionGetDouble(POSITION_SL);
       double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
       double precioApertura = PositionGetDouble(POSITION_PRICE_OPEN);
       double stopLossNuevo = round(precioApertura/tickSize) * tickSize;
       
       if(posicionMagico == pNumeroMagico && posicionTipo == POSITION_TYPE_BUY)
       {
         double precioBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double BEDistancia = precioApertura + (BEPuntosFijos * _Point);
         
         if(stopLossNuevo > stopLossActual && precioBid > BEDistancia)
         {
           solicitud.action = TRADE_ACTION_SLTP;
           solicitud.position = posicionTicket;
           solicitud.comment = "BE: " + _Symbol + " | " + string(pNumeroMagico);
           solicitud.sl = stopLossNuevo;
           
           bool sent = OrderSend(solicitud, resultado);
           if(!sent) Print("OrderSend BE error: ",GetLastError());
         }
               
       }
       else if(posicionMagico == pNumeroMagico && posicionTipo == POSITION_TYPE_SELL)
       {
         double precioAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double BEDistancia = precioApertura - (BEPuntosFijos * _Point); 
        
         if(stopLossNuevo < stopLossActual && precioAsk < BEDistancia)
         {
           solicitud.action = TRADE_ACTION_SLTP;
           solicitud.position = posicionTicket;
           solicitud.comment = "BE: " + _Symbol + " | " + string(pNumeroMagico);
           solicitud.sl = stopLossNuevo;
           
           bool sent = OrderSend(solicitud, resultado);
           if(!sent) Print("OrderSend BE error: ", GetLastError());
         }
       }
    }
}

// Ajuste de niveles de stops
double AjusteNivelStopArriba(double pPrecioActual, double pPrecioParaAjustar, int pPuntosAdicionales = 3)
{
  double precioAjustado = pPrecioParaAjustar;
  
  long nivelesStop = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
  
  if(nivelesStop > 0)
  {
    double nivelesStopPecio = nivelesStop * _Point; 
    nivelesStopPecio = pPrecioActual + nivelesStopPecio;
    
    double puntosAdicionales = pPuntosAdicionales * _Point;
    
    if(precioAjustado <= nivelesStopPecio + pPuntosAdicionales)
    {
      precioAjustado = nivelesStopPecio + pPuntosAdicionales;
      Print("Precio ajustado por encima de nivel de stop a "+ string(precioAjustado));
    }
  }
  
  return precioAjustado;
}

// Ajuste de niveles de stops
double AjusteNivelStopDebajo(double pPrecioActual, double pPrecioParaAjustar, int pPuntosAdicionales = 3)
{
  double precioAjustado = pPrecioParaAjustar;
  
  long nivelesStop = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
  
  if(nivelesStop > 0)
  {
    double nivelesStopPecio = nivelesStop * _Point; 
    nivelesStopPecio = pPrecioActual - nivelesStopPecio;
    
    double puntosAdicionales = pPuntosAdicionales * _Point;
    
    if(precioAjustado >= nivelesStopPecio - pPuntosAdicionales)
    {
      precioAjustado = nivelesStopPecio - pPuntosAdicionales;
      Print("Precio ajustado por debajo de nivel de stop a "+ string(precioAjustado));
    }
  }
  
  return precioAjustado;
}