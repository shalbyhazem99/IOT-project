#define NEW_PRINTF_SEMANTICS
#include "foo.h"
#include "printf.h"

configuration fooAppC {}
implementation {
  components MainC, fooC as App;
  components SerialPrintfC;
  components SerialStartC;
  components new AMSenderC(AM_FOO_MSG);
  components new AMReceiverC(AM_FOO_MSG);
  components new TimerMilliC();
  components ActiveMessageC;
  
  App.Boot -> MainC.Boot;
  
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;
  App.AMControl -> ActiveMessageC;
  App.MilliTimer -> TimerMilliC;
  App.Packet -> AMSenderC;
}


