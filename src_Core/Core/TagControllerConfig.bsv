package TagControllerConfig;

import CacheUtils :: *;
import Fabric_Defs :: *;

// The TagController expresses its datapath and CPU cache-line widths in bytes.
typedef TDiv#(Wd_Data, 8) TagControllerBusBytes;
typedef CLineDataNumBytes TagControllerCpuLineBytes;

endpackage
