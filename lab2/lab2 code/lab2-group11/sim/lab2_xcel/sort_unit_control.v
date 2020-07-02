`include "vc/trace.v"

`include "vc/mem-msgs.v"
`include "vc/queues.v"
`include "proc/XcelMsg.v"
`include "vc/regs.v"
`include "vc/muxes.v"

module sort_unit_control
#(
    parameter c_sorting_length = 32'd4,
    parameter c_sorting_bits   = 20
)(
    input logic clk,
    input logic reset,

    input  logic [31:0] data_in,
    input  logic out_en,
    input  logic [31:0] reg_file_output [c_sorting_length-1:0],

    input  logic length_fit,
    input  logic length_shorter,
    input  logic [c_sorting_bits:0] size,

    input  logic clear_full,
    input  logic [c_sorting_bits:0] iteration,
    input  logic [c_sorting_bits:0] c_num_iteration,

    output logic [1:0]  mux_sel         [c_sorting_length-1:0],
    output logic full
);

    logic [31:0] count;
    logic [31:0] count_in;
    logic        priority_flag;
    logic [31:0] sorting_temp_rd;
    logic multiple_flag_unit;

    assign multiple_flag_unit = (size % c_sorting_length == 0);

    //genvar i;
    //genvar z;
    //genvar e;
    //genvar freezy_line;
    //genvar descent_line;

    parameter zero    = 2'd0;
    parameter freezy  = 2'd1;
    parameter descent = 2'd2;
    parameter insert  = 2'd3;

    always @ (posedge clk) begin
      count <= count_in;
    end

    always_comb begin

      if (reset || clear_full) begin
          for (int unsigned r = 0; r < c_sorting_length; r = r + 1) begin
            mux_sel[r] = zero;  // let mux choose 0 to initialize the reg_file
            count_in   = 0;
          end
      end

       else if (out_en && count < c_sorting_length) begin

           for (int unsigned i = 0; i < c_sorting_length; i = i + 1) begin
             if ( data_in > reg_file_output[i]) begin

                  for (int unsigned descent_line = 0; descent_line < i; descent_line++) begin
                    mux_sel[descent_line] = descent;
                  end

                  mux_sel[i] = insert;

                  for (int unsigned freezy_line = i + 1; freezy_line < c_sorting_length; freezy_line++) begin
                    mux_sel[freezy_line] = freezy;
                  end

              end

           end

        count_in = count + 1;
      end

      else begin //if not in the sorting state, let the mux to choose the original value
        for (int unsigned e = 0; e < c_sorting_length; e++) begin
          mux_sel[e] = freezy;
        end
      end
    end

    always_comb begin
      if( multiple_flag_unit )
        sorting_temp_rd = c_sorting_length;
      else begin
        if (iteration < c_num_iteration )
          sorting_temp_rd = c_sorting_length;
        else
          sorting_temp_rd = size - (iteration) * c_sorting_length;
      end
    end

    always_comb begin
      if (reset || clear_full) begin
        //count_in = 0;
        full = 0;
      end
      else if ( length_fit && count_in == sorting_temp_rd ) begin
        full = 1;
      end
      else if ( length_shorter && count_in == size) begin
        full = 1;
      end
      else begin
        full = 0; //in any other time, full should be 0
      end
    end

    /*
    if( size_in % c_sorting_length == 0 )
      sorting_temp = c_sorting_length;
    else begin
      if (iteration < c_num_iteration )
        sorting_temp = c_sorting_length;
      else
        sorting_temp = size_in - (iteration) * c_sorting_length;
    end */


endmodule
