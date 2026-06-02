#include <util.h>

void exit(int);

extern unsigned int end;

void _fini() {}
void __exidx_start() {}
void __exidx_end() {}

void __errno() {}

int _isatty()
{
  return 0;
}
int _fstat()
{
  return 0;
}

// Default behavior is for GCC to send printf output here
int _write(int fd, const unsigned char *buf, int count)
{
    int cnt;
    for(cnt = 0; cnt < count; ++cnt)
    {
        putchar(*buf);
	++buf;
    }

    return cnt;
}

void _close()
{
    return;
}

void _read()
{
    return;
}

void _lseek()
{
    return;
}
