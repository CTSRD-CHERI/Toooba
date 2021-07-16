#define CONFIG_ADDRESS_INCREMENT (64)
#define CONFIG_ADDRESS_REVOKE    (0x03000000)
#define CONFIG_ADDRESS_OWN       (CONFIG_ADDRESS_REVOKE + CONFIG_ADDRESS_INCREMENT)
#define CONFIG_ADDRESS_READ      (CONFIG_ADDRESS_OWN + CONFIG_ADDRESS_INCREMENT)
#define CONFIG_ADDRESS_INIT      (CONFIG_ADDRESS_READ + CONFIG_ADDRESS_INCREMENT)

enum ConfigOp{
  ConfigOpRevoke,
  ConfigOpOwn,
  ConfigOpRead,
  ConfigOpInit
};

int performPraesidioConfigOps(unsigned long long argAddress, enum ConfigOp op) {
  volatile unsigned long long* configAddress;
  switch (op) {
    case ConfigOpRevoke:
      configAddress = CONFIG_ADDRESS_REVOKE;
      break;
    case ConfigOpOwn:
      configAddress = CONFIG_ADDRESS_OWN;
      break;
    case ConfigOpRead:
      configAddress = CONFIG_ADDRESS_READ;
      break;
    case ConfigOpInit:
      configAddress = CONFIG_ADDRESS_INIT;
      break;
    default:
      return -1;
  }
  configAddress[0] = argAddress;
  return 0;
}

int main(void) {
    int ret;
    //Initialize Praesidio Shim
    performPraesidioConfigOps(0x80000000, ConfigOpOwn);
    performPraesidioConfigOps(0x80007000, ConfigOpOwn);
    performPraesidioConfigOps(0x80230000, ConfigOpRevoke);
    performPraesidioConfigOps(0x80220000, ConfigOpRevoke);
    performPraesidioConfigOps(0xBF7DF000, ConfigOpOwn);
    performPraesidioConfigOps(0x00000000, ConfigOpInit);

    //Loop that counts AXI4 requests coming out of CPU 
    asm volatile (
        "li t0, 0x74;"//Event ID for AXI4 ar
        //"li t0, 0x6;"//Event ID for AUIPC
        "csrw mhpmevent3, t0;"
        "csrr t1, mhpmcounter3;"
        "li t0, 20;"
        "loop: addi t0, t0, -1;"
        "auipc t2, 0x100;"
        "srli t2, t2, 2;"
        "slli t2, t2, 2;"
        "slli t3, t0, 16;"
        "add t2, t2, t3;"
        "lw t2, 0(t2);"
        "bnez t0, loop;"
        "csrr t0, mhpmcounter3;"
        "sub %0, t0, t1"
        : "=r"(ret) //output
        : //input
        : "t0", "t1", "t2", "t3"//clobbered
    );
    return ret;
}
