#include "sendAck.h"
#include "Timer.h"

module sendAckC {

  uses {
  /****** INTERFACES *****/
	interface Boot;
	//interfaces for communication
	interface SplitControl;
	interface Packet;
    interface AMSend;
    interface Receive;
    //interface for ack
    interface PacketAcknowledgements;
    //interface for timer
    interface Timer<TMilli> as FirstSensorTimer;
	//interface used to perform sensor reading (to get the value from a sensor)
	interface Read<uint16_t> as DataRead;
  }

} implementation {

  uint8_t counter=0;
  uint8_t rec_id;
  message_t packet;

  void sendReq();
  void sendResp();
  void printMSG(my_msg_t* msg);
  
  
  void printMSG(my_msg_t* msg){
  	dbg_clear("radio_pack", "\t\t type: %hhu \n ", msg->msg_type);
	dbg_clear("radio_pack", "\t\t counter: %hhu \n", msg->msg_counter);
	dbg_clear("radio_pack", "\t\t data: %hu \n", msg->value);
  }
  //***************** Send request function ********************//
  void sendReq() {
	/* This function is called when we want to send a request
	 *
	 * STEPS:
	 * 1. Prepare the msg
	 * 2. Set the ACK flag for the message using the PacketAcknowledgements interface
	 *     (read the docs)
	 * 3. Send an UNICAST message to the correct node
	 */
	 my_msg_t* msg = (my_msg_t*)(call Packet.getPayload(&packet, sizeof(my_msg_t)));
	 if(msg == NULL){
	 	dbgerror("radio_send", "Packet not created.\n");
	 	return;
	 }
	 msg->msg_type = REQ;
	 msg->msg_counter = counter;
	 msg->value=0;
	 dbg("radio_pack","Preparing the REQ message... \n");
	 
	 if(call PacketAcknowledgements.requestAck(&packet) == SUCCESS){
	 	dbg("radio_ack", "Packet ACK request done correctly!\n");
	 	if(call AMSend.send(2, &packet,sizeof(my_msg_t)) == SUCCESS){
	     	dbg("radio_send", "Packet passed to lower layer successfully!\n");
	     	dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
	     	dbg_clear("radio_pack","\t Payload Sent\n" );
		 	printMSG(msg);
  		}
  	}
 }        

  //****************** Task send response *****************//
  void sendResp() {
  	/* This function is called when we receive the REQ message.
  	 * Nothing to do here. 
  	 * `call Read.read()` reads from the fake sensor.
  	 * When the reading is done it raise the event read done.
  	 */
	call DataRead.read();
  }

  //***************** Boot interface ********************//
  event void Boot.booted() {
	dbg("boot","Application booted on node %u.\n",TOS_NODE_ID);
	call SplitControl.start();
  }

  //***************** SplitControl interface ********************//
  event void SplitControl.startDone(error_t err){
    if(err == SUCCESS) {
    	dbg("radio", "Radio on!\n");
    	if (TOS_NODE_ID > 0){
			if(TOS_NODE_ID == 1){
				call FirstSensorTimer.startPeriodic( 1000 );
			}
  		}
  	}
    else{
		dbgerror("radio", "Radio not starting well!\n");
		call SplitControl.start();
    }
  }
  
  event void SplitControl.stopDone(error_t err){
    dbg("radio", "Radio off\n");
  }

  //***************** MilliTimer interface ********************//
  event void FirstSensorTimer.fired() {
	/* This event is triggered every time the timer fires.
	 * When the timer fires, we send a request
	 */
	 
	 sendReq();
	 counter++;
  }
  

  //********************* AMSend interface ****************//
  event void AMSend.sendDone(message_t* buf,error_t err) {
	/* This event is triggered when a message is sent 
	 *
	 * STEPS:
	 * 1. Check if the packet is sent
	 * 2. Check if the ACK is received (read the docs)
	 * 2a. If yes, stop the timer. The program is done for mote 1
	 * 2b. Otherwise, send again the request
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */
	 //step #1
	  if (&packet == buf && err == SUCCESS) {
      	dbg("radio_send", "Packet sent...");
      	dbg_clear("radio_send", " at time %s \n", sim_time_string());
      	 //step #2
      	 if(call PacketAcknowledgements.wasAcked(buf)){
      	 	dbg("radio_ack", "Packet acked\n");
      	 	//stop the timer
      	 	//step #2a
      	 	dbg("radio_send", "Stopping timer.....\n");
      	 	call FirstSensorTimer.stop();
      	 	
      	 }
      	 else{
      	 	dbgerror("radio_ack", "Packet not acked!\n\n");
      	 	if(TOS_NODE_ID ==2){
      	 		//step #2b
      	 		dbg("radio_send", "Resending the message.\n");
      	 		if(call PacketAcknowledgements.requestAck(&packet) == SUCCESS){
	 				dbg("radio_ack", "Packet ACK request done correctly!\n");
	 				if(call AMSend.send(1, &packet,sizeof(my_msg_t)) == SUCCESS){
	     				dbg("radio_send", "Packet passed to lower layer successfully!\n"); 
  					}
  				}
  			}
      	 }
      }
      else{
      	dbgerror("radio_send", "Send done error!\n");
      }
  }

  //***************************** Receive interface *****************//
  event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {
	/* This event is triggered when a message is received 
	 *
	 * STEPS:
	 * 1. Read the content of the message
	 * 2. Check if the type is request (REQ)
	 * 3. If a request is received, send the response
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */
	 if (len != sizeof(my_msg_t)) {
	 	return buf;
	 }
	 else {
	 	my_msg_t* msg = (my_msg_t*)payload;
      	dbg("radio_rec", "Received packet at time %s\n", sim_time_string());
      	dbg("radio_pack"," Payload length %hhu \n", call Packet.payloadLength( buf ));
      	dbg("radio_pack", ">>>Pack \n");
      	dbg_clear("radio_pack","\t\t Payload Received\n" );
      	printMSG(msg);
	  	//STEP #2
	  	if(msg->msg_type == REQ){
	  		rec_id= msg->msg_counter;
	  		dbg("radio_rec", "Received REQ packet with counter: %hhu.\n",rec_id);
	  		sendResp();
	  	}
	  	else if (msg->msg_type == RESP){
	  		dbg("radio_rec", "Received RESP packet\n");
	  	}
	  	else{
	  		dbgerror("radio_rec", "Received packet with wrong filed\n");
	  	}
     
      return buf;
    }
    {
      dbgerror("radio_rec", "Receiving error \n");
    }

  }
  
  //************************* Read interface **********************//
	event void DataRead.readDone(error_t result, uint16_t data) {
		/* This event is triggered when the fake sensor finish to read (after a Read.read()) 
		 *
		 * STEPS:
		 * 1. Prepare the response (RESP)
		 * 2. Send back (with a unicast message) the response
		 * X. Use debug statement showing what's happening (i.e. message fields)
		 */
		 my_msg_t* msg = (my_msg_t*)(call Packet.getPayload(&packet, sizeof(my_msg_t)));
	 	if(msg == NULL){
	 		dbgerror("radio_send", "Packet not created.\n");
	 		return;
	 	}
	 	msg->msg_type = RESP;
	 	msg->msg_counter = rec_id;
	 	msg->value= data;
	 	dbg("radio_pack","Preparing the RESP message... \n");
	 
	 	if(call PacketAcknowledgements.requestAck(&packet) == SUCCESS){
	 		dbg("radio_ack", "Packet ACK request done correctly!\n");
	 		if(call AMSend.send(1, &packet,sizeof(my_msg_t)) == SUCCESS){
	     		dbg("radio_send", "Packet passed to lower layer successfully!\n");
	     		dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
	     		dbg_clear("radio_pack","\t Payload Sent\n" );
				printMSG(msg);
  			}
  		}
  	}
}
