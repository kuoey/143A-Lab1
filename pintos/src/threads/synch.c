/* This file is derived from source code for the Nachos
   instructional operating system.  The Nachos copyright notice
   is reproduced in full below. */

/* Copyright (c) 1992-1996 The Regents of the University of California.
   All rights reserved.
   Permission to use, copy, modify, and distribute this software
   and its documentation for any purpose, without fee, and
   without written agreement is hereby granted, provided that the
   above copyright notice and the following two paragraphs appear
   in all copies of this software.
   IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO
   ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR
   CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE
   AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF CALIFORNIA
   HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
   THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY
   WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
   WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
   PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS ON AN "AS IS"
   BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
   PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
   MODIFICATIONS.
*/

#include "threads/synch.h"
#include <stdio.h>
#include <string.h>
#include "threads/interrupt.h"
#include "threads/thread.h"
#include "threads/fixed-point.h"

/* Initializes semaphore SEMA to VALUE.  A semaphore is a
   nonnegative integer along with two atomic operators for
   manipulating it:
   - down or "P": wait for the value to become positive, then
     decrement it.
   - up or "V": increment the value (and wake up one waiting
     thread, if any). */
void
sema_init (struct semaphore *sema, unsigned value) 
{
  ASSERT (sema != NULL);

  sema->value = value;
  list_init (&sema->waiters);
}

/* ADD PRIORITY: func to compare priorities of two waiting threads on a semaphore */
static bool threadPrioCompare(const struct list_elem *t1,
                             const struct list_elem *t2, void *aux UNUSED)
{ 
  const struct thread *tPointer1 = list_entry (t1, struct thread, elem);
  const struct thread *tPointer2 = list_entry (t2, struct thread, elem);
  if(tPointer1->priority < tPointer2->priority){
    return true;
  }
  else{
    return false;
  }
}


/* Down or "P" operation on a semaphore.  Waits for SEMA's value
   to become positive and then atomically decrements it.
   This function may sleep, so it must not be called within an
   interrupt handler.  This function may be called with
   interrupts disabled, but if it sleeps then the l scheduled
   thread will probably turn interrupts back on. */
void
sema_down (struct semaphore *sema) 
{
  enum intr_level old_level;

  ASSERT (sema != NULL);
  ASSERT (!intr_context ());

  old_level = intr_disable ();
  while (sema->value == 0) 
    {
      list_push_back (&sema->waiters, &thread_current ()->elem);
      thread_block ();
    }
  sema->value--;
  intr_set_level (old_level);
}

/* Down or "P" operation on a semaphore, but only if the
   semaphore is not already 0.  Returns true if the semaphore is
   decremented, false otherwise.
   This function may be called from an interrupt handler. */
bool
sema_try_down (struct semaphore *sema) 
{
  enum intr_level old_level;
  bool success;

  ASSERT (sema != NULL);

  old_level = intr_disable ();
  if (sema->value > 0) 
    {
      sema->value--;
      success = true; 
    }
  else
    success = false;
  intr_set_level (old_level);

  return success;
}

/* Up or "V" operation on a semaphore.  Increments SEMA's value
   and wakes up one thread of those waiting for SEMA, if any.
   This function may be called from an interrupt handler. */
void
sema_up (struct semaphore *sema) 
{
  enum intr_level old_level;
  //(ADDED) used to deal with prio donation below
  struct list_elem *max_prio_sema;
  struct thread *freed_thread = NULL;
  ///////////////////////////

  ASSERT (sema != NULL);

  old_level = intr_disable ();
  if (!list_empty (&sema->waiters)) 
  {
    //(ADDED) wakes up the thread with the highest prio that is waiting on the semaphore (lines 126 -129)
    //thread_unblock (list_entry (list_pop_front (&sema->waiters), struct thread, elem));
    max_prio_sema = list_max (&sema->waiters,threadPrioCompare,0);
    list_remove(max_prio_sema);
    freed_thread = list_entry(max_prio_sema,struct thread,elem);
    thread_unblock (freed_thread);
  }
  sema->value++;
  intr_set_level (old_level);

  if(old_level == INTR_ON && freed_thread!=NULL) {
    if(thread_current()->priority < freed_thread->priority)
      thread_yield ();
  }
}

static void sema_test_helper (void *sema_);

/* Self-test for semaphores that makes control "ping-pong"
   between a pair of threads.  Insert calls to printf() to see
   what's going on. */
void
sema_self_test (void) 
{
  struct semaphore sema[2];
  int i;

  printf ("Testing semaphores...");
  sema_init (&sema[0], 0);
  sema_init (&sema[1], 0);
  thread_create ("sema-test", PRI_DEFAULT, sema_test_helper, &sema);
  for (i = 0; i < 10; i++) 
    {
      sema_up (&sema[0]);
      sema_down (&sema[1]);
    }
  printf ("done.\n");
}

