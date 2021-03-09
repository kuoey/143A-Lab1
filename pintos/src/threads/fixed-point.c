#include "threads/thread.h"
#include <debug.h>
#include <stddef.h>
#include <random.h>
#include <stdio.h>
#include <string.h>
#include "threads/flags.h"
#include "threads/interrupt.h"
#include "threads/intr-stubs.h"
#include "threads/palloc.h"
#include "threads/switch.h"
#include "threads/synch.h"
#include "threads/vaddr.h"
int f;
int power(int base, int pow)
{
  if (pow == 0)
    return 1;
  else if (pow % 2 == 0)
    return power(base, pow / 2) * power(base, pow / 2);
  else
    return base * power(base, pow / 2) * power(base, pow / 2);
}

//Convert n to fixed point:    n * f
 int convertNtoFixedPoint(int n)
{
    return n * f;
}

//Convert x to integer (rounding toward zero):    x / f
 int convertXtoInt(int x)
{
    return x / f;
}

//    (x + f / 2) / f if x >= 0,
// (x - f / 2) / f if x <= 0.
 int convertXtoIntRoundNear(int x)
{
    if(x >= 0)
        return (x + f / 2) / f;
    else
        return (x - f / 2) / f;
}

//x + y
 int addXandY(int x, int y)
{
    return x + y;
}

// x - y
 int subtractYfromX(int x, int y)
{
    return x - y;
}

//Add x and n:    x + n * f
 int addXandN(int x, int n)
{
    return x + (n * f);
}

//Subtract n from x:    x - n * f
 int subNfromX(int x, int n)
{
    return x - (n * f);
}

//Multiply x by y:    ((int64_t) x) * y / f
 int multXbyY(int x, int y)
{
    return ((int64_t) x) * y / f;
}

//Multiply x by n:    x * n
 int multXbyN(int x, int n)
{
    return x * n;
}

//Divide x by y:    ((int64_t) x) * f / y
 int divXbyY(int x, int y)
{
    return ((int64_t) x) * f / y;
}

//Divide x by n:    x / n
 int divXbyN(int x, int n)
{
    return x / n;
}