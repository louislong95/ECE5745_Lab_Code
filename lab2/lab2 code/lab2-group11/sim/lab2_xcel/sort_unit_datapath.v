`include "vc/trace.v"

`include "vc/mem-msgs.v"
`include "vc/queues.v"
`include "proc/XcelMsg.v"
`include "vc/regs.v"
`include "vc/muxes.v"

module sort_unit_datapath
#(
    parameter c_sorting_length = 32'd4
)(
    input  logic clk,
    input  logic reset,

    input  logic [31:0] data_in,
    input  logic [1:0]  mux_sel         [c_sorting_length-1:0],

    output logic [31:0] reg_file_output [c_sorting_length-1:0]
    //output logic [31:0] reg_file_output
);

    logic [31:0] reg_file     [c_sorting_length-1:0];
    logic [31:0] mux_out      [c_sorting_length-1:0];
    logic reg_en              [c_sorting_length-1:0];

    vc_Mux4#(32) last_mux
    (
      .in0(32'b0),
      .in1(reg_file[c_sorting_length-1]),
      .in2(),
      .in3(data_in),
      .sel(mux_sel[c_sorting_length-1]),
      .out(mux_out[c_sorting_length-1])
    );

    vc_EnReg#(32) last_reg
    (
      .clk(clk),
      .reset(reset),
      .en(reg_en[c_sorting_length-1]),
      .d(mux_out[c_sorting_length-1]),
      .q(reg_file[c_sorting_length-1])
    );

    assign reg_en[c_sorting_length-1]          = 1;
    assign reg_file_output[c_sorting_length-1] = reg_file[c_sorting_length-1];

    genvar i;
    generate

    for (i = c_sorting_length - 2; i > -1; i = i - 1) begin: sort_reg_files

      vc_Mux4#(32) p_mux
      (
        .in0(32'b0),
        .in1(reg_file[i]),
        .in2(reg_file[i+1]),
        .in3(data_in),
        .sel(mux_sel[i]),
        .out(mux_out[i])
      );

      vc_EnReg#(32) p_regs
      (
        .clk(clk),
        .reset(reset),
        .en(reg_en[i]),
        .d(mux_out[i]),
        .q(reg_file[i])
      );
      assign reg_en[i] = 1;
      assign reg_file_output[i] = reg_file[i];

     end
   endgenerate

endmodule
