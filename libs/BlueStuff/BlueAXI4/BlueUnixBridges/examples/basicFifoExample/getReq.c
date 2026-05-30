#include <BlueUnixFifo.h>
#include <stdio.h>

typedef struct {
  uint16_t a;
  uint16_t b;
} MyReqType;

void decodeReq (void* dest, const uint8_t* rawbytes) {
  // cast destination pointer to MyReqType
  MyReqType* req = (MyReqType*) dest;
  // low 11 bits: b
  req->b = (* (uint16_t*) rawbytes) & 0x07ff;
  // next 12 bits: a
  req->a = (* (uint16_t*) (rawbytes + 1) >> 3) & 0x0fff;
}

void printReq (MyReqType* req) {
  printf ("MyReqType {a: 0x%04x, b: 0x%04x}\n", req->a, req->b);
}

int main (int argc, char** argv) {
  if (argc < 3) {
    printf ("usage: %s FIFO_PATH N_REQ (argc: %d)\n", argv[0], argc);
    exit (EXIT_FAILURE);
  }
  bub_fifo_desc_t reqDesc =
    bub_fifo_OpenForConsumption (argv[1], 3, &decodeReq);
  printf("argv[1]: %s\n", argv[1]);
  printf("argv[2]: %s\n", argv[2]);
  printf("----------------------------\n");

  MyReqType req;

  for (int i = 0; i < atoi (argv[2]); i ++) {
    bub_fifo_ConsumeElement (reqDesc, (void *) &req);
    printReq (&req);
  }
  bub_fifo_Close (reqDesc);
  return 0;
}
