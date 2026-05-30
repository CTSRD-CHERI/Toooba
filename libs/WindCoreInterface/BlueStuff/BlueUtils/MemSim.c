/*-
 * Copyright (c) 2018-2021 Alexandre Joannou
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory (Department of Computer Science and
 * Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
 * DARPA SSITH research programme.
 *
 * This material is based upon work supported by the DoD Information Analysis
 * Center Program Management Office (DoD IAC PMO), sponsored by the Defense
 * Technical Information Center (DTIC) under Contract No. FA807518D0004.  Any
 * opinions, findings and conclusions or recommendations expressed in this
 * material are those of the author(s) and do not necessarily reflect the views
 * of the Air Force Installation Contracting Agency (AFICA).
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

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <ctype.h>
#include <math.h>

// general helper functions
inline unsigned long long div_up (unsigned long long a, unsigned long long b)
{
  return (a/b)+((a%b)?1:0);
}

int hexToInt (char c)
{
  if(c >= '0' && c <= '9') return c - '0';
  if(c >= 'a' && c <= 'f') return c - 'a' + 10;
  if(c >= 'A' && c <= 'F') return c - 'A' + 10;
  return 0;
}

void print_mem ( const unsigned char * const mem
               , unsigned long long from
               , unsigned long long to
               , unsigned long long word_sz )
{
  int i, j;
  int shft = (int) log2(word_sz);
  unsigned long long from_align = (from << shft) >> shft;
  unsigned long long to_align = (to << shft) >> shft;
  for (i = from_align; i < from_align + to_align; i+= word_sz)
  {
    printf("0x%04x: 0x", i);
    for (j = word_sz-1; j >= 0; j--)
    {
      printf("%02x",mem[i+j]);
    }
    printf("\n");
  }
}

// HEX file loader functions
#define MAX_WIDTH 256
char * parse_hex_line (char * line)
{
  char cmt[3] = "//";
  // check for comments
  if (strncmp(line, cmt, 2) == 0) return NULL;
  // strip end comments
  char * tok = strtok(line, cmt);
  // trim leading whitespaces
  while(isspace(*tok)) tok++;
  // trim trailing whitespaces
  char * last = tok + strlen(tok) - 1;
  while(last > tok && isspace(*last)) last--;
  *(last + 1) = '\0';
  return tok;
}

unsigned long long write_hex_to_buff (char * hexline, unsigned char * buff)
{
  int i;
  unsigned long long pos = 0;
  for (i = strlen(hexline) - 1; i >=0; i -= 2)
    buff[pos++] = hexToInt(hexline[i]) + (hexToInt(hexline[i-1])<<4);
  return pos;
}

void load_hex (const char * filename, unsigned char * buff, unsigned long long buff_sz)
{
  // open file
  FILE * fp = fopen(filename, "r");
  if (fp == NULL) {
    fprintf(stderr, "Error opening %s: %s\n", filename, strerror(errno));
    exit(-1);
  }
  int done = 0;
  // fetch first line to determine the line width
  char line[MAX_WIDTH];
  char * hexline;
  if(fgets((char*)&line, MAX_WIDTH, fp) == NULL) done = 1;
  hexline = parse_hex_line(line);
  unsigned long long width = (hexline) ? div_up(strlen(hexline),2) : 0;
  // get rest of the file
  unsigned long long space_left = buff_sz;
  while (!done && space_left - width > 0)
  {
    // fold in previous line
    if (hexline)
    {
      unsigned long long bytes_written = write_hex_to_buff(hexline, buff);
      space_left -= bytes_written;
      buff += bytes_written;
    }
    // get next line and check for end
    if (fgets((char*)&line, MAX_WIDTH, fp) == NULL) done = 1;
    hexline = parse_hex_line(line);
    width = (hexline) ? div_up(strlen(hexline),2) : 0;
  }
  fclose(fp);
}

// functions to be used in Bluespec
////////////////////////////////////////////////////////////////////////////////

#ifdef __cplusplus
extern "C" {
#endif

#define DEBUG_LVL 0

typedef unsigned char t_byte;
typedef unsigned long long t_addr;
typedef unsigned long long t_size;
typedef unsigned long long t_data;
typedef unsigned char t_be;

typedef struct {
  t_byte * const data;
  t_size size;
} t_mem;

t_mem * mem_create (t_size memSize)
{
  #if (DEBUG_LVL > 0)
  printf ("---- mem_create ----\n");
  #endif
  t_mem * m = (t_mem *) malloc(sizeof(t_mem));
  m->size = memSize;
  *(t_byte **)&m->data =
    (t_byte *) malloc(m->size * sizeof(t_byte));
  #if (DEBUG_LVL > 1)
  printf("---- asked for 0x%0llx bytes\n", memSize);
  printf("---- allocated memory size = 0x%0llx\n", m->size);
  printf("---- allocated memory      @ 0x%p\n", m->data);
  #endif
  return m;
}

void mem_init ( t_mem * mem_ptr
              , char * hexfile
              , t_addr offset )
{
  #if (DEBUG_LVL > 0)
  printf("---- mem_init ----\n");
  #endif
  load_hex(hexfile, &(mem_ptr->data[offset]), mem_ptr->size - offset);
  #if (DEBUG_LVL > 2)
  printf("loaded hex file...\n");
  print_mem(mem_ptr->data, 0, 2048, 4);
  #endif
}

void mem_zero (t_mem * mem_ptr)
{
  #if (DEBUG_LVL > 0)
  printf("---- mem_zero ----\n");
  #endif
  explicit_bzero((void *) mem_ptr->data, mem_ptr->size);
}

t_data mem_read ( t_mem * mem_ptr
                , t_addr addr
                , t_size size )
{
  #if (DEBUG_LVL > 0)
  printf("---- mem_read ----\n");
  #endif
  #if (DEBUG_LVL > 1)
  printf("---- mem_read - args       ----\n");
  printf("---- mem_ptr      @ 0x%p ----\n", mem_ptr);
  printf("---- addr         = 0x%llx ----\n", addr);
  printf("---- size         = 0x%llx ----\n", size);
  #endif
  t_data data = 0;
  for (t_size i = 0; i < size; i++)
  {
    t_addr actual_addr = (addr+i) % (mem_ptr->size);
    ((t_byte*)&data)[i] = mem_ptr->data[actual_addr];
    #if (DEBUG_LVL > 1)
    if (addr+i >= mem_ptr->size)
      printf( "---- @ 0x%0llx >= memory size 0x%0llx"
              ", reading 0x%02x from @ 0x%0llx instead\n"
            , addr+i, mem_ptr->size, mem_ptr->data[actual_addr], actual_addr );
    #endif
  }
  return data;
}

void mem_write ( t_mem * mem_ptr
               , t_addr addr
               , t_be be
               , t_data data )
{
  #if (DEBUG_LVL > 0)
  printf("---- mem_write ----\n");
  #endif
  #if (DEBUG_LVL > 1)
  printf("---- mem_write - args  ----\n");
  printf("---- mem_ptr  @ 0x%p ----\n", mem_ptr);
  printf("---- addr     = 0x%llx ----\n", addr);
  printf("---- be       = 0x%x ----\n", be);
  printf("---- data     = 0x%llx ----\n", data);
  #endif
  for (t_size i = 0; i < 8; i++)
  {
    t_addr actual_addr = (addr+i) % (mem_ptr->size);
    if (be & 0x1) mem_ptr->data[actual_addr] = ((t_byte*)&data)[i];
    be >>= 1;
    #if (DEBUG_LVL > 1)
    if (addr+i >= mem_ptr->size)
      printf( "---- @ 0x%0llx >= memory size 0x%0llx"
              ", writing 0x%02x to @ 0x%0llx instead\n"
            , addr+i, mem_ptr->size, ((t_byte*)&data)[i], actual_addr );
    #endif
  }
}

void mem_clean (t_mem * mem_ptr)
{
  #if (DEBUG_LVL > 0)
  printf("---- mem_clean ----\n");
  #endif
  free(mem_ptr);
}

#ifdef __cplusplus
}
#endif
