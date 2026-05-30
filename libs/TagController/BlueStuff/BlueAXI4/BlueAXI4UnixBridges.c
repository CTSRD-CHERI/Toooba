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

#include <BlueUnixBridges.h>
#include <BlueAXI4UnixBridges.h>

inline baub_port_fifo_desc_t* baub_fifo_OpenChannelsAsMaster
  ( char* awSrc_path, size_t awSrc_bytesize, deserializer_t awSrc_deserializer
  , char* wSrc_path, size_t wSrc_bytesize, deserializer_t wSrc_deserializer
  , char* bSnk_path, size_t bSnk_bytesize, serializer_t bSnk_serializer
  , char* arSrc_path, size_t arSrc_bytesize, deserializer_t arSrc_deserializer
  , char* rSnk_path, size_t rSnk_bytesize, serializer_t rSnk_serializer ) {
  baub_port_fifo_desc_t* desc =
    (baub_port_fifo_desc_t*) malloc (sizeof (baub_port_fifo_desc_t));
  desc->aw = bub_fifo_OpenForConsumption ( awSrc_path
                                         , awSrc_bytesize
                                         , awSrc_deserializer );
  desc->w =
    bub_fifo_OpenForConsumption (wSrc_path, wSrc_bytesize, wSrc_deserializer);
  desc->b =
    bub_fifo_OpenForProduction (bSnk_path, bSnk_bytesize, bSnk_serializer);
  desc->ar = bub_fifo_OpenForConsumption ( arSrc_path
                                         , arSrc_bytesize
                                         , arSrc_deserializer );
  desc->r =
    bub_fifo_OpenForProduction (rSnk_path, rSnk_bytesize, rSnk_serializer);
  return desc;
}

inline baub_port_fifo_desc_t* baub_fifo_OpenChannelsAsSlave
  ( char* awSnk_path, size_t awSnk_bytesize, serializer_t awSnk_serializer
  , char* wSnk_path, size_t wSnk_bytesize, serializer_t wSnk_serializer
  , char* bSrc_path, size_t bSrc_bytesize, deserializer_t bSrc_deserializer
  , char* arSnk_path, size_t arSnk_bytesize, serializer_t arSnk_serializer
  , char* rSrc_path, size_t rSrc_bytesize, deserializer_t rSrc_deserializer ) {
  baub_port_fifo_desc_t* desc =
    (baub_port_fifo_desc_t*) malloc (sizeof (baub_port_fifo_desc_t));
  desc->aw =
    bub_fifo_OpenForProduction (awSnk_path, awSnk_bytesize, awSnk_serializer);
  desc->w =
    bub_fifo_OpenForProduction (wSnk_path, wSnk_bytesize, wSnk_serializer);
  desc->b =
    bub_fifo_OpenForConsumption (bSrc_path, bSrc_bytesize, bSrc_deserializer);
  desc->ar =
    bub_fifo_OpenForProduction (arSnk_path, arSnk_bytesize, arSnk_serializer);
  desc->r =
    bub_fifo_OpenForConsumption (rSrc_path, rSrc_bytesize, rSrc_deserializer);
  return desc;
}

inline void baub_fifo_Close (baub_port_fifo_desc_t* desc) {
  bub_fifo_Close (desc->aw);
  bub_fifo_Close (desc->w);
  bub_fifo_Close (desc->b);
  bub_fifo_Close (desc->ar);
  bub_fifo_Close (desc->r);
}
