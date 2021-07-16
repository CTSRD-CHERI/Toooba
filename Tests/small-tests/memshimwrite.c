int main(void) {
    int ret;
    //Loop that counts AXI4 requests coming out of CPU 
    asm volatile (
        "li t0, 0x70;"//Event ID for AXI4 aw
        "csrw mhpmevent3, t0;"
        "csrr t1, mhpmcounter3;"
        "li t0, 100;"
        "loop: addi t0, t0, -1;"
        "auipc t2, 0x100;"
        "srli t2, t2, 2;"
        "slli t2, t2, 2;"
        "slli t3, t0, 16;"
        "add t2, t2, t3;"
        "sw t2, 0(t2);"
        "bnez t0, loop;"
        "csrr t0, mhpmcounter3;"
        "sub %0, t0, t1"
        : "=r"(ret) //output
        : //input
        : "t0", "t1", "t2", "t3"//clobbered
    );
    return ret;
}
