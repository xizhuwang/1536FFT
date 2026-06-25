`timescale 1 ns / 10 ps

module quantize_q8_symmetric #(
    parameter integer W_IN = 32,
    parameter integer Q_SHIFT = 14
)(
    input  wire signed [W_IN-1:0] din_re,
    input  wire signed [W_IN-1:0] din_im,
    output wire signed [7:0]      dout_re,
    output wire signed [7:0]      dout_im
);
    function signed [7:0] quant_one;
        input signed [W_IN-1:0] val;
        reg signed [W_IN-1:0] mag;
        reg signed [W_IN-1:0] q;
        begin
            if (val >= 0) begin
                q = (val + ({{(W_IN-1){1'b0}}, 1'b1} <<< (Q_SHIFT-1))) >>> Q_SHIFT;
            end else begin
                mag = -val;
                q = -((mag + ({{(W_IN-1){1'b0}}, 1'b1} <<< (Q_SHIFT-1))) >>> Q_SHIFT);
            end

            if (q > 127) begin
                quant_one = 8'sd127;
            end else if (q < -128) begin
                quant_one = -8'sd128;
            end else begin
                quant_one = q[7:0];
            end
        end
    endfunction

    assign dout_re = quant_one(din_re);
    assign dout_im = quant_one(din_im);
endmodule
