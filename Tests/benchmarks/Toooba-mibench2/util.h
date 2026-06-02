// See LICENSE for license details.

#ifndef __UTIL_H
#define __UTIL_H

extern void setStats(int enable);

#include <stdint.h>

#define static_assert(cond) switch(0) { case 0: case !!(long)(cond): ; }

static int verify(int n, const volatile int* test, const int* verify)
{
  int i;
  // Unrolled for faster verification
  for (i = 0; i < n/2*2; i+=2)
  {
    int t0 = test[i], t1 = test[i+1];
    int v0 = verify[i], v1 = verify[i+1];
    if (t0 != v0) return i+1;
    if (t1 != v1) return i+2;
  }
  if (n % 2 != 0 && test[n-1] != verify[n-1])
    return n;
  return 0;
}

static int verifyDouble(int n, const volatile double* test, const double* verify)
{
  int i;
  // Unrolled for faster verification
  for (i = 0; i < n/2*2; i+=2)
  {
    double t0 = test[i], t1 = test[i+1];
    double v0 = verify[i], v1 = verify[i+1];
    int eq1 = t0 == v0, eq2 = t1 == v1;
    if (!(eq1 & eq2)) return i+1+eq1;
  }
  if (n % 2 != 0 && test[n-1] != verify[n-1])
    return n;
  return 0;
}

static void __attribute__((noinline)) barrier(int ncores)
{
  static volatile int sense;
  static volatile int count;
  static __thread int threadsense;

  __sync_synchronize();

  threadsense = !threadsense;
  if (__sync_fetch_and_add(&count, 1) == ncores-1)
  {
    count = 0;
    sense = threadsense;
  }
  else while(sense != threadsense)
    ;

  __sync_synchronize();
}

static uint64_t lfsr(uint64_t x)
{
  uint64_t bit = (x ^ (x >> 1)) & 1;
  return (x >> 1) | (bit << 62);
}

static uintptr_t insn_len(uintptr_t pc)
{
  return (*(unsigned short*)pc & 3) ? 4 : 2;
}

#define stringify_1(s) #s
#define stringify(s) stringify_1(s)
#define stats(code, iter) do { \
    unsigned long _c = -read_csr(mcycle), _i = -read_csr(minstret); \
    code; \
    _c += read_csr(mcycle), _i += read_csr(minstret); \
    if (cid == 0) \
      printf("\n%s: %ld cycles, %ld.%ld cycles/iter, %ld.%ld CPI\n", \
             stringify(code), _c, _c/iter, 10*_c/iter%10, _c/_i, 10*_c/_i%10); \
  } while(0)

#define NULL 0

int memcmp(const void *s1, const void *s2, unsigned long n);

int strncmp(const char *s1, const char *s2, unsigned long n);

char *strchr(const char *s, int c);

unsigned long strlen(const char *s);

void putchar(char c);

void puts(char *string);

void *memcpy(void *dest, const void *src, unsigned long n);

void *bcopy(void *dest, const void *src, unsigned long n);

void *memmove(void *dest, const void *src, unsigned long n);

void *memset(void *s, int c, unsigned long n);

void bzero(void *s, unsigned long n);

double modf(double x, double *iptr);

int printf(const char *format, ...);

#define HEAP_SIZE (1024 * 1024)  // 1 MB

static unsigned char heap[HEAP_SIZE];
static int heap_offset = 0;

void *malloc(unsigned long size);

void *calloc(unsigned long len, unsigned long size);

void * _sbrk(int increment);

void free(void *ptr);

// math functions and constants
#define PI 3.14159

static unsigned int seed = 1;

void srand(unsigned int s);

int rand(void);

double fabs(double x);

double pow(double x, double n);

double sqrt(double x);

double sin(double x);

double cos(double x);

double atan(double z);

double atan2(double y, double x);

double acos(double x);

double cbrt(double x);

double floor(double x);

double ceil(double x);

typedef struct {
    double low;
    double high;
} fake_float128;

fake_float128 __extenddftf2(double a);

double __trunctfdf2(fake_float128 a);

fake_float128 __multf3(fake_float128 a, fake_float128 b);

fake_float128 __addtf3(fake_float128 a, fake_float128 b);

fake_float128 __subtf3(fake_float128 a, fake_float128 b);

fake_float128 __divtf3(fake_float128 a, fake_float128 b);

int __lttf2(fake_float128 a, fake_float128 b);

#endif //__UTIL_H
