//=========================================================================
// Sorting Accelerator Implementation
//=========================================================================
// Sort array in memory containing positive integers.
// Accelerator register interface:
//
//  xr0 : go/done
//  xr1 : base address of array
//  xr2 : number of elements in array
//
// Accelerator protocol involves the following steps:
//  1. Write the base address of array via xr1
//  2. Write the number of elements in array via xr2
//  3. Tell accelerator to go by writing xr0
//  4. Wait for accelerator to finish by reading xr0, result will be 1
//

`ifndef LAB2_SORT_SORT_XCEL_V
`define LAB2_SORT_SORT_XCEL_V

`include "vc/trace.v"

`include "vc/mem-msgs.v"
`include "vc/queues.v"
`include "proc/XcelMsg.v"
//`include "lab2_xcel/sort_unit.v"
`include "lab2_xcel/sorting_unit_VRTL.v"

//=========================================================================
// Sorting Accelerator Implementation
//=========================================================================

module lab2_xcel_SortXcelVRTL
#(
	parameter c_sorting_length = 20'd128,
	parameter c_sorting_bits   = 20
	//parameter num_iteration    = size_in/c_sorting_length
)(
  input  logic         clk,
  input  logic         reset,

  // look at XcelMsg for bit definition
  output logic         xcelreq_rdy,
  input  logic         xcelreq_en,
  input  XcelReqMsg    xcelreq_msg,

  input  logic         xcelresp_rdy,
  output logic         xcelresp_en,
  output XcelRespMsg   xcelresp_msg,

  // look at MemMsg in stdlib.ifcs for bit definition
  input  logic         memreq_rdy,
  output logic         memreq_en,
  output mem_req_4B_t  memreq_msg,

  output logic         memresp_rdy,
  input  logic         memresp_en,
  input  mem_resp_4B_t memresp_msg
);

  // ''' LAB TASK ''''''''''''''''''''''''''''''''''''''''''''''''''''''''
  // Create RTL model for sorting xcel

  logic        reset_sort_unit;
  logic [c_sorting_bits:0] size, size_in;
  logic [31:0] base_src0,   base_src0_in;
  logic [c_sorting_bits:0] byte_offset, byte_offset_in;
  logic [c_sorting_bits:0] byte_offset_wr, byte_offset_wr_in;
  logic [c_sorting_bits:0] memreq_sent, memreq_sent_in;
  logic [c_sorting_bits:0] memreq_sent_wr, memreq_sent_wr_in;

  logic [c_sorting_bits:0] iteration, iteration_in;
  logic [c_sorting_bits:0] c_num_iteration;
  logic sorting_go;
  logic out_en;
  logic full;
  logic finish_write;
  logic length_fit, length_shorter;
  logic remove_wr_resp_flag;
  logic [31:0] tmp_val;
  logic clear_full;
  logic memresp_is_read;
  logic [c_sorting_bits:0] sorting_temp;
  logic [c_sorting_bits:0] wr_result_id;
  logic [c_sorting_bits:0] sort_left;
  logic multiple_flag;
  logic [31:0] result_single;

  assign multiple_flag   = (size_in % c_sorting_length == 0);
  assign sort_left       = size_in - iteration * c_sorting_length;

  logic        xcelreq_deq_en;
  logic        xcelreq_deq_rdy;
  XcelReqMsg   xcelreq_deq_ret;


  vc_Queue#(`VC_QUEUE_PIPE,$bits(xcelreq_msg),1) xcelreq_q
  (
    .clk     (clk),
    .reset   (reset),
    .num_free_entries(),
    .enq_en  (xcelreq_en),
    .enq_rdy (xcelreq_rdy),
    .enq_msg (xcelreq_msg),
    .deq_en  (xcelreq_deq_en),
    .deq_rdy (xcelreq_deq_rdy),
    .deq_ret (xcelreq_deq_ret)
  );

  // Memory ports and queues

  logic           memresp_deq_en;
  logic           memresp_deq_rdy;
  mem_resp_4B_t   memresp_deq_ret;

  vc_Queue#(`VC_QUEUE_PIPE,$bits(memresp_msg),1) memresp_q
  (
    .clk     (clk),
    .reset   (reset),
    .num_free_entries(),
    .enq_en  (memresp_en),
    .enq_rdy (memresp_rdy),
    .enq_msg (memresp_msg),
    .deq_en  (memresp_deq_en),
    .deq_rdy (memresp_deq_rdy),
    .deq_ret (memresp_deq_ret)
  );

  sort_unit_VRTL#(c_sorting_length, c_sorting_bits) sort_unit_VRTL  // connect out sorting unit
  (
    .clk(clk),
    .reset(reset_sort_unit),

    .data_in(tmp_val),
    .out_en(out_en),

    .length_fit(length_fit),
    .length_shorter(length_shorter),
    .size(size),

    .clear_full(clear_full),
    .iteration(iteration),
    .c_num_iteration(c_num_iteration),
    .multiple_flag(multiple_flag),
    .memreq_sent_wr(memreq_sent_wr),

    .full(full),
    .reg_file_output(result_single)

  );

  // Extra state registers




  //assign c_num_iteration = size_in/c_sorting_length;

  always_ff @(posedge clk) begin
    memreq_sent    <= memreq_sent_in;
    size           <= size_in;
    base_src0      <= base_src0_in;
    byte_offset    <= byte_offset_in;
    byte_offset_wr <= byte_offset_wr_in;
    memreq_sent_wr <= memreq_sent_wr_in;
    iteration      <= iteration_in;
  end

  //======================================================================
  // State Update
  //======================================================================

  typedef enum logic [$clog2(5)-1:0] {
    STATE_XCFG,
    STATE_M_RD, // read one number
    STATE_SORTING,
    STATE_M_WR,
    STATE_WAIT

  } state_t;

  state_t state_reg;

  logic go;

  always_ff @(posedge clk) begin

    if ( reset )
      state_reg <= STATE_XCFG;
    else begin
      state_reg <= state_reg;

      case ( state_reg )

        STATE_XCFG:
          if ( go && xcelresp_en && xcelresp_rdy )
            state_reg <= STATE_M_RD;
          else
            state_reg <= STATE_XCFG;

        STATE_M_RD:                              // read the numbers from memory
          if ( sorting_go && memresp_deq_rdy )   // if dequeue signal is ready and ready to sort, then go to sort state
            state_reg <= STATE_SORTING;
          else
            state_reg <= STATE_M_RD;

        STATE_SORTING:                           // sorting state
          if( !full )                            // if the sort unit is not full, go to the memory read state
            state_reg <= STATE_M_RD;
          else if( full )                        // if the sort unit is full, go to the memory write state
            state_reg <= STATE_M_WR;
          else                                   // otherwise, stay in sorting state
            state_reg <= STATE_SORTING;

        STATE_M_WR:                              // memory write state
        if ( memreq_rdy )                      // if memory is ready to receive request message, go to wait state to wait the response
            state_reg <= STATE_WAIT;
          else
            state_reg <= STATE_M_WR;

        STATE_WAIT:
          if ( memresp_deq_rdy )                 // dequeue signal must be ready
          // there are four cases in wait state:
            if ( length_fit && !finish_write )                                 // first, if the size_in is equal or larger than c_sorting_length
              state_reg <= STATE_M_WR;                                         // and not finish writing all back, go to write state
            else if ( length_fit && iteration < c_num_iteration && finish_write) begin // second, if the size_in is equal or greater than c_sorting_length
              state_reg <= STATE_M_RD;
            end                                                                // and all sorted numbers has been written to memory, and not finish iteration, go to MEM_RD state
            else if ( length_shorter && !finish_write) begin                         // third, if the size_in is less than the c_sorting_length
              state_reg <= STATE_M_WR;
            end                                                                // and not finish writing all back, go to write state.
            // this else is the same thing as:
            // else if ( length_fit && iteration == c_num_iteration && finish_write || length_shorter && iteration == c_num_iteration && finish_write )
            else begin                                                         // last, if this round of number is written to memory, and iteration is done
              state_reg <= STATE_XCFG;                                         // then, it means finished and go back to X stage.
            end

        default:
          state_reg <= STATE_XCFG;

      endcase
    end
  end

  //======================================================================
  // State Outputs
  //======================================================================

  // Temporary
  logic [31:0] base_addr;
  //logic clr_iteration;


  always_comb begin

    xcelreq_deq_en      = 0;
    xcelresp_en         = 0;
    memreq_en           = 0;
    memresp_deq_en      = 0;
    go                  = 0;
    sorting_go          = 0;
    finish_write        = 0;
    remove_wr_resp_flag = 0;
    reset_sort_unit     = 1;           // at the beginning, clean the sort unit
    clear_full          = 0;

    base_src0_in        = base_src0;
    size_in             = size;


    //--------------------------------------------------------------------
    // STATE: XCFG
    //--------------------------------------------------------------------
    // In this state we handle the accelerator configuration protocol,
    // where we write the base addresses, size, and then tell the
    // accelerator to start. We also handle responding when the
    // accelerator is done.

    if ( state_reg == STATE_XCFG ) begin

      out_en = 0;                                  // disable the sorting unit
      reset_sort_unit = 1;                         // clean the sorting unit
      if ( xcelreq_deq_rdy & xcelresp_rdy ) begin  // when queue prepare to send data to consumer, and core is ready to receive the data
        xcelreq_deq_en = 1;                        // de-queue signal assertion
        xcelresp_en    = 1;                        // assert the resp enable, send data back to core

        if ( xcelreq_deq_ret.type_ == `XcelReqMsg_TYPE_READ ) begin   // if it is read
          xcelresp_msg.type_ = `XcelRespMsg_TYPE_READ;
          xcelresp_msg.data  = 1;
        end
        else begin                                // if it is write
          if ( xcelreq_deq_ret.addr == 0 ) begin  // if it is write to xr0
            go             = 1;                   // start xcel
            byte_offset_in = 0;                   // reset the byte offset value in read state
            byte_offset_wr_in   = 0;              // reset the byte offset value in write state
            memreq_sent_in = 0;                   // reset the read request counter
            memreq_sent_wr_in   = 0;              // reset the write request counter
            iteration_in        = 0;              // reset the iteration
          end
          else if ( xcelreq_deq_ret.addr == 1 )   // write to xr1
            base_src0_in = xcelreq_deq_ret.data;  // src0 -> xr1

          else if ( xcelreq_deq_ret.addr == 2 ) begin   // write to xr2
            size_in = xcelreq_deq_ret.data;             // src1 -> xr2
            if ( size_in < c_sorting_length) begin      // if the sorting length is less than the size of xcel
                length_shorter  = 1;               // assert length_shorter signal to indicate the sort length is less than the capacity
                length_fit      = 0;               // dessert length_fit signal
                c_num_iteration = 0;
            end
            else if ( size_in == c_sorting_length) begin
              length_shorter  = 0;
              length_fit      = 1;
              c_num_iteration = 0;
            end
            else begin                            // if the sorting length is equal or greater than the size of xcel
              length_shorter  = 0;
              length_fit      = 1;               // assert length_fit signal
              if( multiple_flag) begin
                 c_num_iteration = size_in/c_sorting_length - 1;
              end
              else begin
                c_num_iteration = size_in/c_sorting_length;
              end
            end
          end

          xcelresp_msg.type_ = `XcelRespMsg_TYPE_WRITE;  // send the ack to the core
          xcelresp_msg.data  = 0;                 // send back 0, please see the test
        end
      end

      if ( !remove_wr_resp_flag ) begin           // we need to pop one message stored in memory queue in this state because in the test_multiple,
      	memresp_deq_en      = 1;                  // queue will store the writing ack message, so before next round, we need to pop it out
        remove_wr_resp_flag = 1;                  // we assert the dequeue enable signal and set the flag to 1
      end
      else begin                                  // if the flag is 1, it means that the write ack message has been poped out
        memresp_deq_en      = 0;                  // so in next cycle, turn off the dequeue enable signal
        remove_wr_resp_flag = 1;                  // still keep asserting the flag; this flag will be turned off in the wait state
      end

    end

    //--------------------------------------------------------------------
    // STATE: M_RD
    //--------------------------------------------------------------------

    else if ( state_reg == STATE_M_RD ) begin

      out_en = 0;                          // still disable the sorting unit
      reset_sort_unit = 0;                 // but do not reset the sorting unit

      if ( memreq_rdy )                    // if memory is ready to receive message
      begin

        base_addr = base_src0;             // read the base address from src0 field

        memreq_en = 1;                     // build the communication between memory
        memreq_msg.type_ = `VC_MEM_REQ_MSG_TYPE_READ;    // type is 'read'
        if (memreq_sent == 0) begin        // if it is the first message
          memreq_msg.addr = base_addr + iteration * 4 * c_sorting_length;
        end
        else begin                                       // if it is not the first message
          memreq_msg.addr = base_addr + iteration * 4 * c_sorting_length + byte_offset;
        end
        memreq_msg.len = 0;
        memreq_sent_in = memreq_sent + 1;          // counter ++
        byte_offset_in = byte_offset + 4;          // byte_offset = byte_offset + 4
      end
      else begin
        memreq_sent_in = memreq_sent;         // if read finishes,  stop the counter
        byte_offset_in = byte_offset;
      end

      // Memory responses
      if ( memresp_deq_rdy )
      begin
        memresp_deq_en = 1;
        tmp_val = memresp_deq_ret.data;       // pass the data in the response message to the sorting unit
        memresp_is_read = (memresp_deq_ret.type_ == `VC_MEM_RESP_MSG_TYPE_READ);
        if ( memresp_deq_en && memresp_deq_rdy && memresp_is_read) begin   // if data has been dequeued from the qeueue,
          sorting_go = 1'b1;                             // start the sorting state
        end
        else begin
          sorting_go = 0;
        end
      end
    end

    //--------------------------------------------------------------------
    // STATE: SORTING
    //--------------------------------------------------------------------

    else if ( state_reg == STATE_SORTING ) begin
        out_en = 1;                     // enable the sorting function in the sorting unit
        reset_sort_unit = 0;            // dessert the reset signal
      end

    //--------------------------------------------------------------------
    // STATE: M_WR
    //--------------------------------------------------------------------

    else if ( state_reg == STATE_M_WR ) begin
      out_en = 0;                       // disable the sorting unit
      reset_sort_unit = 0;              // do not clean the sorting unit

      if ( memreq_rdy ) begin           // if the memory is ready to receive the message
        memreq_en           = 1;
        memreq_msg.type_    = `VC_MEM_REQ_MSG_TYPE_WRITE;    // type is write
        memreq_msg.len      = 0;
        memreq_msg.data = result_single;

        if (memreq_sent_wr == 0) begin  // if it is first time to send, do not add the byte_offset
          memreq_msg.addr = base_addr + iteration * 4 * c_sorting_length;
        end
        else begin                      // if it is not the first time to send, add the byte_offset
          memreq_msg.addr   = base_addr + iteration * 4 * c_sorting_length + byte_offset_wr;
        end

        memreq_sent_wr_in = memreq_sent_wr + 1;    // counter++
        byte_offset_wr_in = byte_offset_wr + 4;

      end

      else begin
        memreq_sent_wr_in = memreq_sent_wr;
        byte_offset_wr_in = byte_offset_wr;
      end

    end

    //--------------------------------------------------------------------
    // STATE: WAIT
    //--------------------------------------------------------------------

    else if ( state_reg == STATE_WAIT ) begin
      out_en              = 0;    // disable the sorting unit
      reset_sort_unit     = 0;
      memreq_sent_in      = 0;    // clean memory response
      byte_offset_in      = 0;    // clean the byte_offset, just in case if next state is MEM_RD
      remove_wr_resp_flag = 0;    // clean the flag, just in case if next state is MEM_RD

      if ( memresp_deq_rdy ) begin
        memresp_deq_en = 1;
        if( multiple_flag ) begin
          sorting_temp = c_sorting_length;
        end
        else begin
          if (iteration < c_num_iteration ) begin
            sorting_temp = c_sorting_length;
          end
          else begin
            sorting_temp = size_in - (iteration) * c_sorting_length;
          end
        end
        if ( length_fit && memreq_sent_wr == sorting_temp ) begin  // if this round has the equal or greater size than c_sorting_length, and all data has been writen
          byte_offset_wr_in = 0;                     // clean the write byte_offset counter
          memreq_sent_wr_in = 0;                     // clean the write request message counter
          finish_write = 1;                          // assert finish_write signal for state transition
          iteration_in = iteration + 1;              // increment the iteration value
          clear_full   = 1;
        end
        else if ( length_shorter && memreq_sent_wr == size) begin   // if this round has less size than c_sorting_length and all data has been written
          byte_offset_wr_in = 0;
          memreq_sent_wr_in = 0;
          finish_write = 1;
          iteration_in = iteration + 1;
          clear_full   = 1;
        end
        else begin
          finish_write = 0;                          // if writing not finish, dessert the finish_write signal
        end
      end
    end
  end

  //======================================================================
  // Line Tracing
  //======================================================================

  `ifndef SYNTHESIS

  logic [`VC_TRACE_NBITS-1:0] str;
  `VC_TRACE_BEGIN
  begin
    $sformat( str, "xr%2x = %x", xcelreq_msg.addr, xcelreq_msg.data );
    vc_trace.append_en_rdy_str( trace_str, xcelreq_en, xcelreq_rdy, str );

    vc_trace.append_str( trace_str, "(" );

    case ( state_reg )
      //STATE_XCFG:      vc_trace.append_str( trace_str, "X " );
      //STATE_M_RD:      vc_trace.append_str( trace_str, "RD" );
      //STATE_ADD :      vc_trace.append_str( trace_str, "+ " );
      //STATE_M_WR:      vc_trace.append_str( trace_str, "WR" );
      //STATE_WAIT:      vc_trace.append_str( trace_str, "W " );
      default:         vc_trace.append_str( trace_str, "? " );
    endcase
    vc_trace.append_str( trace_str, " " );

    $sformat( str, "%x", base_src0 );
    vc_trace.append_str( trace_str, str );
    vc_trace.append_str( trace_str, " " );

    $sformat( str, "%x", size_in );
    vc_trace.append_str( trace_str, str );
    vc_trace.append_str( trace_str, " " );

    /*$sformat( str, "%x", num_src0 );
    vc_trace.append_str( trace_str, str );
    vc_trace.append_str( trace_str, " " ); */

    /*$sformat( str, "%x", memrsp_recv_wait[7:0] );
    vc_trace.append_str( trace_str, str );
    vc_trace.append_str( trace_str, " " );  */

    vc_trace.append_str( trace_str, ")" );

    $sformat( str, "%x", memreq_msg.data );
    vc_trace.append_en_rdy_str( trace_str, memreq_en, memreq_rdy, str );

    vc_trace.append_str( trace_str, "||" );

    $sformat( str, "%x", memreq_msg.data );
    vc_trace.append_en_rdy_str( trace_str, memreq_en, memreq_rdy, str );

    vc_trace.append_str( trace_str, "::" );

    $sformat( str, "%x", xcelresp_msg.data );
    vc_trace.append_en_rdy_str( trace_str, xcelresp_en, xcelresp_rdy, str );

  end
  `VC_TRACE_END

  `endif /* SYNTHESIS */

endmodule

`endif /* LAB2_XCEL_SORT_XCEL_V */
