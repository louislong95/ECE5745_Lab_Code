`include "vc/trace.v"

`include "vc/mem-msgs.v"
`include "vc/queues.v"
`include "proc/XcelMsg.v"
`include "vc/regs.v"
`include "vc/muxes.v"
`include "lab2_xcel/sort_unit_datapath.v"
`include "lab2_xcel/sort_unit_control.v"

module sort_unit_VRTL
#(
    parameter c_sorting_length = 32'd4,
    parameter c_sorting_bits   = 20
)(
    input logic clk,
    input logic reset,

    input logic [31:0] data_in,
    input logic out_en,

    input logic length_fit,
    input logic length_shorter,
    input logic [c_sorting_bits:0] size,

    input logic clear_full,
    input logic [c_sorting_bits:0] iteration,
    input logic [c_sorting_bits:0] c_num_iteration,
    input logic multiple_flag,
    input logic [c_sorting_bits:0] memreq_sent_wr,

    output logic full,
    //output logic [31:0] reg_file_output [c_sorting_length-1:0]
    output logic [31:0] reg_file_output
);

    logic [1:0] mux_sel [c_sorting_length-1:0];
    logic [31:0] reg_file [c_sorting_length-1:0];

    sort_unit_datapath#(c_sorting_length) sort_unit_datapath
    (
        .clk(clk),
        .reset(reset),

        .data_in(data_in),
        .mux_sel(mux_sel),

        .reg_file_output(reg_file)
    );

    sort_unit_control#(c_sorting_length, c_sorting_bits) sort_unit_control
    (
        .clk(clk),
        .reset(reset),

        .data_in(data_in),
        .out_en(out_en),
        .reg_file_output(reg_file),

        .length_fit(length_fit),
        .length_shorter(length_shorter),
        .size(size),

        .clear_full(clear_full),
        .iteration(iteration),
        .c_num_iteration(c_num_iteration),
        //.multiple_flag(multiple_flag),

        .mux_sel(mux_sel),
        .full(full)
    );

    /*genvar i;
    generate
      for (i = 0; i < c_sorting_length; i = i + 1) begin: out
        assign reg_file_output[i] = reg_file[i];
      end
    endgenerate */

    always_comb begin
      if ( length_fit ) begin              // if it has c_sorting_length in the array, start from the last reg to send back
          //memreq_msg.data = result[(c_sorting_length - 1) - memreq_sent_wr];
          //memreq_msg.data = result[memreq_sent_wr];
          /*if( multiple_flag )
            memreq_msg.data = result[memreq_sent_wr];
          else begin
              if (iteration < c_num_iteration)
                memreq_msg.data = result[memreq_sent_wr];
              else
                //memreq_msg.data = result[c_sorting_length - (size_in - iteration * c_sorting_length) + memreq_sent_wr];
                wr_result_id    = c_sorting_length - sort_left + memreq_sent_wr;
                memreq_msg.data = result[wr_result_id];
          end  */
          if (multiple_flag || (!multiple_flag && iteration != c_num_iteration)) begin
             reg_file_output = reg_file[memreq_sent_wr];
          end
          else begin
             //wr_result_id    = c_sorting_length - sort_left + memreq_sent_wr;
             reg_file_output = reg_file[c_sorting_length - (size - iteration * c_sorting_length) + memreq_sent_wr];
          end

      end
      else begin                           // if the number of data in sorting unit is less than c_sorting_length
          //memreq_msg.data = result[(size - 1) - memreq_sent_wr];  // start from the last effective reg
          reg_file_output = reg_file[c_sorting_length - size + memreq_sent_wr];
          //output_sel = c_sorting_length - size + memreq_sent_wr;
          //memreq_msg.data = result;
      end
    end

endmodule