/* Thread function used by sema_self_test(). */
static void
sema_test_helper (void *sema_) 
{
  struct semaphore *sema = sema_;
  int i;

  for (i = 0; i < 10; i++) 
    {
      sema_down (&sema[0]);
      sema_up (&sema[1]);
    }
}

/* Initializes LOCK.  A lock can be held by at most a single
   thread at any given time.  Our locks are not "recursive", that
   is, it is an error for the thread currently holding a lock to
   try to acquire that lock.
   A lock is a specialization of a semaphore with an initial
   value of 1.  The difference between a lock and such a
   semaphore is twofold.  First, a semaphore can have a value
   greater than 1, but a lock can only be owned by a single
   thread at a time.  Second, a semaphore does not have an owner,
   meaning that one thread can "down" the semaphore and then
   another one "up" it, but with a lock the same thread must both
   acquire and release it.  When these restrictions prove
   onerous, it's a good sign that a semaphore should be used,
   instead of a lock. */
void
lock_init (struct lock *lock)
{
  ASSERT (lock != NULL);

  lock->holder = NULL;
  sema_init (&lock->semaphore, 1);
}

//(ADDED) this method compares the max_priorities of locks (should probably move 
//to a file with all compares)
static bool lockPrioCompare(const struct list_elem *l1,
                             const struct list_elem *l2, void *aux UNUSED)
{
  const struct lock *lPointer1 = list_entry (l1, struct lock, elem);
  const struct lock *lPointer2 = list_entry (l2, struct lock, elem);
  if(lPointer1->max_priority > lPointer2->max_priority) {
    return true;
  }
  else {
    return false;
  }
}


/* Acquires LOCK, sleeping until it becomes available if
   necessary.  The lock must not already be held by the current
   thread.
   This function may sleep, so it must not be called within an
   interrupt handler.  This function may be called with
   interrupts disabled, but interrupts will be turned back on if
   we need to sleep. */
void
lock_acquire (struct lock *lock)
{
  //all asserts were given
  ASSERT (lock != NULL);
  ASSERT (!intr_context ());
  ASSERT (!lock_held_by_current_thread (lock));
  
  //(ADDED) Deals with prio donation (lines 229-254)
  enum intr_level old_level;
  old_level = intr_disable ();
  if(!thread_mlfqs && lock->holder != NULL)
  {
    struct thread *l_holder = lock->holder;
    struct lock * lock_copy = lock;
    int curr_prio = thread_get_priority();
  
    while(lock_copy != NULL){ 
        l_holder = lock_copy->holder;
        if( l_holder->priority < curr_prio)
        {
          l_holder->priority = curr_prio;
          lock_copy->max_priority = curr_prio;
        }
        lock_copy = l_holder->wait_on_lock;
    } 
  }

  thread_current()->wait_on_lock = lock; //I'm waiting on this lock
  intr_set_level (old_level);

  sema_down (&lock->semaphore);          //lock acquired
  lock->holder = thread_current ();      //Now I'm the owner of this lock
  thread_current()->wait_on_lock = NULL; //and now no more waiting for this lock
  list_insert_ordered(&(thread_current()->locks_held), &lock->elem, lockPrioCompare,NULL);
  lock->max_priority = thread_get_priority();

}

/* Tries to acquires LOCK and returns true if successful or false
   on failure.  The lock must not already be held by the current
   thread.
   This function will not sleep, so it may be called within an
   interrupt handler. */
bool
lock_try_acquire (struct lock *lock)
{
  bool success;

  ASSERT (lock != NULL);
  ASSERT (!lock_held_by_current_thread (lock));

  success = sema_try_down (&lock->semaphore);
  if (success)
    lock->holder = thread_current ();
  return success;
}

/* Releases LOCK, which must be owned by the current thread.
   An interrupt handler cannot acquire a lock, so it does not
   make sense to try to release a lock within an interrupt
   handler. */
void
lock_release (struct lock *lock) 
{
  // asserts were given
  ASSERT (lock != NULL);
  ASSERT (lock_held_by_current_thread (lock));

  //(ADDED) deals with prio donation (lines 289-311)

  enum intr_level old_level;
  old_level = intr_disable ();

  //remove this lock from list of held_locks
  lock->holder = NULL;
  lock->max_priority = -1;
  list_remove(&lock->elem);

  if(!thread_mlfqs)
  {
    //check if we are holding locks, if so take the max donated priority
    if(!list_empty(&(thread_current()->locks_held)))
    {
      struct list_elem *first_elem = list_begin(&(thread_current()->locks_held));
      struct lock *l = list_entry(first_elem,struct lock,elem);
      thread_current()->priority = l->max_priority;
    }
    else //else go back to old priority 
    {
      thread_current()->priority = thread_current()->old_priority;
    }
  }

  intr_set_level (old_level);
  sema_up (&lock->semaphore);
}

