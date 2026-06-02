/* NIST Secure Hash Algorithm */

#include <util.h>
#include "../bareBench.h"
#include "sha.h"
#include "input.h"

int main()
{
  SHA_INFO sha_info;

  sha_stream(&sha_info, inputString);
  sha_print(&sha_info);
  
  return(0);
}
