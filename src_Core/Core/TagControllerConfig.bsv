package TagControllerConfig;

import Memory_Config :: *;
import CacheUtils :: *;

// The TagController expresses its datapath and CPU cache-line widths in bytes.
typedef TDiv#(AccessWidth, 8) TagControllerBusBytes;
typedef CLineDataNumBytes CpuLineSize;

endpackage
