#ifndef DEVICES_TIMER_H
#define DEVICES_TIMER_H

#include <round.h>
#include <stdint.h>
#include <list.h>

/* Number of timer interrupts per second. */
#define TIMER_FREQ 100

/* ADD ALARM: structure declaration for the sleep_list */
struct sleeping_threads
{
  struct thread *threadID;
  uint64_t wakeup_time;
  struct list_elem elem1;
};



void timer_init (void);
void timer_calibrate (void);

int64_t timer_ticks (void);
int64_t timer_elapsed (int64_t);

/* Sleep and yield the CPU to other threads. */
void timer_sleep (int64_t ticks);
void timer_msleep (int64_t milliseconds);
void timer_usleep (int64_t microseconds);
void timer_nsleep (int64_t nanoseconds);

/* Busy waits. */
void timer_mdelay (int64_t milliseconds);
void timer_udelay (int64_t microseconds);
void timer_ndelay (int64_t nanoseconds);

void timer_print_stats (void);

void init_f_value();
__inline__ int convert_to_fixed_point(int n);
__inline__ int covert_to_integer(int x);
__inline__ int covert_to_integer_round(int x);
__inline__ int add_fixed_point(int x, int y);
__inline__ int subtract_fixed_point(int x, int y);
__inline__ int add_fixed_and_integer(int x, int n);
__inline__ int sub_fixed_and_integer(int x, int n);
__inline__ int multiply_fixed_point(int x, int y);
__inline__ int multiply_fixed_and_integer(int x, int n);
__inline__ int divide_fixed_point(int x, int y);
__inline__ int divide_fixed_and_integer(int x, int n);

#endif /* devices/timer.h */
