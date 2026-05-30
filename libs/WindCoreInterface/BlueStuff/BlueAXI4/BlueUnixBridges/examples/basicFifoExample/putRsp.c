#include <BlueUnixFifo.h>
#include <stdio.h>
#include <string.h>

void hexDump (const uint8_t* raw, size_t n) {
  for (int i = n; i >= 0; i--) printf ("%02x", raw[i]);
}

typedef struct {
  uint32_t x;
  uint8_t y[17];
} MyRspType;

void encodeRsp (uint8_t* rawbytes, const void* src) {
  MyRspType* rsp = (MyRspType*) src;
  memcpy (rawbytes, rsp->y, 17);
  rawbytes[16] = ((uint8_t) (rsp->x << 4) & 0xf0) | rawbytes[16] & 0x0f;
  rawbytes[17] = (uint8_t) (rsp->x >> 4) & 0xff;
  rawbytes[18] = (uint8_t) (rsp->x >> 12) & 0xff;
  rawbytes[19] = (uint8_t) (rsp->x >> 20) & 0x03;
}

void printRsp (MyRspType* rsp) {
  printf ("MyRspType {x: 0x%03x, y:", 0x003fffff & rsp->x);
  hexDump (rsp->y, 17);
  printf ("}\n");
}

int main (int argc, char** argv) {
  if (argc < 3) {
    printf ("usage: %s FIFO_PATH N_RSP (argc: %d)\n", argv[0], argc);
    exit (EXIT_FAILURE);
  }
  bub_fifo_desc_t rspDesc =
    bub_fifo_OpenForProduction (argv[1], 20, &encodeRsp);
  printf("argv[1]: %s\n", argv[1]);
  printf("argv[2]: %s\n", argv[2]);
  printf("----------------------------\n");

  for (int i = 0; i < atoi (argv[2]); i ++) {
    MyRspType rsp = { .x = i, .y = i*23 };
    bub_fifo_ProduceElement (rspDesc, (void *) &rsp);
    printRsp (&rsp);
  }
  bub_fifo_Close (rspDesc);
  return 0;
}
