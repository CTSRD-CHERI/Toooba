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

#include "BlueUnixFifo.h"

#include <fcntl.h>
#include <libgen.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <dirent.h>

// local helpers
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

// A BlueUnixFifo structure
typedef struct {
  char* pathname;
  int fd;
  mode_t mode;
  int flags;
  size_t element_byte_size;
  uint8_t* buf;
  ssize_t byte_count;
  deserializer_t deserializer;
  serializer_t serializer;
} bub_fifo_fields_t;

// create path
//////////////
static int create_dir_path (const char* path, mode_t mode) {
  int res = -1; // initialise return status to error
  DIR* dir = opendir (path);
  int errsv = errno;
  if (dir) { // check if the dir path is already existing, and end recursion
    closedir (dir);
    res = 0; // no error encountered, success
  } else if (ENOENT == errsv) { // otherwise, create it and its parent
    // copy path for string manipulation
    size_t len = strlen (path) + 1;
    char* parentpath = (char*) malloc (len * sizeof (char));
    strcpy (parentpath, path);
    parentpath = dirname (parentpath);
    // try to create the parent hierarchy
    res = create_dir_path (parentpath, mode | 0111);
    // if it succeeded, try to create the directory itself
    if (res == 0) res = mkdir (path, mode | 0111);
  }
  // return error status
  return res;
}

// create a blue unix fifo descriptor
/////////////////////////////////////
static bub_fifo_fields_t* create_fifo_desc ( char* pathname
                                           , mode_t mode
                                           , int flags
                                           , size_t element_byte_size
                                           , deserializer_t deserializer
                                           , serializer_t serializer ) {
  bub_fifo_fields_t* desc =
    (bub_fifo_fields_t*) malloc (sizeof (bub_fifo_fields_t));
  // copy pathname
  size_t n = strlen (pathname);
  desc->pathname = (char*) malloc (n + 1);
  memcpy (desc->pathname, pathname, n + 1);
  // file descriptor, initially set to -1
  desc->fd = -1;
  // the desired mode for file creation (unix permissions rwx.rwx.rwx)
  desc->mode = mode;
  // flags to open the fifo with (O_RDONLY, O_WRONLY, O_RDWR, O_NONBLOCK...)
  desc->flags = flags;
  // the size of the element being exchanged in bytes (for types with bitwidth
  // non multiple of 8, this size should be rounded up)
  desc->element_byte_size = element_byte_size;
  // element buffer
  desc->buf = (uint8_t*) malloc (element_byte_size);
  // running byte count to account for currently read/written bytes, initially
  // set to 0
  desc->byte_count = 0;
  // a deserializer callback, called by blueUnixFifo_Consume to transform the
  // byte array being received into a rich typed value
  desc->deserializer = deserializer;
  // a serializer callback, called by blueUnixFifo_Produce to transform the
  // rich typed value being sent into a byte array
  desc->serializer = serializer;
  // return the initialized blue unix fifo descriptor
  return desc;
}

// destroy a blue unix fifo descriptor (free dynamically allocated memory)
//////////////////////////////////////////////////////////////////////////
static void destroy_fifo_desc (bub_fifo_fields_t* desc) {
  free (desc->pathname);
  free (desc->buf);
  free (desc);
}

// print a blue unix fifo descriptor (debug)
////////////////////////////////////////////
static void print_fifo_desc (bub_fifo_fields_t* desc) {
  printf ( "bub_fifo_fields_t @ %p:\n"
           ".pathname: %s\n"
           ".fd: %d\n"
           ".mode: 0%o\n"
           ".flags: 0x%0x\n"
           ".element_byte_size: %lu\n"
           ".buf: %p\n"
           ".byte_count: %ld\n"
           ".deserializer@: %p\n"
           ".serializer@: %p\n"
         , desc
         , desc->pathname
         , desc->fd
         , desc->mode
         , desc->flags
         , desc->element_byte_size
         , desc->buf
         , desc->byte_count
         , desc->deserializer
         , desc->serializer );
}

// open file descriptor associated with a blue unix fifo descriptor
///////////////////////////////////////////////////////////////////
static void open_fifo (bub_fifo_fields_t* desc) {
  int fd = open (desc->pathname, desc->flags);
  if (fd == -1) {
    int errsv = errno;
    switch (errsv) {
      case ENXIO: break;
      default:
        print_fifo_desc (desc);
        printf ( "%s:l%d: %s: %s (errno: %d)\n"
               , __FILE__, __LINE__, __func__, strerror (errsv), errsv);
        exit (EXIT_FAILURE);
    }
  }
  desc->fd = fd;
}

