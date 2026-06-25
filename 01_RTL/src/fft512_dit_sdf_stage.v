`timescale 1 ns / 10 ps

module fft512_dit_sdf_stage #(
    parameter integer STAGE = 0,
    parameter integer W     = 11
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    valid_in,
    input  wire signed [W-1:0]     din_re,
    input  wire signed [W-1:0]     din_im,
    output reg                     valid_out,
    output reg  signed [W-1:0]     dout_re,
    output reg  signed [W-1:0]     dout_im
);
    localparam integer L      = (1 << STAGE);
    localparam integer ADDR_W = (STAGE == 0) ? 1 : STAGE;
    localparam [ADDR_W:0] L_CONST = L[ADDR_W:0];
    localparam integer TW_PREFETCH = (STAGE >= 7);

    wire signed [15:0] tw_re;
    wire signed [15:0] tw_im;
    reg  signed [15:0] tw_re_r;
    reg  signed [15:0] tw_im_r;
    wire signed [W-1:0] twd_re;
    wire signed [W-1:0] twd_im;

    reg [STAGE:0]  cnt;
    reg [ADDR_W:0] fill_cnt;

    wire phase_second = cnt[STAGE];
    wire [ADDR_W-1:0] addr = (STAGE == 0) ? {ADDR_W{1'b0}} : cnt[ADDR_W-1:0];
    wire [STAGE:0] cnt_next = cnt + {{STAGE{1'b0}}, 1'b1};
    wire [ADDR_W-1:0] addr_next = (STAGE == 0) ? {ADDR_W{1'b0}} : cnt_next[ADDR_W-1:0];
    wire [8:0] tw_addr = {{(9-ADDR_W){1'b0}}, addr} << (8 - STAGE);
    wire [8:0] tw_addr_next = {{(9-ADDR_W){1'b0}}, addr_next} << (8 - STAGE);
    wire [8:0] tw_addr_lookup = (TW_PREFETCH && valid_in) ? tw_addr_next : tw_addr;
    wire filled = (fill_cnt >= L_CONST);

    twiddle512_q14_rom u_tw (
        .addr (tw_addr_lookup),
        .tw_re(tw_re),
        .tw_im(tw_im)
    );

    complex_mul_q14 #(.W(W)) u_mul (
        .a_re(din_re),
        .a_im(din_im),
        .w_re(TW_PREFETCH ? tw_re_r : tw_re),
        .w_im(TW_PREFETCH ? tw_im_r : tw_im),
        .y_re(twd_re),
        .y_im(twd_im)
    );

    generate
        if (STAGE < 7) begin : g_reg_delay
            // Small DIT-SDF delays are kept as registers.
            // These stages are shallow and do not justify a 512x45 hard macro.
            reg signed [W-1:0] delay_re [0:L-1];
            reg signed [W-1:0] delay_im [0:L-1];

            wire signed [W-1:0] old_re = delay_re[addr];
            wire signed [W-1:0] old_im = delay_im[addr];

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    tw_re_r   <= 16'sd16384;
                    tw_im_r   <= 16'sd0;
                    cnt       <= {(STAGE+1){1'b0}};
                    fill_cnt  <= {(ADDR_W+1){1'b0}};
                    valid_out <= 1'b0;
                    dout_re   <= {W{1'b0}};
                    dout_im   <= {W{1'b0}};
                end else begin
                    valid_out <= 1'b0;

                    if (valid_in) begin
                        valid_out <= filled;
                        cnt <= cnt + {{STAGE{1'b0}}, 1'b1};
                        if (!filled) begin
                            fill_cnt <= fill_cnt + {{ADDR_W{1'b0}}, 1'b1};
                        end

                        if (!phase_second) begin
                            dout_re <= old_re;
                            dout_im <= old_im;
                            delay_re[addr] <= din_re;
                            delay_im[addr] <= din_im;
                        end else begin
                            dout_re <= old_re + twd_re;
                            dout_im <= old_im + twd_im;
                            delay_re[addr] <= old_re - twd_re;
                            delay_im[addr] <= old_im - twd_im;
                        end
                    end
                end
            end
        end else begin : g_sram512_pair_delay
            // -----------------------------------------------------------------
            // STAGE=7 and STAGE=8 both use the 512x45 memory wrapper.
            //
            // Motivation:
            //   The previous STAGE=7 register implementation removed the 128x64
            //   hard macro, but it introduced a large distributed FF/register
            //   array and short local paths that can make APR hold closure much
            //   harder.  This version keeps the original two-lane SDF schedule
            //   but maps the packed pair buffer to the same 512x45 macro used by
            //   STAGE=8.
            //
            // Packing format, 45-bit word:
            //   {pad[44:44], lane1_im, lane1_re, lane0_im, lane0_re}
            // With W=11, only 44 bits are useful and bit[44] is padding.
            // -----------------------------------------------------------------
            localparam integer PAIR_AW = STAGE - 1;  // 6 for STAGE=7, 7 for STAGE=8

            reg                lane0_valid;
            reg                lane0_filled;
            reg                lane0_phase_second;
            reg signed [W-1:0] lane0_din_re;
            reg signed [W-1:0] lane0_din_im;
            reg signed [W-1:0] lane0_twd_re;
            reg signed [W-1:0] lane0_twd_im;

            reg                hold_valid;
            reg                hold_phase_second;
            reg signed [W-1:0] hold_old_re;
            reg signed [W-1:0] hold_old_im;
            reg signed [W-1:0] hold_twd_re;
            reg signed [W-1:0] hold_twd_im;

            wire lane0_cycle = valid_in && !addr[0];
            wire lane1_cycle = valid_in &&  addr[0];
            wire [PAIR_AW-1:0] pair_addr_low = addr[STAGE-1:1];
            wire [8:0] pair_addr = {{(9-PAIR_AW){1'b0}}, pair_addr_low};
            wire [44:0] pair_rd_word;

            wire signed [W-1:0] old0_re = pair_rd_word[W-1:0];
            wire signed [W-1:0] old0_im = pair_rd_word[(2*W)-1:W];
            wire signed [W-1:0] old1_re = pair_rd_word[(3*W)-1:(2*W)];
            wire signed [W-1:0] old1_im = pair_rd_word[(4*W)-1:(3*W)];

            wire signed [W-1:0] store0_re = lane0_phase_second ? (old0_re - lane0_twd_re) : lane0_din_re;
            wire signed [W-1:0] store0_im = lane0_phase_second ? (old0_im - lane0_twd_im) : lane0_din_im;
            wire signed [W-1:0] store1_re = phase_second ? (old1_re - twd_re) : din_re;
            wire signed [W-1:0] store1_im = phase_second ? (old1_im - twd_im) : din_im;

            wire [44:0] pair_wr_word = {{(45-(4*W)){1'b0}}, store1_im, store1_re, store0_im, store0_re};

            sram512x45_sp u_delay (
                .clk     (clk),
                .rst_n   (rst_n),
                .rd_en   (lane0_cycle),
                .rd_addr (pair_addr),
                .rd_data (pair_rd_word),
                .wr_en   (lane1_cycle && lane0_valid),
                .wr_addr (pair_addr),
                .wr_data (pair_wr_word)
            );

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    tw_re_r            <= 16'sd16384;
                    tw_im_r            <= 16'sd0;
                    cnt                <= {(STAGE+1){1'b0}};
                    fill_cnt           <= {(ADDR_W+1){1'b0}};
                    lane0_valid        <= 1'b0;
                    lane0_filled       <= 1'b0;
                    lane0_phase_second <= 1'b0;
                    lane0_din_re       <= {W{1'b0}};
                    lane0_din_im       <= {W{1'b0}};
                    lane0_twd_re       <= {W{1'b0}};
                    lane0_twd_im       <= {W{1'b0}};
                    hold_valid         <= 1'b0;
                    hold_phase_second  <= 1'b0;
                    hold_old_re        <= {W{1'b0}};
                    hold_old_im        <= {W{1'b0}};
                    hold_twd_re        <= {W{1'b0}};
                    hold_twd_im        <= {W{1'b0}};
                    valid_out          <= 1'b0;
                    dout_re            <= {W{1'b0}};
                    dout_im            <= {W{1'b0}};
                end else begin
                    tw_re_r    <= tw_re;
                    tw_im_r    <= tw_im;
                    valid_out  <= 1'b0;
                    hold_valid <= 1'b0;

                    if (hold_valid) begin
                        valid_out <= 1'b1;
                        if (!hold_phase_second) begin
                            dout_re <= hold_old_re;
                            dout_im <= hold_old_im;
                        end else begin
                            dout_re <= hold_old_re + hold_twd_re;
                            dout_im <= hold_old_im + hold_twd_im;
                        end
                    end

                    if (lane1_cycle && lane0_valid && lane0_filled) begin
                        valid_out <= 1'b1;
                        if (!lane0_phase_second) begin
                            dout_re <= old0_re;
                            dout_im <= old0_im;
                        end else begin
                            dout_re <= old0_re + lane0_twd_re;
                            dout_im <= old0_im + lane0_twd_im;
                        end
                    end

                    if (valid_in) begin
                        cnt <= cnt + {{STAGE{1'b0}}, 1'b1};
                        if (!filled) begin
                            fill_cnt <= fill_cnt + {{ADDR_W{1'b0}}, 1'b1};
                        end

                        if (!addr[0]) begin
                            lane0_valid        <= 1'b1;
                            lane0_filled       <= filled;
                            lane0_phase_second <= phase_second;
                            lane0_din_re       <= din_re;
                            lane0_din_im       <= din_im;
                            lane0_twd_re       <= twd_re;
                            lane0_twd_im       <= twd_im;
                        end else begin
                            lane0_valid       <= 1'b0;
                            hold_valid        <= lane0_valid && filled;
                            hold_phase_second <= phase_second;
                            hold_old_re       <= old1_re;
                            hold_old_im       <= old1_im;
                            hold_twd_re       <= twd_re;
                            hold_twd_im       <= twd_im;
                        end
                    end
                end
            end
        end
    endgenerate
endmodule
