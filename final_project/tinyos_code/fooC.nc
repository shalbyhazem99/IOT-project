#include "Timer.h"
#include "foo.h"
#include"printf.h"
#define N 10

module fooC @safe()
{
	uses
	{
		interface Boot;
		interface Receive;
		interface AMSend;
		interface Timer<TMilli> as MilliTimer;
		interface SplitControl as AMControl;
		interface Packet;
	}
}
implementation
{

	message_t packet;

	bool locked;
	uint16_t counter = 0;
	uint16_t last_msg_count[N];
	uint16_t cons_msg_count[N];

	event void Boot.booted()
	{
		call AMControl.start();
		printf("Booted %d\n",TOS_NODE_ID);
		printfflush();
	}

	event void AMControl.startDone(error_t err)
	{
		if (err == SUCCESS)
		{
			call MilliTimer.startPeriodic(500);	//2Hz
		}
		else
		{
			call AMControl.start();
		}
	}

	event void AMControl.stopDone(error_t err)
	{
		// do nothing
	}

	event void MilliTimer.fired()
	{
		//print counter the led value
		dbg("RadioCountToLedsC", "RadioCountToLedsC: timer fired, counter is %hu.\n", counter);
		if (locked)
		{
			return;
		}
		else
		{
			foo_msg_t *rcm = (foo_msg_t*) call Packet.getPayload(&packet, sizeof(foo_msg_t));
			if (rcm == NULL)
			{
				return;
			}
			rcm->id = TOS_NODE_ID;
			rcm->counter = counter;
			if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(foo_msg_t)) == SUCCESS)
			{
				dbg("RadioCountToLedsC", "RadioCountToLedsC: packet sent.\n", counter);
				locked = TRUE;
				counter++;
			}
		}
	}

	event message_t *Receive.receive(message_t *bufPtr,
		void *payload, uint8_t len)
	{
		dbg("RadioCountToLedsC", "Received packet of length %hhu.\n", len);
		if (len != sizeof(foo_msg_t))
		{
			return bufPtr;
		}
		else
		{
			foo_msg_t *rcm = (foo_msg_t*) payload;
			
			if(cons_msg_count[rcm->id-1]==0 || last_msg_count[rcm->id-1] +1 == rcm->counter){ //reciving consecutive message
				last_msg_count[rcm->id-1]++;
				cons_msg_count[rcm->id-1]++;
			}
			else if(last_msg_count[rcm->id-1] +1 < rcm->counter){ //one or more message has not been sent
				last_msg_count[rcm->id-1]=rcm->counter;
				cons_msg_count[rcm->id-1]=1;
			}
			
			if(cons_msg_count[rcm->id-1] ==10){
				cons_msg_count[rcm->id-1]=0;
				//send notification to node-red
				printf("{\"ALARM\":{\"id_first_mote\":%d,\"id_second_mote\":%d}}\n",TOS_NODE_ID, rcm->id);
				printfflush();
			}
			return bufPtr;
		}
	}

	event void AMSend.sendDone(message_t *bufPtr, error_t error)
	{
		if (&packet == bufPtr)
		{
			locked = FALSE;
		}
	}
}
