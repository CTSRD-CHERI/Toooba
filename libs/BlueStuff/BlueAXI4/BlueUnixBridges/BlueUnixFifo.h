#ifndef BLUE_UNIX_FIFO_H
#define BLUE_UNIX_FIFO_H

/*-
 * Copyright (c) 2022-2023 Alexandre Joannou
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

#include <stdint.h>
#include <stdlib.h>

// A function pointer to a callback helper turning `serialized_rawbytes_src` (a
// raw array of bytes) into a more useful C type stored in a previously
// allocated buffer pointed to by `structured_dest`.
// (notionally equivalent to BSV's unpack)
typedef void (*deserializer_t) ( void* structured_dest
                               , const uint8_t* serialized_rawbytes_src );
// A function pointer to a callback helper turning `structured_src` (a
// structured C type) into a raw array of bytes in a previously allocated buffer
// pointed to by `serialized_rawbytes_dest`.
// (notionally equivalent to BSV's pack)
typedef void (*serializer_t) ( uint8_t* serialized_rawbytes_dest
                             , const void* structured_src );
// A (opaque) BlueUnixFifo descriptor
typedef struct bub_fifo_fields_opaque* bub_fifo_desc_t;

// BlueUnixBridges fifo API
////////////////////////////////////////////////////////////////////////////////
// Open the unix fifo `pathname` as readable to allow consumption of elements
// of `bytesize` bytes from it using the `bub_fifo_Consume[Element]` function(s)
// and converting the resulting bytes using `deserializer`.
// Return a blue unix fifo descriptor
extern bub_fifo_desc_t bub_fifo_OpenForConsumption
  (char* pathname, size_t bytesize, deserializer_t deserializer);
// Open the unix fifo `pathname` as writable to allow production of elements
// of `bytesize` bytes to it using the `bub_fifo_Produce[Element]` function(s)
// and converting the incoming bytes using `serializer`.
// Return a blue unix fifo descriptor
extern bub_fifo_desc_t bub_fifo_OpenForProduction
  (char* pathname, size_t bytesize, serializer_t serializer);
// Open the unix fifo `pathname` as readable and writable to allow consumption
// and production of elements of `bytesize` bytes from and to it using the
// `bub_fifo_{Consume, Produce}[Element]` functions and converting the bytes
// appropriately using `deserializer` or `serializer`.
// NOTE: calls to `bub_fifo_Consume` and `bub_fifo_Produce` should not be
// interleaved without elements being fully consumed / produced.
// Return a blue unix fifo descriptor
extern bub_fifo_desc_t bub_fifo_OpenForConsumptionProduction
  ( char* pathname, size_t bytesize
  , deserializer_t deserializer, serializer_t serializer );
// Consume from the `desc` fifo up to `bytesize` bytes (where `bytesize` was
// specified when opening the fifo) and returns how many bytes were consumed in
// total since the first call for the currently consumed element. If fewer than
// `bytesize` bytes were consumed, subsequent calls will continue to accumulate
// more bytes. If `bytesize` bytes were consumed, they are converted as per
// `deserializer` (where `deserializer` was specified when opening the fifo),
// returned in `elemdest`, and the fifo state is reset for consumption of the
// next element.
extern ssize_t bub_fifo_Consume (bub_fifo_desc_t desc, void* elemdest);
// Consume an element from the `desc` fifo into the `elementdest` buffer and
// return a pointer to `elementdest`.
// NOTE: `elementdest` should be an already allocated buffer of `bytesize` bytes
// (where `bytesize` was specified when opening the fifo)
extern void* bub_fifo_ConsumeElement (bub_fifo_desc_t desc, void* elemdest);
// Produce in the `desc` fifo up to `bytesize` bytes (where `bytesize` was
// specified when opening the fifo) and returns how many bytes were produced in
// total since the first call for the currently produced element. Upon first
// production, the bytes in `elemsrc` are converted as per `serializer` (where
// `serializer` was specified when opening the fifo). If fewer than `bytesize`
// bytes were produced, subsequent calls will simply continue to produce the
// next bytes until `bytesize` bytes were produced. When all `bytesize` bytes
// have been produced, the fifo state is reset for production of the next
// element.
extern ssize_t bub_fifo_Produce (bub_fifo_desc_t desc, void* elemsrc);
// Produce the element in `elemsrc` into the `desc` fifo and return a pointer to
// `elementsrc`.
extern void* bub_fifo_ProduceElement (bub_fifo_desc_t desc, void* elemsrc);
// close a blue fifo descriptor
extern void bub_fifo_Close (bub_fifo_desc_t desc);

#ifdef __cplusplus
extern "C" {
#endif

// BDPI Bluespec SystemVerilog API
////////////////////////////////////////////////////////////////////////////////

// Create a unix fifo on the filesystem at `pathname` and for data of size
// `bytesize` bytes, and open it RW. Return a unix fifo descriptor pointer to
// be stored by the simulator for later operations.
// Note: opening RW lets the simulator process persist if client processes pop
// in and out of existance (by maintaining the fifo channel effectively open
// for the lifetime of the simulator)
extern bub_fifo_desc_t bub_fifo_BDPI_Create (char* pathname, size_t bytesize);
// Read into `retbuf` one element from the fifo described by `desc`, of the
// size specified in `desc`. `retbuf`'s bottom 32 bits contain 0 if the read
// needs to be attempted again, and the bytesize of the element on
// successfull read. If the read succeeded, the upper bits in retbuf contain
// the element that was read.
extern void bub_fifo_BDPI_Read (unsigned int* retbuf, bub_fifo_desc_t desc);
// Write the element in `d` into the fifo described by `desc`, where the
// element in `d` must be of the size specified in `desc`. Returns 1 upon
// success, and 0 if the write should be re-attempted.
extern unsigned char bub_fifo_BDPI_Write
  (bub_fifo_desc_t desc, unsigned int* d);

// DPI-C Verilog API
////////////////////////////////////////////////////////////////////////////////

typedef enum __attribute__((__packed__)) {
     LastByteRead = 0x00
,   ValidByteRead = 0x01
, InvalidByteRead = 0x02
} byte_read_status_t;

typedef struct {
  byte_read_status_t status;
  uint8_t byte;
} byte_read_t;

typedef enum __attribute__((__packed__)) {
  LastByteWritten = 0x00
,     ByteWritten = 0x01
,  ByteNotWritten = 0x02
} byte_write_status_t;

extern bub_fifo_desc_t bub_fifo_DPI_C_Create (char* pathname, size_t bytesize);
extern byte_read_t bub_fifo_DPI_C_ReadByte (bub_fifo_desc_t desc);
extern byte_write_status_t bub_fifo_DPI_C_WriteByte ( bub_fifo_desc_t desc
                                                    , const uint8_t data );
extern void bub_fifo_DPI_C_ResetCount (bub_fifo_desc_t desc);

#ifdef __cplusplus
}
#endif

#endif
