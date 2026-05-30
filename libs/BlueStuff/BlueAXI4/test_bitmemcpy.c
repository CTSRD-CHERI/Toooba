#include "BlueAXI4UnixBridgesHelpers.h"

void print_array(uint8_t* arr, size_t n)
{
  for (size_t i = 0; i < n; i++)
    printf("0x%02x ", arr[i]);
  printf("\n");
}

int main()
{
  uint8_t src[2] = {0x12,0xab};
  //uint8_t src[2] = {0x00,0x00};
  uint8_t dst[4] = {0x00,0x00,0x00,0x00};
  //uint8_t dst[4] = {0xff,0xff,0xff,0xff};

  printf("before\n");
  printf("src: ");
  print_array(src, 2);
  printf("dst: ");
  print_array(dst, 4);

  //bitmemcpy(dst, 0, src, 0, 8);
  bitmemcpy(dst, 0, src, 1, 8);

  printf("after\n");
  printf("src: ");
  print_array(src, 2);
  printf("dst: ");
  print_array(dst, 4);


  return 0;
}
