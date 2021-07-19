#define COMMUNICATION_ADDRESS (0xD0010000)
#define FIRST_VAL             (0x55555555)
#define SECOND_VAL            (0xCAFEBABE)

int main(void) {
  int secure_world;
  asm volatile(
    "csrr %0, 0xFC0" //CSR indicating whether a core is in the secure world or not
    : "=r" (secure_world) //output
    : //input
    : //clobbered
  );
  unsigned int* ptr = (unsigned int*) COMMUNICATION_ADDRESS;
  if(secure_world == 0) {
    *ptr = FIRST_VAL;
    while(*ptr != SECOND_VAL);
    return *ptr;
  } else {
    while(*ptr != FIRST_VAL);
    *ptr = SECOND_VAL;
    while(1);
  }
}
