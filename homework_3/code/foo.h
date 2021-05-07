#ifndef RADIO_COUNT_TO_LEDS_H
#define RADIO_COUNT_TO_LEDS_H

typedef nx_struct foo_msg {
  nx_uint16_t id;
  nx_uint16_t counter;
} foo_msg_t;

enum {
  AM_FOO_MSG = 6,
};

#endif
