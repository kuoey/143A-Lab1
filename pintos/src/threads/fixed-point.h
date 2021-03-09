#ifndef THREADS_FIXED_POINT_H
#define THREADS_FIXED_POINT_H

#include <debug.h>
#include <list.h>
#include <stdint.h>
int f;
int power(int base, int pow);
int convertNtoFixedPoint(int n);
int convertXtoInt(int x);
int convertXtoIntRoundNear(int x);
int addXandY(int x, int y);
int subtractYfromX(int x, int y);
int addXandN(int x, int n);
int subNfromX(int x, int n);
int multXbyY(int x, int y);
int multXbyN(int x, int n);
int divXbyY(int x, int y);
int divXbyN(int x, int n);


#endif /* threads/fixed-point.h */