// create a fifo on the filesystem for other processes to open
//////////////////////////////////////////////////////////////
static void create_fifo (bub_fifo_fields_t* desc) {
  // create the parent dir hierarchy (copy path for string manipulation)
  size_t len = strlen (desc->pathname) + 1;
  char* pathcpy = (char*) malloc (len * sizeof (char));
  strcpy (pathcpy, desc->pathname);
  create_dir_path (dirname (pathcpy), desc->mode);
  // create the unix fifo
  if (mkfifo (desc->pathname, desc->mode) == -1) {
    int errsv = errno;
    switch (errsv) {
      case EEXIST: break;
      default:
        print_fifo_desc (desc);
        printf ( "%s:l%d: %s: %s (errno: %d)\n"
               , __FILE__, __LINE__, __func__, strerror (errsv), errsv);
        exit (EXIT_FAILURE);
    }
  }
  // open the unix fifo
  open_fifo (desc);
  // set the fifo size
  //fcntl (desc->fd, F_SETPIPE_SZ, DFLT_PIPE_SZ);
}

// close an opened blue unix fifo file descriptor
/////////////////////////////////////////////////
static void close_fifo (bub_fifo_fields_t* desc) {
  if (close (desc->fd) == -1) {
    int errsv = errno;
    switch (errsv) {
      default:
        print_fifo_desc (desc);
        printf ( "%s:l%d: %s: %s (errno: %d)\n"
               , __FILE__, __LINE__, __func__, strerror (errsv), errsv);
        exit (EXIT_FAILURE);
    }
  }
}

// unlink the backing file for a blue unix fifo descriptor
//////////////////////////////////////////////////////////
static void unlink_fifo (bub_fifo_fields_t* desc) {
  if (unlink (desc->pathname) == -1) {
    int errsv = errno;
    switch (errsv) {
      default:
        print_fifo_desc (desc);
        printf ( "%s:l%d: %s: %s (errno: %d)\n"
               , __FILE__, __LINE__, __func__, strerror (errsv), errsv);
        exit (EXIT_FAILURE);
    }
  }
}

// desctroy the blue unix fifo described by `desc`
//////////////////////////////////////////////////
static void destroy_fifo (bub_fifo_fields_t* desc) {
  close_fifo (desc);
  unlink_fifo (desc);
  destroy_fifo_desc (desc);
}

// read bytes from the fifo and aggregate them in the descriptor buffer
///////////////////////////////////////////////////////////////////////
static void read_fifo (bub_fifo_fields_t* desc) {
  // check for presence of producer
  if (desc->fd == -1) open_fifo (desc);
  if (desc->fd == -1) return; // immediate return if no producer is present
  // read for appropriate amount of bytes and accumulate in buf
  size_t remaining = desc->element_byte_size - desc->byte_count;
  ssize_t res = read (desc->fd, desc->buf + desc->byte_count, remaining);
  // handle possible errors
  if (res == -1) {
    int errsv = errno;
    switch (errsv) {
      case EAGAIN: return;
      default:
        print_fifo_desc (desc);
        printf ( "%s:l%d: %s: %s (errno: %d)\n"
               , __FILE__, __LINE__, __func__, strerror (errsv), errsv);
        exit (EXIT_FAILURE);
    }
  }
  // on read success, accumulate bytes read
  desc->byte_count += res;
}

// write bytes into the fifo and keep track of how many in the descriptor
/////////////////////////////////////////////////////////////////////////
static void write_fifo (bub_fifo_fields_t* desc, const uint8_t* data) {
  // check for presence of consumer
  if (desc->fd == -1) open_fifo (desc);
  if (desc->fd == -1) return;
  // write remaining bytes to write
  size_t remaining = desc->element_byte_size - desc->byte_count;
  int res = write (desc->fd, data + desc->byte_count, remaining);
  // handle possible errors
  if (res == -1) {
    int errsv = errno;
    switch (errsv) {
      case EBADF:
      case EPIPE:
      case EAGAIN:
        return;
      default:
        print_fifo_desc (desc);
        printf ( "%s:l%d: %s: %s (errno: %d)\n"
               , __FILE__, __LINE__, __func__, strerror (errsv), errsv);
        exit (EXIT_FAILURE);
    }
  }
  // on write success, accumulate bytes written
  desc->byte_count += res;
}

// wrap relevant functions for Bluespec SystemVerilog BDPI API
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

bub_fifo_desc_t bub_fifo_BDPI_Create (char* pathname, size_t bytesize) {
  // initialise a fifo descriptor
  bub_fifo_fields_t* desc = create_fifo_desc ( pathname
                                             , 0666
                                             , O_RDWR | O_NONBLOCK
                                             , bytesize
                                             , NULL
                                             , NULL );
  // create the fifo
  create_fifo (desc);
  // return the fifo descriptor
  return (bub_fifo_desc_t) desc;
}

