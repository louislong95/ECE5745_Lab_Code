#=========================================================================
# Sort Unit RTL Model
#=========================================================================
# Sort array in memory containing positive integers.
# Accelerator register interface:
#
#  xr0 : go/done
#  xr1 : base address of array
#  xr2 : number of elements in array
#
# Accelerator protocol involves the following steps:
#  1. Write the base address of array via xr1
#  2. Write the number of elements in array via xr2
#  3. Tell accelerator to go by writing xr0
#  4. Wait for accelerator to finish by reading xr0, result will be 1
#

from pymtl3      import *

from pymtl3.stdlib.ifcs.xcel_ifcs import XcelMinionIfcRTL
from pymtl3.stdlib.ifcs.mem_ifcs  import MemMasterIfcRTL, mk_mem_msg, MemMsgType
from pymtl3.stdlib.rtl  import BypassQueueRTL, PipeQueueRTL, Reg

from proc.XcelMsg import *

class SortXcelPRTL( Component ):

  # Constructor

  def construct( s ):

    MemReqMsg, MemRespMsg = mk_mem_msg( 8,32,32 )
    MEM_TYPE_READ  = b4(MemMsgType.READ)
    MEM_TYPE_WRITE = b4(MemMsgType.WRITE)

    # Interface

    s.xcel = XcelMinionIfcRTL( XcelReqMsg, XcelRespMsg )

    s.mem  = MemMasterIfcRTL( *mk_mem_msg(8,32,32) )

    # ''' LAB TASK ''''''''''''''''''''''''''''''''''''''''''''''''''''''
    # Create RTL model for sorting xcel
    # '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

  # Line tracing

  def line_trace( s ):

    s.trace = ""

    # ''' LAB TASK ''''''''''''''''''''''''''''''''''''''''''''''''''''''
    # Define line trace here
    # '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

    return s.trace

