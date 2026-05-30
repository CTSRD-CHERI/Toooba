#ifndef BLUE_AXI4_UNIX_BRIDGES_H
#define BLUE_AXI4_UNIX_BRIDGES_H

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

// This header declares the BlueUnixFifo API for C client, as well as the C
// functions to be wrapped in Bluespec SystemVerilog BDPI calls for use in
// BSV simulator code.

#include <BlueUnixBridges.h>
#include "BlueAXI4UnixBridgesHelpers.h"

// An AXI4UnixFifo port descriptor
typedef struct {
  bub_fifo_desc_t aw;
  bub_fifo_desc_t  w;
  bub_fifo_desc_t  b;
  bub_fifo_desc_t ar;
  bub_fifo_desc_t  r;
} baub_port_fifo_desc_t;

// AXI4 Unix Bridges Fifo API
////////////////////////////////////////////////////////////////////////////////

#ifdef __cplusplus
extern "C" {
#endif

baub_port_fifo_desc_t* baub_fifo_OpenChannelsAsMaster
  ( char* awSrc_path, size_t awSrc_bytesize, deserializer_t awSrc_deserializer
  , char* wSrc_path, size_t wSrc_bytesize, deserializer_t wSrc_deserializer
  , char* bSnk_path, size_t bSnk_bytesize, serializer_t bSnk_serializer
  , char* arSrc_path, size_t arSrc_bytesize, deserializer_t arSrc_deserializer
  , char* rSnk_path, size_t rSnk_bytesize, serializer_t rSnk_serializer );
baub_port_fifo_desc_t* baub_fifo_OpenChannelsAsSlave
  ( char* awSnk_path, size_t awSnk_bytesize, serializer_t awSnk_serializer
  , char* wSnk_path, size_t wSnk_bytesize, serializer_t wSnk_serializer
  , char* bSrc_path, size_t bSrc_bytesize, deserializer_t bSrc_deserializer
  , char* arSnk_path, size_t arSnk_bytesize, serializer_t arSnk_serializer
  , char* rSrc_path, size_t rSrc_bytesize, deserializer_t rSrc_deserializer );
void baub_fifo_Close (baub_port_fifo_desc_t* desc);

#define AXI4_(IDsz,ADDRsz,DATAsz,AWsz,Wsz,Bsz,ARsz,Rsz,sym) \
  baub_axi4_ ## IDsz ## _ ## ADDRsz ## _ ## DATAsz ## _ \
             ## AWsz ## _ ## Wsz ## _ ## Bsz ## _ ## ARsz ## _ ## Rsz ## _ \
             ## sym

#define DEF_AXI4_API(IDsz, ADDRsz, DATAsz, AWsz, Wsz, Bsz, ARsz, Rsz) \
  DEF_AXI4_HEPLERS_API(IDsz, ADDRsz, DATAsz, AWsz, Wsz, Bsz, ARsz, Rsz) \
baub_port_fifo_desc_t* \
  AXI4_(IDsz, ADDRsz, DATAsz, AWsz, Wsz, Bsz, ARsz, Rsz, fifo_OpenAsMaster) \
  (char* path) { \
  size_t len = strlen (path) + 10; \
  char* awSrc_path = (char*) malloc (len * sizeof(char)); \
  char*  wSrc_path = (char*) malloc (len * sizeof(char)); \
  char*  bSnk_path = (char*) malloc (len * sizeof(char)); \
  char* arSrc_path = (char*) malloc (len * sizeof(char)); \
  char*  rSnk_path = (char*) malloc (len * sizeof(char)); \
  strcpy (awSrc_path, path); \
  strcpy ( wSrc_path, path); \
  strcpy ( bSnk_path, path); \
  strcpy (arSrc_path, path); \
  strcpy ( rSnk_path, path); \
  strcat (awSrc_path, "/awSource"); \
  strcat ( wSrc_path,  "/wSource"); \
  strcat ( bSnk_path,    "/bSink"); \
  strcat (arSrc_path, "/arSource"); \
  strcat ( rSnk_path,    "/rSink"); \
  baub_port_fifo_desc_t* mstrDesc = baub_fifo_OpenChannelsAsMaster \
    ( awSrc_path, AXI4_AW_BYTEsz(IDsz,ADDRsz,AWsz) \
                , &AXI4_AW_(IDsz,ADDRsz,AWsz,deserialize_flit) \
    ,  wSrc_path, AXI4_W_BYTEsz(DATAsz,Wsz), &AXI4_W_(DATAsz,Wsz,deserialize_flit) \
    ,  bSnk_path, AXI4_B_BYTEsz(IDsz,Bsz), &AXI4_B_(IDsz,Bsz,serialize_flit) \
    , arSrc_path, AXI4_AR_BYTEsz(IDsz,ADDRsz,ARsz) \
                , &AXI4_AR_(IDsz,ADDRsz,ARsz,deserialize_flit) \
    ,  rSnk_path, AXI4_R_BYTEsz(IDsz,DATAsz,Rsz) \
                , &AXI4_R_(IDsz,DATAsz,Rsz,serialize_flit) ); \
  printf("opened axi4 master port:\n"); \
  printf( "\taw: %s, %0d bytes (from %0d bits), decoder: %p\n" \
        , awSrc_path \
        , AXI4_AW_BYTEsz(IDsz,ADDRsz,AWsz) \
        , AXI4_AW_BITsz(IDsz,ADDRsz,AWsz) \
        , &AXI4_AW_(IDsz,ADDRsz,AWsz,deserialize_flit)); \
  printf( "\tw: %s, %0d bytes (from %0d bits), decoder: %p\n" \
        , wSrc_path \
        , AXI4_W_BYTEsz(DATAsz,Wsz) \
        , AXI4_W_BITsz(DATAsz,Wsz) \
        , &AXI4_W_(DATAsz,Wsz,deserialize_flit)); \
  printf( "\tb: %s, %0d bytes (from %0d bits), encoder: %p\n" \
        , bSnk_path \
        , AXI4_B_BYTEsz(IDsz,Bsz) \
        , AXI4_B_BITsz(IDsz,Bsz) \
        , &AXI4_B_(IDsz,Bsz,serialize_flit)); \
  printf( "\tar: %s, %0d bytes (from %0d bits), decoder: %p\n" \
        , arSrc_path \
        , AXI4_AR_BYTEsz(IDsz,ADDRsz,ARsz) \
        , AXI4_AR_BITsz(IDsz,ADDRsz,ARsz) \
        , &AXI4_AR_(IDsz,ADDRsz,ARsz,deserialize_flit)); \
  printf( "\tr: %s, %0d bytes (from %0d bits), encoder: %p\n" \
        , rSnk_path \
        , AXI4_R_BYTEsz(IDsz,DATAsz,Rsz) \
        , AXI4_R_BITsz(IDsz,DATAsz,Rsz) \
        , &AXI4_R_(IDsz,DATAsz,Rsz,serialize_flit)); \
  return mstrDesc; \
} \
baub_port_fifo_desc_t* \
  AXI4_(IDsz, ADDRsz, DATAsz, AWsz, Wsz, Bsz, ARsz, Rsz, fifo_OpenAsSlave) \
  (char* path) { \
  size_t len = strlen (path) + 10; \
  char* awSnk_path = (char*) malloc (len * sizeof(char)); \
  char*  wSnk_path = (char*) malloc (len * sizeof(char)); \
  char*  bSrc_path = (char*) malloc (len * sizeof(char)); \
  char* arSnk_path = (char*) malloc (len * sizeof(char)); \
  char*  rSrc_path = (char*) malloc (len * sizeof(char)); \
  strcpy (awSnk_path, path); \
  strcpy ( wSnk_path, path); \
  strcpy ( bSrc_path, path); \
  strcpy (arSnk_path, path); \
  strcpy ( rSrc_path, path); \
  strcat (awSnk_path,  "/awSink"); \
  strcat ( wSnk_path,   "/wSink"); \
  strcat ( bSrc_path, "/bSource"); \
  strcat (arSnk_path,  "/arSink"); \
  strcat ( rSrc_path, "/rSource"); \
  baub_port_fifo_desc_t* slvDesc = baub_fifo_OpenChannelsAsSlave \
    ( awSnk_path, AXI4_AW_BYTEsz(IDsz,ADDRsz,AWsz) \
                , &AXI4_AW_(IDsz,ADDRsz,AWsz,serialize_flit) \
    ,  wSnk_path, AXI4_W_BYTEsz(DATAsz,Wsz), &AXI4_W_(DATAsz,Wsz,serialize_flit) \
    ,  bSrc_path, AXI4_B_BYTEsz(IDsz,Bsz), &AXI4_B_(IDsz,Bsz,deserialize_flit) \
    , arSnk_path, AXI4_AR_BYTEsz(IDsz,ADDRsz,ARsz) \
                , &AXI4_AR_(IDsz,ADDRsz,ARsz,serialize_flit) \
    ,  rSrc_path, AXI4_R_BYTEsz(IDsz,DATAsz,Rsz) \
                , &AXI4_R_(IDsz,DATAsz,Rsz,deserialize_flit) ); \
  printf("opened axi4 slave port:\n"); \
  printf( "\taw: %s, %0d bytes (from %0d bits), encoder: %p\n" \
        , awSnk_path \
        , AXI4_AW_BYTEsz(IDsz,ADDRsz,AWsz) \
        , AXI4_AW_BITsz(IDsz,ADDRsz,AWsz) \
        , &AXI4_AW_(IDsz,ADDRsz,AWsz,serialize_flit)); \
  printf( "\tw: %s, %0d bytes (from %0d bits), encoder: %p\n" \
        , wSnk_path \
        , AXI4_W_BYTEsz(DATAsz,Wsz) \
        , AXI4_W_BITsz(DATAsz,Wsz) \
        , &AXI4_W_(DATAsz,Wsz,serialize_flit)); \
  printf( "\tb: %s, %0d bytes (from %0d bits), decoder: %p\n" \
        , bSrc_path \
        , AXI4_B_BYTEsz(IDsz,Bsz) \
        , AXI4_B_BITsz(IDsz,Bsz) \
        , &AXI4_B_(IDsz,Bsz,deserialize_flit)); \
  printf( "\tar: %s, %0d bytes (from %0d bits), encoder: %p\n" \
        , arSnk_path \
        , AXI4_AR_BYTEsz(IDsz,ADDRsz,ARsz) \
        , AXI4_AR_BITsz(IDsz,ADDRsz,ARsz) \
        , &AXI4_AR_(IDsz,ADDRsz,ARsz,serialize_flit)); \
  printf( "\tr: %s, %0d bytes (from %0d bits), decoder: %p\n" \
        , rSrc_path \
        , AXI4_R_BYTEsz(IDsz,DATAsz,Rsz) \
        , AXI4_R_BITsz(IDsz,DATAsz,Rsz) \
        , &AXI4_R_(IDsz,DATAsz,Rsz,deserialize_flit)); \
  return slvDesc; \
}

#ifdef __cplusplus
}
#endif

#endif