void bub_fifo_BDPI_Read (unsigned int* retbufptr, bub_fifo_desc_t desc) {
  bub_fifo_fields_t* fields = (bub_fifo_fields_t*) desc;
  read_fifo (fields);
  // byte handle on the return buffer
  uint8_t* retbuf = (uint8_t*) retbufptr;
  // return no bytes read by default
  memset (retbuf, 0, 4);
  // if full data has been read, copy internal buf into retbuf with read size,
  // and reset byte count
  if (fields->byte_count == fields->element_byte_size) {
    fields->byte_count = 0;
    (*retbuf) = (uint32_t) fields->element_byte_size;
    memcpy (retbuf + 4, fields->buf, fields->element_byte_size);
  }
}

unsigned char bub_fifo_BDPI_Write (bub_fifo_desc_t desc, unsigned int* data) {
  bub_fifo_fields_t* fields = (bub_fifo_fields_t*) desc;
  write_fifo (fields, (const uint8_t*) data);
  // if full data has been written, reset byte count and return success
  if (fields->byte_count == fields->element_byte_size) {
    fields->byte_count = 0;
    return 1;
  }
  return 0;
}

// wrap relevant functions for the rest of the API
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

bub_fifo_desc_t bub_fifo_OpenForProduction ( char* pathname
                                           , size_t bytesize
                                           , serializer_t serializer ) {
  // initialise a fifo descriptor
  bub_fifo_fields_t* desc = create_fifo_desc ( pathname
                                            , 0000
                                            , O_WRONLY | O_NONBLOCK
                                            , bytesize
                                            , NULL
                                            , serializer );
  // open the unix fifo
  open_fifo (desc);
  // return the descriptor
  return (bub_fifo_desc_t) desc;
}

bub_fifo_desc_t bub_fifo_OpenForConsumption ( char* pathname
                                            , size_t bytesize
                                            , deserializer_t deserializer ) {
  // initialise a fifo descriptor
  bub_fifo_fields_t* desc = create_fifo_desc ( pathname
                                             , 0000
                                             , O_RDONLY | O_NONBLOCK
                                             , bytesize
                                             , deserializer
                                             , NULL );
  // open the unix fifo
  open_fifo (desc);
  // return the descriptor
  return (bub_fifo_desc_t) desc;
}

bub_fifo_desc_t bub_fifo_OpenForConsumptionProduction
  ( char* pathname, size_t bytesize
  , deserializer_t deserializer, serializer_t serializer ) {
  // initialise a fifo descriptor
  bub_fifo_fields_t* desc = create_fifo_desc ( pathname
                                             , 0000
                                             , O_RDWR | O_NONBLOCK
                                             , bytesize
                                             , deserializer
                                             , serializer );
  // open the unix fifo
  open_fifo (desc);
  // return the descriptor
  return (bub_fifo_desc_t) desc;
}

ssize_t bub_fifo_Consume (bub_fifo_desc_t desc, void* elemdest) {
  bub_fifo_fields_t* fields = (bub_fifo_fields_t*) desc;
  read_fifo (fields);
  if (fields->byte_count == fields->element_byte_size) {
    fields->byte_count = 0;
    fields->deserializer (elemdest, fields->buf);
    return fields->element_byte_size;
  }
  return fields->byte_count;
}

void* bub_fifo_ConsumeElement (bub_fifo_desc_t desc, void* elemdest) {
  bub_fifo_fields_t* fields = (bub_fifo_fields_t*) desc;
  while (bub_fifo_Consume (desc, elemdest) != fields->element_byte_size);
  return elemdest;
}

ssize_t bub_fifo_Produce (bub_fifo_desc_t desc, void* elemsrc) {
  bub_fifo_fields_t* fields = (bub_fifo_fields_t*) desc;
  // encode on first attempt
  if (fields->byte_count == 0) fields->serializer (fields->buf, elemsrc);
  write_fifo (fields, fields->buf);
  // if full data has been written, reset byte count and return success
  if (fields->byte_count == fields->element_byte_size) {
    fields->byte_count = 0;
    return fields->element_byte_size;
  }
  return fields->byte_count;
}

void* bub_fifo_ProduceElement (bub_fifo_desc_t desc, void* elemsrc) {
  bub_fifo_fields_t* fields = (bub_fifo_fields_t*) desc;
  while (bub_fifo_Produce (desc, elemsrc) != fields->element_byte_size);
  return elemsrc;
}

void bub_fifo_Close (bub_fifo_desc_t desc) {
  close_fifo ((bub_fifo_fields_t*) desc);
}
