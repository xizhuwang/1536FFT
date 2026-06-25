`timescale 1 ns / 10 ps

module CHIP (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       valid_in,
    input  wire [2:0] din_re,
    input  wire [2:0] din_im,
    output wire       valid_out,
    output wire [7:0] dout_re,
    output wire [7:0] dout_im
);
    Top_PureDIT u_top (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_in),
        .din_re    (din_re),
        .din_im    (din_im),
        .valid_out (valid_out),
        .dout_re   (dout_re),
        .dout_im   (dout_im)
    );
endmodule
