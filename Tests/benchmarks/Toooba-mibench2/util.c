// See LICENSE for license details.

#include "util.h"

int memcmp(const void *s1, const void *s2, unsigned long n) {
    const unsigned char *p1 = s1;
    const unsigned char *p2 = s2;

    for (unsigned long i = 0; i < n; i++) {
        if (p1[i] != p2[i]) {
            return (int)(p1[i] - p2[i]);
        }
    }
    return 0;
}

int strncmp(const char *s1, const char *s2, unsigned long n) {
    for (unsigned long i = 0; i < n; i++) {
        unsigned char c1 = (unsigned char)s1[i];
        unsigned char c2 = (unsigned char)s2[i];

        if (c1 != c2) {
            return c1 - c2;
        }

        // If end of either string is reached
        if (c1 == '\0') {
            return 0;
        }
    }
    return 0;
}

unsigned long strlen(const char *s) {
    unsigned long len = 0;
    while (s[len] != '\0') {
        len++;
    }
    return len;
}

char *strchr(const char *s, int c) {
    while (*s) {
        if (*s == (char)c) {
            return (char *)s;  // Cast away constness to match standard signature
        }
        s++;
    }

    // Check for null terminator if searching for '\0'
    if ((char)c == '\0') {
        return (char *)s;
    }

    return 0;  // Character not found
}

volatile char out_char;
void putchar(char c) {
    out_char = c;
};

void puts(char *string)
{
    int index = 0;
    while(string[index] != '\0')
    {
        putchar(string[index]);
        ++index;
    }
}

void *memcpy(void *dest, const void *src, unsigned long n) {
    unsigned char *d = dest;
    const unsigned char *s = src;

    for (unsigned long i = 0; i < n; i++) {
        d[i] = s[i];
    }

    return dest;
}

void *bcopy(void *dest, const void *src, unsigned long n) {
  return memcpy(dest, src, n);
}

void *memmove(void *dest, const void *src, unsigned long n) {
    unsigned char *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;

    if (d == s || n == 0) {
        return dest;
    }

    if (d < s || d >= s + n) {
        // No overlap or safe to copy forward
        return memcpy(dest, src, n);
    } else {
        // Overlap: copy backward
        for (unsigned long i = n; i > 0; i--) {
            d[i - 1] = s[i - 1];
        }
        return dest;
    }
}

void *memset(void *s, int c, unsigned long n) {
    unsigned char *p = s;
    unsigned char value = (unsigned char)c;

    for (unsigned long i = 0; i < n; i++) {
        p[i] = value;
    }

    return s;
}

void bzero(void *s, unsigned long n) {
  memset(s,0,n);
}

double modf(double x, double *iptr) {
    if (x >= 0.0) {
        *iptr = (double)(long long)x;
    } else {
        *iptr = (double)(long long)x;
    }

    return x - *iptr;
}

int printf(const char *format, ...) {
    // Stub: does nothing
    (void)format;  // Avoid unused parameter warning

    return 0;  // Return value can be adjusted as needed
}

void *malloc(unsigned long size) {
    // Align size to 16 bytes
    size = (size + 15) & ~15;

    if (heap_offset + size > HEAP_SIZE) {
        // Out of memory
        return 0;
    }

    void *ptr = &heap[heap_offset];
    heap_offset += size;
    return ptr;
}

void *calloc(unsigned long len, unsigned long size) {
    unsigned long blen = len * size;
    return memset(malloc(blen),0,blen);
}

void * _sbrk(int increment)
{   
    return malloc(increment);
}

void free(void *ptr) {
    // Stub: does nothing
    (void)ptr; // Avoid unused parameter warning
}

void srand(unsigned int s) {
    seed = s;
}

int rand(void) {
    // Constants from Numerical Recipes
    seed = seed * 1664525 + 1013904223;
    return (int)(seed & 0x7FFFFFFF);  // Return non-negative result
}

double fabs(double x) {
    return x < 0 ? -x : x;
}

double pow(double x, double n) {
    double result = 1.0;
    for (int i = 0; i < n; i++) {
        result *= x;
    }
    return result;
}

double sqrt(double x) {
    if (x < 0) return -1;  // error or NaN in real implementations

    double guess = x / 2.0;
    for (int i = 0; i < 20; i++) {
        guess = 0.5 * (guess + x / guess);
    }
    return guess;
}

