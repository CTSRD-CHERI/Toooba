#define COMMUNICATION_ADDRESS (0xD0010000)
#define FIRST_VAL             (0x55555555)
#define SECOND_VAL            (0xCAFEBABE)

int main(void) {
  int secure_world, start_time, end_time;
  asm volatile(
    "csrr %0, 0xFC0" //CSR indicating whether a core is in the secure world or not
    : "=r" (secure_world) //output
    : //input
    : //clobbered
  );
  unsigned int* ptr = (unsigned int*) COMMUNICATION_ADDRESS;
  if(secure_world == 0) {
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
    return end_time - start_time;
  } else {
    while(*ptr != FIRST_VAL);
    *ptr = SECOND_VAL;
    while(1);
  }
}
