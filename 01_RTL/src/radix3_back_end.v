`timescale 1 ns / 10 ps

module radix3_back_end #(
    parameter integer W = 11,
    parameter integer Q_SHIFT = 4
)(
    input  wire                clk,
    input  wire                rst_n,
    input  wire                valid_in,
    input  wire [8:0]          k_in,
    input  wire signed [W-1:0] b0_re,
    input  wire signed [W-1:0] b0_im,
    input  wire signed [W-1:0] b1_re,
    input  wire signed [W-1:0] b1_im,
    input  wire signed [W-1:0] b2_re,
    input  wire signed [W-1:0] b2_im,
    output reg                 valid_out,
    output reg  [8:0]          k_out,
    output reg  signed [7:0]   x0_re,
    output reg  signed [7:0]   x0_im,
    output reg  signed [7:0]   x1_re,
    output reg  signed [7:0]   x1_im,
    output reg  signed [7:0]   x2_re,
    output reg  signed [7:0]   x2_im
);
    localparam signed [15:0] W3_RE  = -16'sd8192;
    localparam signed [15:0] W3_IM  = -16'sd14189;
    localparam signed [15:0] W32_RE = -16'sd8192;
    localparam signed [15:0] W32_IM = 16'sd14189;

    wire [10:0] t1_addr = {2'b00, k_in};
    wire [10:0] t2_addr = ({1'b0, k_in, 1'b0} >= 11'd1536) ?
                          ({1'b0, k_in, 1'b0} - 11'd1536) :
                          {1'b0, k_in, 1'b0};

    wire signed [15:0] t1_re;
    wire signed [15:0] t1_im;
    wire signed [15:0] t2_re;
    wire signed [15:0] t2_im;

    twiddle1536_q14_rom u_tw1 (.addr(t1_addr), .tw_re(t1_re), .tw_im(t1_im));
    twiddle1536_q14_rom u_tw2 (.addr(t2_addr), .tw_re(t2_re), .tw_im(t2_im));

    reg                 v0;
    reg [8:0]           k0;
    reg signed [W-1:0]  b0_re_0;
    reg signed [W-1:0]  b0_im_0;
    reg signed [W-1:0]  b1_re_r;
    reg signed [W-1:0]  b1_im_r;
    reg signed [W-1:0]  b2_re_r;
    reg signed [W-1:0]  b2_im_r;
    reg signed [15:0]   t1_re_r;
    reg signed [15:0]   t1_im_r;
    reg signed [15:0]   t2_re_r;
    reg signed [15:0]   t2_im_r;

    wire signed [W-1:0] u1_re_w;
    wire signed [W-1:0] u1_im_w;
    wire signed [W-1:0] u2_re_w;
    wire signed [W-1:0] u2_im_w;

    complex_mul_q14 #(.W(W)) u_mul_t1 (
        .a_re(b1_re_r), .a_im(b1_im_r), .w_re(t1_re_r), .w_im(t1_im_r),
        .y_re(u1_re_w), .y_im(u1_im_w)
    );
    complex_mul_q14 #(.W(W)) u_mul_t2 (
        .a_re(b2_re_r), .a_im(b2_im_r), .w_re(t2_re_r), .w_im(t2_im_r),
        .y_re(u2_re_w), .y_im(u2_im_w)
    );

    reg                 v1;
    reg [8:0]           k1;
    reg signed [W-1:0]  b0_re_r;
    reg signed [W-1:0]  b0_im_r;
    reg signed [W-1:0]  u1_re;
    reg signed [W-1:0]  u1_im;
    reg signed [W-1:0]  u2_re;
    reg signed [W-1:0]  u2_im;

    wire signed [W-1:0] w3u1_re;
    wire signed [W-1:0] w3u1_im;
    wire signed [W-1:0] w32u1_re;
    wire signed [W-1:0] w32u1_im;
    wire signed [W-1:0] w3u2_re;
    wire signed [W-1:0] w3u2_im;
    wire signed [W-1:0] w32u2_re;
    wire signed [W-1:0] w32u2_im;

    complex_mul_q14 #(.W(W)) u_w3_u1  (.a_re(u1_re), .a_im(u1_im), .w_re(W3_RE),  .w_im(W3_IM),  .y_re(w3u1_re),  .y_im(w3u1_im));
    complex_mul_q14 #(.W(W)) u_w32_u1 (.a_re(u1_re), .a_im(u1_im), .w_re(W32_RE), .w_im(W32_IM), .y_re(w32u1_re), .y_im(w32u1_im));
    complex_mul_q14 #(.W(W)) u_w3_u2  (.a_re(u2_re), .a_im(u2_im), .w_re(W3_RE),  .w_im(W3_IM),  .y_re(w3u2_re),  .y_im(w3u2_im));
    complex_mul_q14 #(.W(W)) u_w32_u2 (.a_re(u2_re), .a_im(u2_im), .w_re(W32_RE), .w_im(W32_IM), .y_re(w32u2_re), .y_im(w32u2_im));

    wire signed [W+1:0] x0_sum_re_w = $signed(b0_re_r) + $signed(u1_re)    + $signed(u2_re);
    wire signed [W+1:0] x0_sum_im_w = $signed(b0_im_r) + $signed(u1_im)    + $signed(u2_im);
    wire signed [W+1:0] x1_sum_re_w = $signed(b0_re_r) + $signed(w3u1_re)  + $signed(w32u2_re);
    wire signed [W+1:0] x1_sum_im_w = $signed(b0_im_r) + $signed(w3u1_im)  + $signed(w32u2_im);
    wire signed [W+1:0] x2_sum_re_w = $signed(b0_re_r) + $signed(w32u1_re) + $signed(w3u2_re);
    wire signed [W+1:0] x2_sum_im_w = $signed(b0_im_r) + $signed(w32u1_im) + $signed(w3u2_im);

    reg                 v2;
    reg [8:0]           k2;
    reg signed [W+1:0]  x0_sum_re;
    reg signed [W+1:0]  x0_sum_im;
    reg signed [W+1:0]  x1_sum_re;
    reg signed [W+1:0]  x1_sum_im;
    reg signed [W+1:0]  x2_sum_re;
    reg signed [W+1:0]  x2_sum_im;

    wire signed [7:0] x0q_re;
    wire signed [7:0] x0q_im;
    wire signed [7:0] x1q_re;
    wire signed [7:0] x1q_im;
    wire signed [7:0] x2q_re;
    wire signed [7:0] x2q_im;

    quantize_q8_symmetric #(.W_IN(W+2), .Q_SHIFT(Q_SHIFT)) u_q0 (
        .din_re(x0_sum_re), .din_im(x0_sum_im), .dout_re(x0q_re), .dout_im(x0q_im)
    );
    quantize_q8_symmetric #(.W_IN(W+2), .Q_SHIFT(Q_SHIFT)) u_q1 (
        .din_re(x1_sum_re), .din_im(x1_sum_im), .dout_re(x1q_re), .dout_im(x1q_im)
    );
    quantize_q8_symmetric #(.W_IN(W+2), .Q_SHIFT(Q_SHIFT)) u_q2 (
        .din_re(x2_sum_re), .din_im(x2_sum_im), .dout_re(x2q_re), .dout_im(x2q_im)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v0        <= 1'b0;
            k0        <= 9'd0;
            b0_re_0   <= {W{1'b0}};
            b0_im_0   <= {W{1'b0}};
            b1_re_r   <= {W{1'b0}};
            b1_im_r   <= {W{1'b0}};
            b2_re_r   <= {W{1'b0}};
            b2_im_r   <= {W{1'b0}};
            t1_re_r   <= 16'sd0;
            t1_im_r   <= 16'sd0;
            t2_re_r   <= 16'sd0;
            t2_im_r   <= 16'sd0;
            v1        <= 1'b0;
            k1        <= 9'd0;
            b0_re_r   <= {W{1'b0}};
            b0_im_r   <= {W{1'b0}};
            u1_re     <= {W{1'b0}};
            u1_im     <= {W{1'b0}};
            u2_re     <= {W{1'b0}};
            u2_im     <= {W{1'b0}};
            v2        <= 1'b0;
            k2        <= 9'd0;
            x0_sum_re <= {(W+2){1'b0}};
            x0_sum_im <= {(W+2){1'b0}};
            x1_sum_re <= {(W+2){1'b0}};
            x1_sum_im <= {(W+2){1'b0}};
            x2_sum_re <= {(W+2){1'b0}};
            x2_sum_im <= {(W+2){1'b0}};
            valid_out <= 1'b0;
            k_out     <= 9'd0;
            x0_re     <= 8'sd0;
            x0_im     <= 8'sd0;
            x1_re     <= 8'sd0;
            x1_im     <= 8'sd0;
            x2_re     <= 8'sd0;
            x2_im     <= 8'sd0;
        end else begin
            v0        <= valid_in;
            v1        <= v0;
            v2        <= v1;
            valid_out <= v2;

            if (valid_in) begin
                k0      <= k_in;
                b0_re_0 <= b0_re;
                b0_im_0 <= b0_im;
                b1_re_r <= b1_re;
                b1_im_r <= b1_im;
                b2_re_r <= b2_re;
                b2_im_r <= b2_im;
                t1_re_r <= t1_re;
                t1_im_r <= t1_im;
                t2_re_r <= t2_re;
                t2_im_r <= t2_im;
            end

            if (v0) begin
                k1      <= k0;
                b0_re_r <= b0_re_0;
                b0_im_r <= b0_im_0;
                u1_re   <= u1_re_w;
                u1_im   <= u1_im_w;
                u2_re   <= u2_re_w;
                u2_im   <= u2_im_w;
            end

            if (v1) begin
                k2        <= k1;
                x0_sum_re <= x0_sum_re_w;
                x0_sum_im <= x0_sum_im_w;
                x1_sum_re <= x1_sum_re_w;
                x1_sum_im <= x1_sum_im_w;
                x2_sum_re <= x2_sum_re_w;
                x2_sum_im <= x2_sum_im_w;
            end

            if (v2) begin
                k_out <= k2;
                x0_re <= x0q_re;
                x0_im <= x0q_im;
                x1_re <= x1q_re;
                x1_im <= x1q_im;
                x2_re <= x2q_re;
                x2_im <= x2q_im;
            end
        end
    end
endmodule