double sin(double x) {
    // Taylor series approximation around 0:
    // sin(x) ≈ x - x^3/3! + x^5/5! - x^7/7!
    double x3 = pow(x, 3);
    double x5 = pow(x, 5);
    double x7 = pow(x, 7);

    return x - x3 / 6.0 + x5 / 120.0 - x7 / 5040.0;
}

double cos(double x) {
    // Taylor series approximation around 0:
    // cos(x) ≈ 1 - x^2/2! + x^4/4! - x^6/6!
    double x2 = pow(x, 2);
    double x4 = pow(x, 4);
    double x6 = pow(x, 6);

    return 1.0 - x2 / 2.0 + x4 / 24.0 - x6 / 720.0;
}

double atan(double z) {
    // Approximation by Bhaskara I, reasonably accurate for |z| <= 1
    if (z < -1 || z > 1) {
        // Use identity: atan(z) = PI/2 - atan(1/z) when z > 1
        return z > 0 ? (3.141592653589793 / 2) - atan(1.0 / z)
                    : -(3.141592653589793 / 2) - atan(1.0 / z);
    }

    // Polynomial approximation (e.g., from Abramowitz & Stegun or other)
    // atan(x) ≈ x*(π/4 + 0.273 * (1 - |x|)) for |x| <= 1
    double abs_z = z < 0 ? -z : z;
    double result = z * (3.141592653589793 / 4 + 0.273 * (1 - abs_z));
    return result;
}

double atan2(double y, double x) {
    const double PI_2 = PI / 2.0;

    if (x > 0) {
        return atan(y / x);
    } else if (x < 0) {
        if (y >= 0) {
            return atan(y / x) + PI;
        } else {
            return atan(y / x) - PI;
        }
    } else {  // x == 0
        if (y > 0) {
            return PI_2;
        } else if (y < 0) {
            return -PI_2;
        } else {
            return 0.0;  // atan2(0, 0) is undefined; return 0 for simplicity
        }
    }
}

double acos(double x) {
    if (x < -1.0 || x > 1.0) {
        return -1;  // error, out of domain
    }

    // acos(x) = atan2(sqrt(1 - x*x), x)
    double sqrt_term = sqrt(1.0 - x * x);
    return atan2(sqrt_term, x);
}

double cbrt(double x) {
    if (x == 0.0) return 0.0;

    // Handle negative numbers
    int neg = x < 0;
    if (neg) x = -x;

    // Initial guess using rough power approximation
    double guess = x;
    if (x > 1.0)
        guess = x / 3.0;
    else
        guess = x * 3.0;

    // Newton-Raphson iteration: y_{n+1} = (2*y_n + x / y_n^2) / 3
    for (int i = 0; i < 20; i++) {
        guess = (2.0 * guess + x / (guess * guess)) / 3.0;
    }

    return neg ? -guess : guess;
}

double floor(double x) {
    int i = (int)x;  // truncate towards zero
    if (x >= 0 || x == (double)i)
        return (double)i;
    else
        return (double)(i - 1);
}

double ceil(double x) {
    int i = (int)x;  // truncate towards zero
    if (x <= 0 || x == (double)i)
        return (double)i;
    else
        return (double)(i + 1);
}

fake_float128 __extenddftf2(double a) {
    // Dummy stub — will not produce valid quad precision!
    fake_float128 result = {0, a};
    return result;
}

double __trunctfdf2(fake_float128 a) {
    return a.low;
}

fake_float128 __multf3(fake_float128 a, fake_float128 b) {
    fake_float128 result = {0, a.low * b.low};  // Not a real product!
    return result;
}

fake_float128 __addtf3(fake_float128 a, fake_float128 b) {
    fake_float128 result = {0, a.low + b.low};  // Dummy placeholder
    return result;
}

fake_float128 __subtf3(fake_float128 a, fake_float128 b) {
    fake_float128 result = {0, a.low - b.low};  // Dummy placeholder
    return result;
}

fake_float128 __divtf3(fake_float128 a, fake_float128 b) {
    fake_float128 result = {0, a.low / b.low};  // Dummy placeholder
    return result;
}

int __lttf2(fake_float128 a, fake_float128 b) {
    if (a.low < b.low) return -1;
    if (a.low > b.low) return 1;
    return 0;
}