`timescale 1 ns / 10 ps

module complex_mul_q14 #(
    parameter integer W = 11
)(
    input  wire signed [W-1:0]  a_re,
    input  wire signed [W-1:0]  a_im,
    input  wire signed [15:0]   w_re,
    input  wire signed [15:0]   w_im,
    output wire signed [W-1:0]  y_re,
    output wire signed [W-1:0]  y_im
);
    localparam integer P_W = W + 16;
    localparam integer S_W = W + 18;
    localparam signed [S_W-1:0] ROUND = {{(S_W-14){1'b0}}, 14'd8192};

    wire signed [P_W-1:0] ar_wr = $signed(a_re) * $signed(w_re);
    wire signed [P_W-1:0] ai_wi = $signed(a_im) * $signed(w_im);
    wire signed [P_W-1:0] ar_wi = $signed(a_re) * $signed(w_im);
    wire signed [P_W-1:0] ai_wr = $signed(a_im) * $signed(w_re);

    wire signed [S_W-1:0] ar_wr_ext = {{(S_W-P_W){ar_wr[P_W-1]}}, ar_wr};
    wire signed [S_W-1:0] ai_wi_ext = {{(S_W-P_W){ai_wi[P_W-1]}}, ai_wi};
    wire signed [S_W-1:0] ar_wi_ext = {{(S_W-P_W){ar_wi[P_W-1]}}, ar_wi};
    wire signed [S_W-1:0] ai_wr_ext = {{(S_W-P_W){ai_wr[P_W-1]}}, ai_wr};

    wire signed [S_W-1:0] p_re = ar_wr_ext - ai_wi_ext;
    wire signed [S_W-1:0] p_im = ar_wi_ext + ai_wr_ext;

    function signed [S_W-1:0] round_shift14;
        input signed [S_W-1:0] val;
        reg signed [S_W-1:0] mag;
        begin
            if (val >= 0) begin
                round_shift14 = (val + ROUND) >>> 14;
            end else begin
                mag = -val;
                round_shift14 = -((mag + ROUND) >>> 14);
            end
        end
    endfunction

    wire signed [S_W-1:0] shr_re = round_shift14(p_re);
    wire signed [S_W-1:0] shr_im = round_shift14(p_im);

    assign y_re = shr_re[W-1:0];
    assign y_im = shr_im[W-1:0];
endmodule
