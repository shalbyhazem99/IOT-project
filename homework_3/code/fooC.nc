#include "Timer.h"
#include "foo.h"
#include"printf.h"

module fooC @safe()
{
	uses
	{
		interface Leds;
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
	bool led0 = FALSE;
	bool led1 = FALSE;
	bool led2 = FALSE;

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
			if (TOS_NODE_ID == 1)
			{
				// mote 1
				call MilliTimer.startPeriodic(1000);	//1Hz
			}
			else if (TOS_NODE_ID == 2)
			{
				//mote 2
				call MilliTimer.startPeriodic(333);	// 3Hz
			}
			else
			{
				//mote 3
				call MilliTimer.startPeriodic(200);	//5Hz
			}
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
			counter++;
			if (rcm->counter % 10 == 0)
			{
				led0 = FALSE;
				led1 = FALSE;
				led2 = FALSE;
				call Leds.set(0);
			}
			else if (rcm->id == 1)
			{
				led0 = !led0;
				call Leds.led0Toggle();
			}
			else if (rcm->id == 2)
			{
				led1 = !led1;
				call Leds.led1Toggle();
			}
			else
			{
				led2 = !led2;
				call Leds.led2Toggle();
			}
			if (TOS_NODE_ID == 2)
			{
				printf("ID: %d, COUNT: %d, STATUS: %d%d%d\n", rcm->id , rcm->counter, led2, led1, led0);
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
