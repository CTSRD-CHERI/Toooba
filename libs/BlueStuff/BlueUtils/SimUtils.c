/*-
 * Copyright (c) 2018-2024 Alexandre Joannou
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory (Department of Computer Science and
 * Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
 * DARPA SSITH research programme.
 *
 * @BERI_LICENSE_HEADER_START@
 *
 * Licensed to BERI Open Systems C.I.C. (BERI) under one or more contributor
 * license agreements.  See the NOTICE file distributed with this work for
 * additional information regarding copyright ownership.  BERI licenses this
 * file to you under the BERI Hardware-Software License, Version 1.0 (the
 * "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at:
 *
 *   http://www.beri-open-systems.org/legal/license-1-0.txt
 *
 * Unless required by applicable law or agreed to in writing, Work distributed
 * under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * @BERI_LICENSE_HEADER_END@
 */

#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

// get system time
unsigned long long sysTime ()
{
  return time(NULL);
}

// print IPC
void printIPC (unsigned long long insts, unsigned long long cycles)
{
  printf("IPC: %f\n", (double) insts/cycles);
}

void getenv_as_64hex (unsigned int * maybe_ret, const char * varname)
{
  uint8_t* maybe_tag = & (((uint8_t*) maybe_ret)[8]);
  uint64_t* maybe_val = (uint64_t*) maybe_ret;
  *maybe_tag = 0;
  char * varval = getenv(varname);
  if (varval)
  {
    *maybe_tag = 1;
    *maybe_val = strtoll(varval, NULL, 16);
  }
}

void getenv_as_uint (unsigned int * maybe_ret, const char * varname)
{
  uint8_t* maybe_tag = & (((uint8_t*) maybe_ret)[8]);
  uint64_t* maybe_val = (uint64_t*) maybe_ret;
  *maybe_tag = 0;
  char * varval = getenv(varname);
  if (varval)
  {
    *maybe_tag = 1;
    *maybe_val = strtoll(varval, NULL, 10);
  }
}
