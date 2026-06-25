`timescale 1 ns / 10 ps

module fft512_dit_sdf_core #(
    parameter integer W = 11
)(
    input  wire                clk,
    input  wire                rst_n,
    input  wire                valid_in,
    input  wire signed [W-1:0] din_re,
    input  wire signed [W-1:0] din_im,
    output wire                valid_out,
    output wire signed [W-1:0] dout_re,
    output wire signed [W-1:0] dout_im
);
    wire [9:0] v;
    wire signed [W-1:0] sr [0:9];
    wire signed [W-1:0] si [0:9];

    assign v[0]  = valid_in;
    assign sr[0] = din_re;
    assign si[0] = din_im;

    genvar gi;
    generate
        for (gi = 0; gi < 9; gi = gi + 1) begin : g_stage
            fft512_dit_sdf_stage #(
                .STAGE(gi),
                .W(W)
            ) u_stage (
                .clk       (clk),
                .rst_n     (rst_n),
                .valid_in  (v[gi]),
                .din_re    (sr[gi]),
                .din_im    (si[gi]),
                .valid_out (v[gi+1]),
                .dout_re   (sr[gi+1]),
                .dout_im   (si[gi+1])
            );
        end
    endgenerate

    assign valid_out = v[9];
    assign dout_re   = sr[9];
    assign dout_im   = si[9];
endmodule
