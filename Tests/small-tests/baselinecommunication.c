#define COMMUNICATION_ADDRESS (0x80010000)
#define FIRST_VAL             (0x55555555)
#define SECOND_VAL            (0xCAFEBABE)
#define REPITITIONS           (100)

int main(void) {
  int hart_id, start_time, end_time, tmp;
  int total = 0;
  asm volatile(
    "csrr %0, 0xF14" //CSR mhartid
    : "=r" (hart_id) //output
    : //input
    : //clobbered
  );
  volatile unsigned int* ptr = (unsigned int*) COMMUNICATION_ADDRESS;
  tmp = *ptr;
  if(hart_id == 0) {
    for(int i = 0; i < REPITITIONS; i++) {
      asm volatile(
        "rdcycle %0"
        : "=r" (start_time) //output
        : //input
        : //clobbered
      );
      *ptr = FIRST_VAL;
      while(*ptr != SECOND_VAL);
      asm volatile(
        "rdcycle %0"
        : "=r" (end_time) //output
        : //input
        : //clobbered
      );
      total += end_time - start_time;
    }
    return total / REPITITIONS;
  } else {
    for(int i = 0; i < REPITITIONS; i++) {
      while(*ptr != FIRST_VAL);
      *ptr = SECOND_VAL;
    }
    while(1);
  }
}
