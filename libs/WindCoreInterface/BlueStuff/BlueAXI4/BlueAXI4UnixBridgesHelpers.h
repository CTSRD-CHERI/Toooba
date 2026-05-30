#ifndef BLUE_AXI4_UNIX_BRIDGES_HELPERS_H
#define BLUE_AXI4_UNIX_BRIDGES_HELPERS_H

/*-
 * Copyright (c) 2022 Alexandre Joannou
 * All rights reserved.
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

// This header provides:
//
// flit types:
// - t_axi4_awflit
// - t_axi4_wflit
// - t_axi4_bflit
// - t_axi4_arflit
// - t_axi4_rflit
//
// Some parametric macros giving the sizes of flits in bits or bytes:
// - AXI4_AW_{BIT,BYTE}sz(IDsz,ADDRsz,AWUSERsz)
// - AXI4_W_{BIT,BYTE}sz(DATAsz,WUSERsz)
// - AXI4_B_{BIT,BYTE}sz(IDsz,BUSERsz)
// - AXI4_AR_{BIT,BYTE}sz(IDsz,ADDRsz,ARUSERsz)
// - AXI4_R_{BIT,BYTE}sz(IDsz,DATAsz,RUSERsz)
//
// Some parametric macros to add the API prefix to a symbol name:
// - AXI4_AW_(IDsz,ADDRsz,AWUSERsz,sym)
// - AXI4_W_(DATAsz,WUSERsz,sym)
// - AXI4_B_(IDsz,BUSERsz,sym)
// - AXI4_AR_(IDsz,ADDRsz,ARUSERsz,sym)
// - AXI4_R_(IDsz,DATAsz,RUSERsz,sym)
//
// A DEF_AXI4_HELPERS_API macro which defines the API functions for the given
// parameters (each function name starts with a parameterized prefix PFX of the
// form "baub_axi4_{aw,w,b,ar,r}_<params>")
//
// - PFX_get_<fieldname> (uint8_t* field, const uint8_t* rawflit)
// - PFX_set_<fieldname> (uint8_t* rawflit, const uint8_t* field)
// - PFX_get_flit (t_axi4_<CHANNEL>flit* flit, const uint8_t* raw_flit)
// - PFX_set_flit (uint8_t* raw_flit, const t_axi4_<CHANNEL>flit* flit)
// - PFX_deserialize_flit (void* flit, const uint8_t* raw_flit)
// - PFX_serialize_flit (uint8_t* raw_flit, const void* flit)
// - PFX_create_flit (const uint8_t* raw_flit)
// - PFX_destroy_flit (t_axi4_<CHANNEL>flit* flit)
// - PFX_print_flit (const t_axi4_<CHANNEL>flit* flit)

#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

// general helpers
////////////////////////////////////////////////////////////////////////////////

#define _MUL8(N) ((N)*8)
#define _DIV8(N) ((N)/8)
#define _MOD8(N) ((N)%8)
#define _DIV8CEIL(N) (((N)/8)+(((N)%8)?1:0))
#define _MASK8LO(N) (~(0xff<<(N)))
#define _MASK8HI(N) (~(0xff>>(N)))

static inline void *bitmemcpy( void *destArg, const size_t destBitOffset
                             , const void *srcArg, const size_t srcBitOffset
                             , const size_t bitLen ) {
  size_t completeBytes = bitLen / 8;
  size_t overflowBits = bitLen % 8;
  uint8_t* dest = (uint8_t*) destArg;
  uint8_t* src = (uint8_t*) srcArg;
  if (destBitOffset == 0 && srcBitOffset == 0) {
    memcpy (dest, src, completeBytes);
    if (overflowBits)
      dest[completeBytes] = src[completeBytes] & _MASK8LO(overflowBits);
  }
  else {
    int i = 0;
    uint8_t tmp = 0;
    do {
      tmp = src[i];
      if (srcBitOffset) {
        tmp >>= srcBitOffset;
        tmp  |= src[i+1] << (8-srcBitOffset);
      }
      dest[i] &= _MASK8LO(destBitOffset);
      dest[i] |= tmp << destBitOffset;
      if (destBitOffset) {
        dest[i+1] &= _MASK8HI(8-destBitOffset);
        dest[i+1] |= tmp >> (8-destBitOffset);
      }
      i++;
    } while (i < completeBytes);
  }
  return dest;
}

static inline void bitHexDump (const uint8_t* raw, size_t bitLen) {
  if (bitLen) {
    printf ("0x");
    size_t remain = _MOD8(bitLen);
    size_t complete = _DIV8(bitLen);
    if (remain) printf ("%02x", raw[complete] & _MASK8LO(remain));
    for (int i = complete-1; i >= 0; i--) printf ("%02x", raw[i]);
  } else printf ("x");
}

// AXI4 flit types
////////////////////////////////////////////////////////////////////////////////

typedef struct {
  uint8_t* awid;     // parametric size
  uint8_t* awaddr;   // parametric size
  uint8_t  awlen;    // 8 bits
  uint8_t  awsize;   // 3 bits
  uint8_t  awburst;  // 2 bits
  uint8_t  awlock;   // 1 bits
  uint8_t  awcache;  // 4 bits
  uint8_t  awprot;   // 3 bits
  uint8_t  awqos;    // 4 bits
  uint8_t  awregion; // 4 bits
  uint8_t* awuser;   // parametric size
} t_axi4_awflit;

typedef struct {
  uint8_t* wdata; // parametric size
  uint8_t* wstrb; // parametric size
  uint8_t  wlast; // 1 bit
  uint8_t* wuser; // parametric size
} t_axi4_wflit;

typedef struct {
  uint8_t* bid;   // parametric size
  uint8_t  bresp; // 2 bits
  uint8_t* buser; // parametric size
} t_axi4_bflit;

typedef struct {
  uint8_t* arid;     // parametric size
  uint8_t* araddr;   // parametric size
  uint8_t  arlen;    // 8 bits
  uint8_t  arsize;   // 3 bits
  uint8_t  arburst;  // 2 bits
  uint8_t  arlock;   // 1 bits
  uint8_t  arcache;  // 4 bits
  uint8_t  arprot;   // 3 bits
  uint8_t  arqos;    // 4 bits
  uint8_t  arregion; // 4 bits
  uint8_t* aruser;   // parametric size
} t_axi4_arflit;

typedef struct {
  uint8_t* rid;   // parametric size
  uint8_t* rdata; // parametric size
  uint8_t  rresp; // 2 bits
  uint8_t  rlast; // 1 bit
  uint8_t* ruser; // parametric size
} t_axi4_rflit;

// AXI4 basic helpers
////////////////////////////////////////////////////////////////////////////////

#define _LENsz 8
#define _LENmask 0b11111111
#define _SIZEsz 3
#define _SIZEmask 0b00000111
#define _BURSTsz 2
#define _BURSTmask 0b00000011
#define _LOCKsz 1
#define _LOCKmask 0b00000001
#define _CACHEsz 4
#define _CACHEmask 0b00001111
#define _PROTsz 3
#define _PROTmask 0b00000111
#define _QOSsz 4
#define _QOSmask 0b00001111
#define _REGIONsz 4
#define _REGIONmask 0b00001111
#define _RESPsz 2
#define _RESPmask 0b00000011
#define _LASTsz 1
#define _LASTmask 0b00000001

// AXI4 flit manipulation API
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

// AxFlit request helpers //
////////////////////////////////////////////////////////////////////////////////

// general form:
// FIELD_N+1_BYTE_IDX = FIELD_N_BYTE_IDX+(FIELD_N_BIT_IDX+FIELD_N_BIT_SIZE)/8
// FIELD_N+1_BIT_IDX  = (FIELD_N_BIT_IDX+FIELD_N_BIT_SIZE)%8

#define _AxUSER_BYTE_IDX(X,Y,Z) 0
#define _AxUSER_BIT_IDX(X,Y,Z) 0
#define _AxREGION_BYTE_IDX(X,Y,AxUSERsz) _DIV8(AxUSERsz)
#define _AxREGION_BIT_IDX(X,Y,AxUSERsz) _MOD8(AxUSERsz)
#define _AxQOS_BYTE_IDX(X,Y,Z) \
  (_AxREGION_BYTE_IDX(X,Y,Z)+_DIV8(_AxREGION_BIT_IDX(X,Y,Z)+_REGIONsz))
#define _AxQOS_BIT_IDX(X,Y,Z) _MOD8(_AxREGION_BIT_IDX(X,Y,Z)+_REGIONsz)
#define _AxPROT_BYTE_IDX(X,Y,Z) \
  (_AxQOS_BYTE_IDX(X,Y,Z)+_DIV8(_AxQOS_BIT_IDX(X,Y,Z)+_QOSsz))
#define _AxPROT_BIT_IDX(X,Y,Z) _MOD8(_AxQOS_BIT_IDX(X,Y,Z)+_QOSsz)
#define _AxCACHE_BYTE_IDX(X,Y,Z) \
  (_AxPROT_BYTE_IDX(X,Y,Z)+_DIV8(_AxPROT_BIT_IDX(X,Y,Z)+_PROTsz))
#define _AxCACHE_BIT_IDX(X,Y,Z) _MOD8(_AxPROT_BIT_IDX(X,Y,Z)+_PROTsz)
#define _AxLOCK_BYTE_IDX(X,Y,Z) \
  (_AxCACHE_BYTE_IDX(X,Y,Z)+_DIV8(_AxCACHE_BIT_IDX(X,Y,Z)+_CACHEsz))
#define _AxLOCK_BIT_IDX(X,Y,Z) _MOD8(_AxCACHE_BIT_IDX(X,Y,Z)+_CACHEsz)
#define _AxBURST_BYTE_IDX(X,Y,Z) \
  (_AxLOCK_BYTE_IDX(X,Y,Z)+_DIV8(_AxLOCK_BIT_IDX(X,Y,Z)+_LOCKsz))
#define _AxBURST_BIT_IDX(X,Y,Z) _MOD8(_AxLOCK_BIT_IDX(X,Y,Z)+_LOCKsz)
#define _AxSIZE_BYTE_IDX(X,Y,Z) \
  (_AxBURST_BYTE_IDX(X,Y,Z)+_DIV8(_AxBURST_BIT_IDX(X,Y,Z)+_BURSTsz))
#define _AxSIZE_BIT_IDX(X,Y,Z) _MOD8(_AxBURST_BIT_IDX(X,Y,Z)+_BURSTsz)
#define _AxLEN_BYTE_IDX(X,Y,Z) \
  (_AxSIZE_BYTE_IDX(X,Y,Z)+_DIV8(_AxSIZE_BIT_IDX(X,Y,Z)+_SIZEsz))
#define _AxLEN_BIT_IDX(X,Y,Z) _MOD8(_AxSIZE_BIT_IDX(X,Y,Z)+_SIZEsz)
#define _AxADDR_BYTE_IDX(X,Y,Z) \
  (_AxLEN_BYTE_IDX(X,Y,Z)+_DIV8(_AxLEN_BIT_IDX(X,Y,Z)+_LENsz))
#define _AxADDR_BIT_IDX(X,Y,Z) _MOD8(_AxLEN_BIT_IDX(X,Y,Z)+_LENsz)
#define _AxID_BYTE_IDX(X,ADDRsz,Z) \
  (_AxADDR_BYTE_IDX(X,ADDRsz,Z)+_DIV8(_AxADDR_BIT_IDX(X,ADDRsz,Z)+(ADDRsz)))
#define _AxID_BIT_IDX(X,ADDRsz,Z) _MOD8(_AxADDR_BIT_IDX(X,ADDRsz,Z)+(ADDRsz))

#define _AXI4_Ax_BITsz(IDsz,Y,Z) \
  (_MUL8(_AxID_BYTE_IDX(IDsz,Y,Z))+_AxID_BIT_IDX(IDsz,Y,Z)+(IDsz))

#define _AXI4_Ax_BYTEsz(X,Y,Z) _DIV8CEIL(_AXI4_Ax_BITsz(X,Y,Z))

#define _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,sym) \
  baub_axi4_a ## x ## _ ## IDsz ## _ ## ADDRsz ## _ ## AxUSERsz ## _ ## sym

#define _DEF_AXI4_AxFlit(x, IDsz, ADDRsz, AxUSERsz) \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## user) \
  (uint8_t* a ## x ## user, const uint8_t* a ## x ## flit) { \
  bitmemcpy ( a ## x ## user, 0 \
            , a ## x ## flit + _AxUSER_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxUSER_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , AxUSERsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## region) \
  (uint8_t* a ## x ## region, const uint8_t* a ## x ## flit) { \
  bitmemcpy ( a ## x ## region, 0 \
            , a ## x ## flit + _AxREGION_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxREGION_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _REGIONsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## qos) \
  (uint8_t* a ## x ## qos, const uint8_t* a ## x ## flit) { \
  bitmemcpy ( a ## x ## qos, 0 \
            , a ## x ## flit + _AxQOS_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxQOS_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _QOSsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## prot) \
  (uint8_t* a ## x ## prot, const uint8_t* a ## x ## flit) { \
  bitmemcpy ( a ## x ## prot, 0 \
            , a ## x ## flit + _AxPROT_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxPROT_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _PROTsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## cache) \
  (uint8_t* a ## x ## cache, const uint8_t* a ## x ## flit) { \
  bitmemcpy ( a ## x ## cache, 0 \
            , a ## x ## flit + _AxCACHE_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxCACHE_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _CACHEsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## lock) \
  (uint8_t* a ## x ## lock, const uint8_t* a ## x ## flit) { \
  bitmemcpy ( a ## x ## lock, 0 \
            , a ## x ## flit + _AxLOCK_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxLOCK_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _LOCKsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## burst) \
  (uint8_t* a ## x ## burst, const uint8_t* a ## x ## flit) { \
  bitmemcpy ( a ## x ## burst, 0 \
            , a ## x ## flit + _AxBURST_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxBURST_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _BURSTsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## size) \
  (uint8_t* a ## x ## size, const uint8_t* a ## x ## flit) { \
  bitmemcpy ( a ## x ## size, 0 \
            , a ## x ## flit + _AxSIZE_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxSIZE_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _SIZEsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## len) \
  (uint8_t* a ## x ## len, const uint8_t* a ## x ## flit) { \
  bitmemcpy ( a ## x ## len, 0 \
            , a ## x ## flit + _AxLEN_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxLEN_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _LENsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## addr) \
  (uint8_t* a ## x ## addr, const uint8_t* a ## x ## flit) { \
    bitmemcpy( a ## x ## addr, 0 \
             , a ## x ## flit + _AxADDR_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
             , _AxADDR_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
             , ADDRsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## id) \
  (uint8_t* a ## x ## id, const uint8_t* a ## x ## flit) { \
    bitmemcpy( a ## x ## id, 0 \
             , a ## x ## flit + _AxID_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
             , _AxID_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
             , IDsz ); \
} \
\
\
\
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## user) \
  (uint8_t* a ## x ## flit, const uint8_t* a ## x ## user) { \
  bitmemcpy ( a ## x ## flit + _AxUSER_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxUSER_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , a ## x ## user, 0 \
            , AxUSERsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## region) \
  (uint8_t* a ## x ## flit, const uint8_t* a ## x ## region) { \
  bitmemcpy ( a ## x ## flit + _AxREGION_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxREGION_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , a ## x ## region, 0 \
            , _REGIONsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## qos) \
  (uint8_t* a ## x ## flit, const uint8_t* a ## x ## qos) { \
  bitmemcpy ( a ## x ## flit + _AxQOS_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxQOS_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , a ## x ## qos, 0 \
            , _QOSsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## prot) \
  (uint8_t* a ## x ## flit, const uint8_t* a ## x ## prot) { \
  bitmemcpy ( a ## x ## flit + _AxPROT_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxPROT_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , a ## x ## prot, 0 \
            , _PROTsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## cache) \
  (uint8_t* a ## x ## flit, const uint8_t* a ## x ## cache) { \
  bitmemcpy ( a ## x ## flit + _AxCACHE_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxCACHE_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , a ## x ## cache, 0 \
            , _CACHEsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## lock) \
  (uint8_t* a ## x ## flit, const uint8_t* a ## x ## lock) { \
  bitmemcpy ( a ## x ## flit + _AxLOCK_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxLOCK_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , a ## x ## lock, 0 \
            , _LOCKsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## burst) \
  (uint8_t* a ## x ## flit, const uint8_t* a ## x ## burst) { \
  bitmemcpy ( a ## x ## flit + _AxBURST_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxBURST_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , a ## x ## burst, 0 \
            , _BURSTsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## size) \
  (uint8_t* a ## x ## flit, const uint8_t* a ## x ## size) { \
  bitmemcpy ( a ## x ## flit + _AxSIZE_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxSIZE_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , a ## x ## size, 0 \
            , _SIZEsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## len) \
  (uint8_t* a ## x ## flit, const uint8_t* a ## x ## len) { \
  bitmemcpy ( a ## x ## flit + _AxLEN_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxLEN_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , a ## x ## len, 0 \
            , _LENsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## addr) \
  (uint8_t* a ## x ## flit, const uint8_t* a ## x ## addr) { \
  bitmemcpy ( a ## x ## flit + _AxADDR_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxADDR_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , a ## x ## addr, 0 \
            , ADDRsz ); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## id) \
  (uint8_t* a ## x ## flit, const uint8_t* a ## x ## id) { \
  bitmemcpy ( a ## x ## flit + _AxID_BYTE_IDX(IDsz, ADDRsz, AxUSERsz) \
            , _AxID_BIT_IDX(IDsz, ADDRsz, AxUSERsz) \
            , a ## x ## id, 0 \
            , IDsz ); \
} \
\
\
\
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_flit) \
  (t_axi4_a ## x ## flit* a ## x ## flit, const uint8_t* raw_a ## x ## flit) { \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## user) \
    (a ## x ## flit->a ## x ## user, raw_a ## x ## flit); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## region) \
    (&a ## x ## flit->a ## x ## region, raw_a ## x ## flit ); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## qos) \
    (&a ## x ## flit->a ## x ## qos, raw_a ## x ## flit ); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## prot) \
    (&a ## x ## flit->a ## x ## prot, raw_a ## x ## flit ); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## cache) \
    (&a ## x ## flit->a ## x ## cache, raw_a ## x ## flit ); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## lock) \
    (&a ## x ## flit->a ## x ## lock, raw_a ## x ## flit ); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## burst) \
    (&a ## x ## flit->a ## x ## burst, raw_a ## x ## flit ); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## size) \
    (&a ## x ## flit->a ## x ## size, raw_a ## x ## flit ); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## len) \
    (&a ## x ## flit->a ## x ## len, raw_a ## x ## flit ); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## addr) \
    (a ## x ## flit->a ## x ## addr, raw_a ## x ## flit); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_a ## x ## id) \
    (a ## x ## flit->a ## x ## id, raw_a ## x ## flit); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_flit) \
  (uint8_t* raw_a ## x ## flit, const t_axi4_a ## x ## flit* a ## x ## flit) { \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## user) \
    (raw_a ## x ## flit, a ## x ## flit->a ## x ## user); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## region) \
    (raw_a ## x ## flit, &a ## x ## flit->a ## x ## region); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## qos) \
    (raw_a ## x ## flit, &a ## x ## flit->a ## x ## qos); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## prot) \
    (raw_a ## x ## flit, &a ## x ## flit->a ## x ## prot); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## cache) \
    (raw_a ## x ## flit, &a ## x ## flit->a ## x ## cache); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## lock) \
    (raw_a ## x ## flit, &a ## x ## flit->a ## x ## lock); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## burst) \
    (raw_a ## x ## flit, &a ## x ## flit->a ## x ## burst); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## size) \
    (raw_a ## x ## flit, &a ## x ## flit->a ## x ## size); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## len) \
    (raw_a ## x ## flit, &a ## x ## flit->a ## x ## len); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## addr) \
    (raw_a ## x ## flit, a ## x ## flit->a ## x ## addr); \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_a ## x ## id) \
    (raw_a ## x ## flit, a ## x ## flit->a ## x ## id); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,deserialize_flit) \
  (void* dest, const uint8_t* rawbytes) { \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_flit) (dest, rawbytes); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,serialize_flit) \
  (uint8_t* rawbytes, const void* src) { \
  _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,set_flit) (rawbytes, src); \
} \
t_axi4_a ## x ## flit* _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,create_flit) \
  (const uint8_t* raw_a ## x ## flit) { \
  t_axi4_a ## x ## flit* a ## x ## flit = \
    (t_axi4_a ## x ## flit*) malloc (sizeof (t_axi4_a ## x ## flit)); \
  a ## x ## flit->a ## x ## user = \
    (uint8_t*) malloc (_DIV8CEIL(AxUSERsz) * sizeof(uint8_t)); \
  a ## x ## flit->a ## x ## addr = \
    (uint8_t*) malloc (_DIV8CEIL(ADDRsz) * sizeof(uint8_t)); \
  a ## x ## flit->a ## x ## id = \
    (uint8_t*) malloc (_DIV8CEIL(IDsz) * sizeof(uint8_t)); \
  if (raw_a ## x ## flit) { \
    _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,get_flit) \
      (a ## x ## flit, raw_a ## x ## flit); \
  } \
  return a ## x ## flit; \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,destroy_flit) \
  (t_axi4_a ## x ## flit* a ## x ## flit) { \
  free (a ## x ## flit->a ## x ## id); \
  free (a ## x ## flit->a ## x ## addr); \
  free (a ## x ## flit->a ## x ## user); \
  free (a ## x ## flit); \
} \
void _AXI4_Ax_PFX(x,IDsz,ADDRsz,AxUSERsz,print_flit) \
  (const t_axi4_a ## x ## flit* flit) { \
  printf ("axi4_a" #x "flit {"); \
  printf (" a" #x "id: "); \
  bitHexDump (flit->a ## x ## id, IDsz); \
  printf (", a" #x "addr: "); \
  bitHexDump (flit->a ## x ## addr, ADDRsz); \
  printf (", a" #x "len: 0x%02x", flit->a ## x ## len & _LENmask); \
  printf (", a" #x "size: 0x%02x", flit->a ## x ## size & _SIZEmask); \
  printf (", a" #x "burst: 0x%02x", flit->a ## x ## burst & _BURSTmask); \
  printf (", a" #x "lock: 0x%02x", flit->a ## x ## lock & _LOCKmask); \
  printf (", a" #x "cache: 0x%02x", flit->a ## x ## cache & _CACHEmask); \
  printf (", a" #x "prot: 0x%02x", flit->a ## x ## prot & _PROTmask); \
  printf (", a" #x "qos: 0x%02x", flit->a ## x ## qos & _QOSmask); \
  printf (", a" #x "region: 0x%02x", flit->a ## x ## region & _REGIONmask); \
  printf (", a" #x "user: "); \
  bitHexDump (flit->a ## x ## user, AxUSERsz); \
  printf (" }"); \
}

// AWFlits //
////////////////////////////////////////////////////////////////////////////////

#define AXI4_AW_BITsz(IDsz, ADDRsz, AWUSERsz) \
  _AXI4_Ax_BITsz(IDsz, ADDRsz, AWUSERsz)

#define AXI4_AW_BYTEsz(IDsz, ADDRsz, AWUSERsz) \
  _AXI4_Ax_BYTEsz(IDsz, ADDRsz, AWUSERsz)

#define AXI4_AW_(IDsz,ADDRsz,AWUSERsz,sym) \
  _AXI4_Ax_PFX(w,IDsz,ADDRsz,AWUSERsz,sym)

#define DEF_AXI4_AWFlit(IDsz, ADDRsz, AWUSERsz) \
  _DEF_AXI4_AxFlit(w, IDsz, ADDRsz, AWUSERsz)

// WFlits //
////////////////////////////////////////////////////////////////////////////////

#define _WUSER_BYTE_IDX(X,Y) 0
#define _WUSER_BIT_IDX(X,Y) 0
#define _WLAST_BYTE_IDX(X,WUSERsz) _DIV8(WUSERsz)
#define _WLAST_BIT_IDX(X,WUSERsz) _MOD8(WUSERsz)
#define _WSTRB_BYTE_IDX(X,Y) \
  (_WLAST_BYTE_IDX(X,Y)+_DIV8(_WLAST_BIT_IDX(X,Y)+_LASTsz))
#define _WSTRB_BIT_IDX(X,Y) _MOD8(_WLAST_BIT_IDX(X,Y)+_LASTsz)
#define _WDATA_BYTE_IDX(DATAsz,Y) \
  (_WSTRB_BYTE_IDX(DATAsz,Y)+_DIV8(_WSTRB_BIT_IDX(DATAsz,Y)+_DIV8CEIL(DATAsz)))
#define _WDATA_BIT_IDX(DATAsz,Y) \
  _MOD8(_WSTRB_BIT_IDX(DATAsz,Y)+_DIV8CEIL(DATAsz))

#define AXI4_W_BITsz(DATAsz,Y) \
  (_MUL8(_WDATA_BYTE_IDX(DATAsz,Y))+_WDATA_BIT_IDX(DATAsz,Y)+(DATAsz))

#define AXI4_W_BYTEsz(X,Y) _DIV8CEIL(AXI4_W_BITsz(X,Y))

#define AXI4_W_(DATAsz,WUSERsz,sym) \
  baub_axi4_w_ ## DATAsz ## _ ## WUSERsz ## _ ## sym

#define DEF_AXI4_WFlit(DATAsz, WUSERsz) \
void AXI4_W_(DATAsz,WUSERsz,get_wuser) \
  (uint8_t* wuser, const uint8_t* wflit) { \
  bitmemcpy ( wuser, 0 \
            , wflit + _WUSER_BYTE_IDX(DATAsz, WUSERsz) \
            , _WUSER_BIT_IDX(DATAsz, WUSERsz) \
            , WUSERsz ); \
} \
void AXI4_W_(DATAsz,WUSERsz,get_wlast) \
  (uint8_t* wlast, const uint8_t* wflit) { \
  bitmemcpy ( wlast, 0 \
            , wflit + _WLAST_BYTE_IDX(DATAsz, WUSERsz) \
            , _WLAST_BIT_IDX(DATAsz, WUSERsz) \
            , _LASTsz ); \
} \
void AXI4_W_(DATAsz,WUSERsz,get_wstrb) \
  (uint8_t* wstrb, const uint8_t* wflit) { \
  bitmemcpy ( wstrb, 0 \
            , wflit + _WSTRB_BYTE_IDX(DATAsz, WUSERsz) \
            , _WSTRB_BIT_IDX(DATAsz, WUSERsz) \
            , _DIV8CEIL(DATAsz) ); \
} \
void AXI4_W_(DATAsz,WUSERsz,get_wdata) \
  (uint8_t* wdata, const uint8_t* wflit) { \
  bitmemcpy ( wdata, 0 \
            , wflit + _WDATA_BYTE_IDX(DATAsz, WUSERsz) \
            , _WDATA_BIT_IDX(DATAsz, WUSERsz) \
            , DATAsz ); \
} \
\
\
\
void AXI4_W_(DATAsz,WUSERsz,set_wuser) \
  (uint8_t* wflit, const uint8_t* wuser) { \
  bitmemcpy ( wflit + _WUSER_BYTE_IDX(DATAsz, WUSERsz) \
            , _WUSER_BIT_IDX(DATAsz, WUSERsz) \
            , wuser, 0 \
            , WUSERsz ); \
} \
void AXI4_W_(DATAsz,WUSERsz,set_wlast) \
  (uint8_t* wflit, const uint8_t* wlast) { \
  bitmemcpy ( wflit + _WLAST_BYTE_IDX(DATAsz, WUSERsz) \
            , _WLAST_BIT_IDX(DATAsz, WUSERsz) \
            , wlast, 0 \
            , _LASTsz ); \
} \
void AXI4_W_(DATAsz,WUSERsz,set_wstrb) \
  (uint8_t* wflit, const uint8_t* wstrb) { \
  bitmemcpy ( wflit + _WSTRB_BYTE_IDX(DATAsz, WUSERsz) \
            , _WSTRB_BIT_IDX(DATAsz, WUSERsz) \
            , wstrb, 0 \
            , _DIV8CEIL(DATAsz) ); \
} \
void AXI4_W_(DATAsz,WUSERsz,set_wdata) \
  (uint8_t* wflit, const uint8_t* wdata) { \
  bitmemcpy ( wflit + _WDATA_BYTE_IDX(DATAsz, WUSERsz) \
            , _WDATA_BIT_IDX(DATAsz, WUSERsz) \
            , wdata, 0 \
            , DATAsz ); \
} \
\
\
\
void AXI4_W_(DATAsz,WUSERsz,get_flit) \
  (t_axi4_wflit* wflit, const uint8_t* raw_wflit) { \
  AXI4_W_(DATAsz,WUSERsz,get_wuser) (wflit->wuser, raw_wflit); \
  AXI4_W_(DATAsz,WUSERsz,get_wlast) (&wflit->wlast, raw_wflit); \
  AXI4_W_(DATAsz,WUSERsz,get_wstrb) (wflit->wstrb, raw_wflit); \
  AXI4_W_(DATAsz,WUSERsz,get_wdata) (wflit->wdata, raw_wflit); \
} \
void AXI4_W_(DATAsz,WUSERsz,set_flit) \
  (uint8_t* raw_wflit, const t_axi4_wflit* wflit) { \
  AXI4_W_(DATAsz,WUSERsz,set_wuser) (raw_wflit, wflit->wuser); \
  AXI4_W_(DATAsz,WUSERsz,set_wlast) (raw_wflit, &wflit->wlast); \
  AXI4_W_(DATAsz,WUSERsz,set_wstrb) (raw_wflit, wflit->wstrb); \
  AXI4_W_(DATAsz,WUSERsz,set_wdata) (raw_wflit, wflit->wdata); \
} \
void AXI4_W_(DATAsz,WUSERsz,deserialize_flit) \
  (void* dest, const uint8_t* rawbytes) { \
  AXI4_W_(DATAsz,WUSERsz,get_flit) (dest, rawbytes); \
} \
void AXI4_W_(DATAsz,WUSERsz,serialize_flit) \
  (uint8_t* rawbytes, const void* src) { \
  AXI4_W_(DATAsz,WUSERsz,set_flit) (rawbytes, src); \
} \
t_axi4_wflit* AXI4_W_(DATAsz,WUSERsz,create_flit) \
  (const uint8_t* raw_wflit) { \
  t_axi4_wflit* wflit = (t_axi4_wflit*) malloc (sizeof (t_axi4_wflit)); \
  wflit->wuser = (uint8_t*) malloc (_DIV8CEIL(WUSERsz) * sizeof(uint8_t)); \
  wflit->wstrb = \
    (uint8_t*) malloc (_DIV8CEIL(_DIV8CEIL(DATAsz)) * sizeof(uint8_t)); \
  wflit->wdata = (uint8_t*) malloc (_DIV8CEIL(DATAsz) * sizeof(uint8_t)); \
  if (raw_wflit) { \
    AXI4_W_(DATAsz,WUSERsz,get_flit) (wflit, raw_wflit); \
  } \
  return wflit; \
} \
void AXI4_W_(DATAsz,WUSERsz,destroy_flit) (t_axi4_wflit* wflit) { \
  free (wflit->wdata); \
  free (wflit->wstrb); \
  free (wflit->wuser); \
  free (wflit); \
} \
void AXI4_W_(DATAsz,WUSERsz,print_flit) (const t_axi4_wflit* flit) { \
  printf ("axi4_wflit {"); \
  printf (" wdata: "); \
  bitHexDump (flit->wdata, DATAsz); \
  printf (" wstrb: "); \
  bitHexDump (flit->wstrb, _DIV8CEIL(DATAsz)); \
  printf (", wlast: 0x%02x", flit->wlast & _LASTmask); \
  printf (", wuser: "); \
  bitHexDump (flit->wuser, WUSERsz); \
  printf (" }"); \
}

// BFlits //
////////////////////////////////////////////////////////////////////////////////

#define _BUSER_BYTE_IDX(X,Y) 0
#define _BUSER_BIT_IDX(X,Y) 0
#define _BRESP_BYTE_IDX(X,BUSERsz) _DIV8(BUSERsz)
#define _BRESP_BIT_IDX(X,BUSERsz) _MOD8(BUSERsz)
#define _BID_BYTE_IDX(X,Y) \
  (_BRESP_BYTE_IDX(X,Y)+_DIV8(_BRESP_BIT_IDX(X,Y)+_RESPsz))
#define _BID_BIT_IDX(X,Y) _MOD8(_BRESP_BIT_IDX(X,Y)+_RESPsz)

#define AXI4_B_BITsz(IDsz,Y) \
  (_MUL8(_BID_BYTE_IDX(IDsz,Y))+_BID_BIT_IDX(IDsz,Y)+(IDsz))

#define AXI4_B_BYTEsz(X,Y) _DIV8CEIL(AXI4_B_BITsz(X,Y))

#define AXI4_B_(IDsz,BUSERsz,sym) \
  baub_axi4_b_ ## IDsz ## _ ## BUSERsz ## _ ## sym

#define DEF_AXI4_BFlit(IDsz, BUSERsz) \
void AXI4_B_(IDsz,BUSERsz,get_buser) (uint8_t* buser, const uint8_t* bflit) { \
  bitmemcpy ( buser, 0 \
            , bflit + _BUSER_BYTE_IDX(IDsz, BUSERsz) \
            , _BUSER_BIT_IDX(IDsz, BUSERsz) \
            , BUSERsz ); \
} \
void AXI4_B_(IDsz,BUSERsz,get_bresp) (uint8_t* bresp, const uint8_t* bflit) { \
  bitmemcpy ( bresp, 0 \
            , bflit + _BRESP_BYTE_IDX(IDsz, BUSERsz) \
            , _BRESP_BIT_IDX(IDsz, BUSERsz) \
            , _RESPsz ); \
} \
void AXI4_B_(IDsz,BUSERsz,get_bid) (uint8_t* bid, const uint8_t* bflit) { \
  bitmemcpy ( bid, 0 \
            , bflit + _BID_BYTE_IDX(IDsz, BUSERsz) \
            , _BID_BIT_IDX(IDsz, BUSERsz) \
            , IDsz ); \
} \
\
\
\
void AXI4_B_(IDsz,BUSERsz,set_buser) (uint8_t* bflit, const uint8_t* buser) { \
  bitmemcpy ( bflit + _BUSER_BYTE_IDX(IDsz, BUSERsz) \
            , _BUSER_BIT_IDX(IDsz, BUSERsz) \
            , buser, 0 \
            , BUSERsz ); \
} \
void AXI4_B_(IDsz,BUSERsz,set_bresp) (uint8_t* bflit, const uint8_t* bresp) { \
  bitmemcpy ( bflit + _BRESP_BYTE_IDX(IDsz, BUSERsz) \
            , _BRESP_BIT_IDX(IDsz, BUSERsz) \
            , bresp, 0 \
            , _RESPsz ); \
} \
void AXI4_B_(IDsz,BUSERsz,set_bid) (uint8_t* bflit, const uint8_t* bid) { \
  bitmemcpy ( bflit + _BID_BYTE_IDX(IDsz, BUSERsz) \
            , _BID_BIT_IDX(IDsz, BUSERsz) \
            , bid, 0 \
            , IDsz ); \
} \
\
\
\
void AXI4_B_(IDsz,BUSERsz,get_flit) \
  (t_axi4_bflit* bflit, const uint8_t* raw_bflit) { \
  AXI4_B_(IDsz,BUSERsz,get_buser) (bflit->buser, raw_bflit); \
  AXI4_B_(IDsz,BUSERsz,get_bresp) (&bflit->bresp, raw_bflit); \
  AXI4_B_(IDsz,BUSERsz,get_bid) (bflit->bid, raw_bflit); \
} \
void AXI4_B_(IDsz,BUSERsz,set_flit) \
  (uint8_t* raw_bflit, const t_axi4_bflit* bflit) { \
  AXI4_B_(IDsz,BUSERsz,set_buser) (raw_bflit, bflit->buser); \
  AXI4_B_(IDsz,BUSERsz,set_bresp) (raw_bflit, &bflit->bresp); \
  AXI4_B_(IDsz,BUSERsz,set_bid) (raw_bflit, bflit->bid); \
} \
void AXI4_B_(IDsz,BUSERsz,deserialize_flit) \
  (void* dest, const uint8_t* rawbytes) { \
  AXI4_B_(IDsz,BUSERsz,get_flit) (dest, rawbytes); \
} \
void AXI4_B_(IDsz,BUSERsz,serialize_flit) \
  (uint8_t* rawbytes, const void* src) { \
  AXI4_B_(IDsz,BUSERsz,set_flit) (rawbytes, src); \
} \
t_axi4_bflit* AXI4_B_(IDsz,BUSERsz,create_flit) (const uint8_t* raw_bflit) { \
  t_axi4_bflit* bflit = (t_axi4_bflit*) malloc (sizeof (t_axi4_bflit)); \
  bflit->buser = (uint8_t*) malloc (_DIV8CEIL(BUSERsz) * sizeof(uint8_t)); \
  bflit->bid = (uint8_t*) malloc (_DIV8CEIL(IDsz) * sizeof(uint8_t)); \
  if (raw_bflit) { \
    AXI4_B_(IDsz,BUSERsz,get_flit) (bflit, raw_bflit); \
  } \
  return bflit; \
} \
void AXI4_B_(IDsz,BUSERsz,destroy_flit) (t_axi4_bflit* bflit) { \
  free (bflit->bid); \
  free (bflit->buser); \
  free (bflit); \
} \
void AXI4_B_(IDsz,BUSERsz,print_flit) (const t_axi4_bflit* flit) { \
  printf ("axi4_bflit {"); \
  printf (" bid: "); \
  bitHexDump (flit->bid, IDsz); \
  printf (", bresp: 0x%02x", flit->bresp & _RESPmask); \
  printf (", buser: "); \
  bitHexDump (flit->buser, BUSERsz); \
  printf (" }"); \
}

// ARFlits //
////////////////////////////////////////////////////////////////////////////////

#define AXI4_AR_BITsz(IDsz, ADDRsz, ARUSERsz) \
  _AXI4_Ax_BITsz(IDsz, ADDRsz, ARUSERsz)

#define AXI4_AR_BYTEsz(IDsz, ADDRsz, ARUSERsz) \
  _AXI4_Ax_BYTEsz(IDsz, ADDRsz, ARUSERsz)

#define AXI4_AR_(IDsz,ADDRsz,AWUSERsz,sym) \
  _AXI4_Ax_PFX(r,IDsz,ADDRsz,AWUSERsz,sym)

#define DEF_AXI4_ARFlit(IDsz, ADDRsz, ARUSERsz) \
  _DEF_AXI4_AxFlit(r, IDsz, ADDRsz, ARUSERsz)

// RFlits //
////////////////////////////////////////////////////////////////////////////////

#define _RUSER_BYTE_IDX(X,Y,Z) 0
#define _RUSER_BIT_IDX(X,Y,Z) 0
#define _RLAST_BYTE_IDX(X,Y,RUSERsz) _DIV8(RUSERsz)
#define _RLAST_BIT_IDX(X,Y,RUSERsz) _MOD8(RUSERsz)
#define _RRESP_BYTE_IDX(X,Y,Z) \
  (_RLAST_BYTE_IDX(X,Y,Z)+_DIV8(_RLAST_BIT_IDX(X,Y,Z)+_LASTsz))
#define _RRESP_BIT_IDX(X,Y,Z) _MOD8(_RLAST_BIT_IDX(X,Y,Z)+_LASTsz)
#define _RDATA_BYTE_IDX(X,Y,Z) \
  (_RRESP_BYTE_IDX(X,Y,Z)+_DIV8(_RRESP_BIT_IDX(X,Y,Z)+_RESPsz))
#define _RDATA_BIT_IDX(X,Y,Z) _MOD8(_RRESP_BIT_IDX(X,Y,Z)+_RESPsz)
#define _RID_BYTE_IDX(X,DATAsz,Z) \
  (_RDATA_BYTE_IDX(X,DATAsz,Z)+_DIV8(_RDATA_BIT_IDX(X,DATAsz,Z)+DATAsz))
#define _RID_BIT_IDX(X,DATAsz,Z) _MOD8(_RDATA_BIT_IDX(X,DATAsz,Z)+DATAsz)

#define AXI4_R_BITsz(IDsz,Y,Z) \
  (_MUL8(_RID_BYTE_IDX(IDsz,Y,Z))+_RID_BIT_IDX(IDsz,Y,Z)+(IDsz))

#define AXI4_R_BYTEsz(X,Y,Z) _DIV8CEIL(AXI4_R_BITsz(X,Y,Z))

#define AXI4_R_(IDsz,DATAsz,RUSERsz,sym) \
  baub_axi4_rflit_ ## IDsz ## _ ## DATAsz ## _ ## RUSERsz ## _ ## sym

#define DEF_AXI4_RFlit(IDsz, DATAsz, RUSERsz) \
void AXI4_R_(IDsz,DATAsz,RUSERsz,get_ruser) \
  (uint8_t* ruser, const uint8_t* rflit) { \
  bitmemcpy ( ruser, 0 \
            , rflit + _RUSER_BYTE_IDX(IDsz, DATAsz, RUSERsz) \
            , _RUSER_BIT_IDX(IDsz, DATAsz, RUSERsz) \
            , RUSERsz ); \
} \
void AXI4_R_(IDsz,DATAsz,RUSERsz,get_rlast) \
  (uint8_t* rlast, const uint8_t* rflit) { \
  bitmemcpy ( rlast, 0 \
            , rflit + _RLAST_BYTE_IDX(IDsz, DATAsz, RUSERsz) \
            , _RLAST_BIT_IDX(IDsz, DATAsz, RUSERsz) \
            , _LASTsz ); \
} \
void AXI4_R_(IDsz,DATAsz,RUSERsz,get_rresp) \
  (uint8_t* rresp, const uint8_t* rflit) { \
  bitmemcpy ( rresp, 0 \
            , rflit + _RRESP_BYTE_IDX(IDsz, DATAsz, RUSERsz) \
            , _RRESP_BIT_IDX(IDsz, DATAsz, RUSERsz) \
            , _RESPsz ); \
} \
void AXI4_R_(IDsz,DATAsz,RUSERsz,get_rdata) \
  (uint8_t* rdata, const uint8_t* rflit) { \
  bitmemcpy ( rdata, 0 \
            , rflit + _RDATA_BYTE_IDX(IDsz, DATAsz, RUSERsz) \
            , _RDATA_BIT_IDX(IDsz, DATAsz, RUSERsz) \
            , DATAsz ); \
} \
void AXI4_R_(IDsz,DATAsz,RUSERsz,get_rid) \
  (uint8_t* rid, const uint8_t* rflit) { \
  bitmemcpy ( rid, 0 \
            , rflit + _RID_BYTE_IDX(IDsz, DATAsz, RUSERsz) \
            , _RID_BIT_IDX(IDsz, DATAsz, RUSERsz) \
            , IDsz ); \
} \
\
\
\
void AXI4_R_(IDsz,DATAsz,RUSERsz,set_ruser) \
  (uint8_t* rflit, const uint8_t* ruser) { \
  bitmemcpy ( rflit + _RUSER_BYTE_IDX(IDsz, DATAsz, RUSERsz) \
            , _RUSER_BIT_IDX(IDsz, DATAsz, RUSERsz) \
            , ruser, 0 \
            , RUSERsz ); \
} \
void AXI4_R_(IDsz,DATAsz,RUSERsz,set_rlast) \
  (uint8_t* rflit, const uint8_t* rlast) { \
  bitmemcpy ( rflit + _RLAST_BYTE_IDX(IDsz, DATAsz, RUSERsz) \
            , _RLAST_BIT_IDX(IDsz, DATAsz, RUSERsz) \
            , rlast, 0 \
            , _LASTsz ); \
} \
void AXI4_R_(IDsz,DATAsz,RUSERsz,set_rresp) \
  (uint8_t* rflit, const uint8_t* rresp) { \
  bitmemcpy ( rflit + _RRESP_BYTE_IDX(IDsz, DATAsz, RUSERsz) \
            , _RRESP_BIT_IDX(IDsz, DATAsz, RUSERsz) \
            , rresp, 0 \
            , _RESPsz ); \
} \
void AXI4_R_(IDsz,DATAsz,RUSERsz,set_rdata) \
  (uint8_t* rflit, const uint8_t* rdata) { \
  bitmemcpy ( rflit + _RDATA_BYTE_IDX(IDsz, DATAsz, RUSERsz) \
            , _RDATA_BIT_IDX(IDsz, DATAsz, RUSERsz) \
            , rdata, 0 \
            , DATAsz ); \
} \
void AXI4_R_(IDsz,DATAsz,RUSERsz,set_rid) \
  (uint8_t* rflit, const uint8_t* rid) { \
  bitmemcpy ( rflit + _RID_BYTE_IDX(IDsz, DATAsz, RUSERsz) \
            , _RID_BIT_IDX(IDsz, DATAsz, RUSERsz) \
            , rid, 0 \
            , IDsz ); \
} \
\
\
\
void AXI4_R_(IDsz,DATAsz,RUSERsz,get_flit) \
  (t_axi4_rflit* rflit, const uint8_t* raw_rflit) { \
  AXI4_R_(IDsz,DATAsz,RUSERsz,get_ruser) (rflit->ruser, raw_rflit); \
  AXI4_R_(IDsz,DATAsz,RUSERsz,get_rlast) (&rflit->rlast, raw_rflit); \
  AXI4_R_(IDsz,DATAsz,RUSERsz,get_rresp) (&rflit->rresp, raw_rflit); \
  AXI4_R_(IDsz,DATAsz,RUSERsz,get_rdata) (rflit->rdata, raw_rflit); \
  AXI4_R_(IDsz,DATAsz,RUSERsz,get_rid) (rflit->rid, raw_rflit); \
} \
void AXI4_R_(IDsz,DATAsz,RUSERsz,set_flit) \
  (uint8_t* raw_rflit, const t_axi4_rflit* rflit) { \
  AXI4_R_(IDsz,DATAsz,RUSERsz,set_ruser) (raw_rflit, rflit->ruser); \
  AXI4_R_(IDsz,DATAsz,RUSERsz,set_rlast) (raw_rflit, &rflit->rlast); \
  AXI4_R_(IDsz,DATAsz,RUSERsz,set_rresp) (raw_rflit, &rflit->rresp); \
  AXI4_R_(IDsz,DATAsz,RUSERsz,set_rdata) (raw_rflit, rflit->rdata); \
  AXI4_R_(IDsz,DATAsz,RUSERsz,set_rid) (raw_rflit, rflit->rid); \
} \
void AXI4_R_(IDsz,DATAsz,RUSERsz,deserialize_flit) \
  (void* dest, const uint8_t* rawbytes) { \
  AXI4_R_(IDsz,DATAsz,RUSERsz,get_flit) (dest, rawbytes); \
} \
void AXI4_R_(IDsz,DATAsz,RUSERsz,serialize_flit) \
  (uint8_t* rawbytes, const void* src) { \
  AXI4_R_(IDsz,DATAsz,RUSERsz,set_flit) (rawbytes, src); \
} \
t_axi4_rflit* AXI4_R_(IDsz,DATAsz,RUSERsz,create_flit) \
  (const uint8_t* raw_rflit) { \
  t_axi4_rflit* rflit = (t_axi4_rflit*) malloc (sizeof (t_axi4_rflit)); \
  rflit->ruser = (uint8_t*) malloc (_DIV8CEIL(RUSERsz) * sizeof(uint8_t)); \
  rflit->rdata = (uint8_t*) malloc (_DIV8CEIL(DATAsz) * sizeof(uint8_t)); \
  rflit->rid = (uint8_t*) malloc (_DIV8CEIL(IDsz) * sizeof(uint8_t)); \
  if (raw_rflit) { \
    AXI4_R_(IDsz,DATAsz,RUSERsz,get_flit) (rflit, raw_rflit); \
  } \
  return rflit; \
} \
void AXI4_R_(IDsz,DATAsz,RUSERsz,destroy_flit) (t_axi4_rflit* rflit) { \
  free (rflit->rid); \
  free (rflit->rdata); \
  free (rflit->ruser); \
  free (rflit); \
} \
void AXI4_R_(IDsz,DATAsz,RUSERsz,print_flit) (const t_axi4_rflit* flit) { \
  printf ("axi4_rflit {"); \
  printf (" rid: "); \
  bitHexDump (flit->rid, IDsz); \
  printf (" rdata: "); \
  bitHexDump (flit->rdata, DATAsz); \
  printf (", rresp: 0x%02x", flit->rresp & _RESPmask); \
  printf (", rlast: 0x%02x", flit->rlast & _LASTmask); \
  printf (", ruser: "); \
  bitHexDump (flit->ruser, RUSERsz); \
  printf (" }"); \
}

// AXI4 fully parameterized definitions
////////////////////////////////////////////////////////////////////////////////

#define DEF_AXI4_HEPLERS_API(IDsz, ADDRsz, DATAsz, AWsz, Wsz, Bsz, ARsz, Rsz) \
  DEF_AXI4_AWFlit(IDsz, ADDRsz, AWsz) \
  DEF_AXI4_WFlit(DATAsz, Wsz) \
  DEF_AXI4_BFlit(IDsz, Bsz) \
  DEF_AXI4_ARFlit(IDsz, ADDRsz, ARsz) \
  DEF_AXI4_RFlit(IDsz, DATAsz, Rsz)

#endif
