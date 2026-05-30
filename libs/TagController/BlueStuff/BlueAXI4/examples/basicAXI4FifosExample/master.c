#include <BlueAXI4UnixBridges.h>
#include <stdio.h>
#include <pthread.h>
#include <unistd.h>

DEF_AXI4_API(2, 32, 64, 0, 0, 0, 0, 0, test)

////////////////////////////////////////////////////////////////////////////////
typedef struct { bub_fifo_desc_t ff; int n; } arArg_t;
void* arTask (void* argPtr) {
  arArg_t* arg = (arArg_t*) argPtr;
  uint8_t arid = 0;
  uint32_t araddr = 0x10;
  uint8_t aruser = 0;
  t_axi4_arflit arflit = { .arid = &arid
                         , .araddr = (uint8_t*) &araddr
                         , .arlen = 8
                         , .arsize = 2
                         //, .arburst = AXI4_Burst_INCR
                         //, .arlock = AXI4_Lock_NORMAL
                         //, .arcache = arcache_wback_r_alloc
                         //, .arprot = AXI4_Prot (DATA,SECURE,PRIV)
                         , .arburst = 1
                         , .arlock = 2
                         , .arcache = 3
                         , .arprot = 4
                         , .arqos = 5
                         , .arregion = 6
                         , .aruser = &aruser };
  uint8_t bitBag[AXI4_AR_BYTEsz(2,32,0)];
  for (int i = 0; i < arg->n; i++) {
    araddr += i;
    while (!bub_fifo_Produce (arg->ff, (void*) &arflit));
    AXI4_AR_(2,32,0,test,print_flit)(&arflit);
    printf ("\n");
    AXI4_AR_(2,32,0,test,serialize_flit)(bitBag, &arflit);
    bitHexDump(bitBag, AXI4_AR_BITsz(2,32,0));
    printf ("\n");
  }
}

////////////////////////////////////////////////////////////////////////////////
typedef struct { bub_fifo_desc_t ff; int n; } rArg_t;
void* rTask (void* argPtr) {
  rArg_t* arg = (rArg_t*) argPtr;
  t_axi4_rflit* rflit = AXI4_R_(2,64,0,test,create_flit)(NULL);
  int cnt = 0;
  while (cnt < arg->n) {
    while (!bub_fifo_Consume (arg->ff, (void*) rflit));
    AXI4_R_(2,64,0,test,print_flit)(rflit);
    printf ("\n");
    if (rflit->rlast) cnt++;
  }
}

////////////////////////////////////////////////////////////////////////////////
int main (int argc, char** argv) {
  if (argc < 4) {
    printf ("usage: %s PORT_DIR N_READ N_WRITE (argc: %d)\n", argv[0], argc);
    exit (EXIT_FAILURE);
  }
  baub_port_fifo_desc_t* slvDesc =
    AXI4_(2, 32, 64, 0, 0, 0, 0, 0, test, fifo_OpenAsSlave)(argv[1]);
  printf("argv[1]: %s\n", argv[1]);
  printf("argv[2]: %s\n", argv[2]);
  printf("argv[3]: %s\n", argv[3]);
  printf("----------------------------\n");

  //pthread_create (&awThread, NULL, awTask, (void*) awArg);
  //pthread_create (&wThread, NULL, wTask, (void*) wArg);
  //pthread_create (&bThread, NULL, bTask, (void*) bArg);
  // ar thread
  pthread_t arThread;
  arArg_t arArg = {ff: slvDesc->ar, n: atoi(argv[2])};
  pthread_create (&arThread, NULL, arTask, (void*) &arArg);
  // r thread
  pthread_t rThread;
  rArg_t rArg = {ff: slvDesc->r, n: atoi(argv[2])};
  pthread_create (&rThread, NULL, rTask, (void*) &rArg);

  //pthread_join (awThread, NULL);
  //pthread_join (wThread, NULL);
  //pthread_join (bThread, NULL);
  pthread_join (arThread, NULL);
  pthread_join (rThread, NULL);

  baub_fifo_Close (slvDesc);

  return 0;
}