/* Returns true if the current thread holds LOCK, false
   otherwise.  (Note that testing whether some other thread holds
   a lock would be racy.) */
bool
lock_held_by_current_thread (const struct lock *lock) 
{
  ASSERT (lock != NULL);

  return lock->holder == thread_current ();
}

/* One semaphore in a list. */
struct semaphore_elem 
  {
    struct list_elem elem;              /* List element. */
    struct semaphore semaphore;         /* This semaphore. */
    int priority; //(ADDED) should hold the prio of the thread waiting on the sema with the highest prio
  };

//(ADDED) compares the prios of semaphores (should probably move to compare file)
static bool semaPrioCompare(const struct list_elem *s1,
                             const struct list_elem *s2, void *aux UNUSED)
{
  const struct semaphore_elem *sPointer1 = list_entry (s1, struct semaphore_elem, elem);
  const struct semaphore_elem *sPointer2 = list_entry (s2, struct semaphore_elem, elem);
  if(sPointer1->priority < sPointer2->priority){
    return true;
  }
  else{
    return false;
  }
}



/* Initializes condition variable COND.  A condition variable
   allows one piece of code to signal a condition and cooperating
   code to receive the signal and act upon it. */
void
cond_init (struct condition *cond)
{
  ASSERT (cond != NULL);

  list_init (&cond->waiters);
}

/* Atomically releases LOCK and waits for COND to be signaled by
   some other piece of code.  After COND is signaled, LOCK is
   reacquired before returning.  LOCK must be held before calling
   this function.
   The monitor implemented by this function is "Mesa" style, not
   "Hoare" style, that is, sending and receiving a signal are not
   an atomic operation.  Thus, typically the caller must recheck
   the condition after the wait completes and, if necessary, wait
   again.
   A given condition variable is associated with only a single
   lock, but one lock may be associated with any number of
   condition variables.  That is, there is a one-to-many mapping
   from locks to condition variables.
   This function may sleep, so it must not be called within an
   interrupt handler.  This function may be called with
   interrupts disabled, but interrupts will be turned back on if
   we need to sleep. */
void
cond_wait (struct condition *cond, struct lock *lock) 
{
  struct semaphore_elem waiter;

  ASSERT (cond != NULL);
  ASSERT (lock != NULL);
  ASSERT (!intr_context ());
  ASSERT (lock_held_by_current_thread (lock));
  
  sema_init (&waiter.semaphore, 0);
  waiter.priority = thread_get_priority(); //(ADDED) sets sema's prio value to the threads prio

  list_push_back (&cond->waiters, &waiter.elem);
  lock_release (lock);
  sema_down (&waiter.semaphore);
  lock_acquire (lock);
}

/* If any threads are waiting on COND (protected by LOCK), then
   this function signals one of them to wake up from its wait.
   LOCK must be held before calling this function.
   An interrupt handler cannot acquire a lock, so it does not
   make sense to try to signal a condition variable within an
   interrupt handler. */
void
cond_signal (struct condition *cond, struct lock *lock UNUSED) 
{
  ASSERT (cond != NULL);
  ASSERT (lock != NULL);
  ASSERT (!intr_context ());
  ASSERT (lock_held_by_current_thread (lock));

  struct list_elem *max_cond_waiter; //(ADDED) to be used below
  if (!list_empty (&cond->waiters)) 
  {
    //(ADDED) wakes max prio thread
    //sema_up (&list_entry (list_pop_front (&cond->waiters), struct semaphore_elem, elem)->semaphore);
    max_cond_waiter = list_max (&cond->waiters,semaPrioCompare,NULL);
    list_remove(max_cond_waiter);
    sema_up (&list_entry(max_cond_waiter,struct semaphore_elem,elem)->semaphore);
  }
}

/* Wakes up all threads, if any, waiting on COND (protected by
   LOCK).  LOCK must be held before calling this function.
   An interrupt handler cannot acquire a lock, so it does not
   make sense to try to signal a condition variable within an
   interrupt handler. */
void
cond_broadcast (struct condition *cond, struct lock *lock) 
{
  ASSERT (cond != NULL);
  ASSERT (lock != NULL);

  while (!list_empty (&cond->waiters))
    cond_signal (cond, lock);
}