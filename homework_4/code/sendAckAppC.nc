#include "sendAck.h"

configuration sendAckAppC {}

implementation {
/****** COMPONENTS *****/
  components MainC, sendAckC as App;
  components new TimerMilliC() as first_t;
  components new FakeSensorC();
  components ActiveMessageC;
  components new AMSenderC(AM_SEND_MSG);
  components new AMReceiverC(AM_SEND_MSG);

/****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;
  //Radio Control
  App.SplitControl -> ActiveMessageC;
  App.PacketAcknowledgements -> ActiveMessageC;
  App.AMSend -> AMSenderC;
  App.Packet -> AMSenderC;
  App.Receive -> AMReceiverC;
  //Timer interface
  App.FirstSensorTimer -> first_t;
  //Fake Sensor read
  App.DataRead -> FakeSensorC;
}

