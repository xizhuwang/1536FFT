`timescale 1 ns / 10 ps

module Top_PureDIT (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       valid_in,
    input  wire [2:0] din_re,
    input  wire [2:0] din_im,
    output reg        valid_out,
    output reg  [7:0] dout_re,
    output reg  [7:0] dout_im
);
    localparam integer W = 11;
    localparam integer Q_IN = 2;
    localparam integer Q_OUT = 4;

    reg        wr_bank;
    reg [8:0]  wr_addr;
    reg [1:0]  wr_lane;
    reg [11:0] pack_lo;

    reg        proc_active;
    reg        proc_bank;
    reg [10:0] proc_cnt;
    reg        pending_valid;
    reg        pending_bank;
    reg        flush_active;
    reg [10:0] flush_cnt;

    reg        rd_valid;
    reg        rd_bank_d;
    reg [1:0]  rd_lane;

    reg        core_in_valid;
    reg signed [W-1:0] core_in_re;
    reg signed [W-1:0] core_in_im;

    wire signed [2:0] din_re_s = din_re;
    wire signed [2:0] din_im_s = din_im;
    wire [5:0] input_lane = {din_re, din_im};
    wire [44:0] input_pack_word = {27'd0, input_lane, pack_lo};
    wire input_word_done = valid_in && (wr_lane == 2'd2);
    wire input_frame_done = input_word_done && (wr_addr == 9'd511);
    wire [8:0] proc_rd_addr = bit_reverse_9(proc_cnt[8:0]);

    wire        in0_wr_en = input_word_done && !wr_bank;
    wire        in1_wr_en = input_word_done &&  wr_bank;
    wire        in0_rd_en = proc_active && !proc_bank;
    wire        in1_rd_en = proc_active &&  proc_bank;
    wire [44:0] in0_rd_data;
    wire [44:0] in1_rd_data;
    wire [44:0] in_rd_data = rd_bank_d ? in1_rd_data : in0_rd_data;

    function [8:0] bit_reverse_9;
        input [8:0] x;
        integer bi;
        begin
            for (bi = 0; bi < 9; bi = bi + 1) begin
                bit_reverse_9[8-bi] = x[bi];
            end
        end
    endfunction

    function signed [W-1:0] sign_extend_lane;
        input [2:0] x;
        reg signed [2:0] xs;
        begin
            xs = x;
            sign_extend_lane = {{(W-3){xs[2]}}, xs} <<< Q_IN;
        end
    endfunction

    function [5:0] select_lane;
        input [44:0] word;
        input [1:0]  lane;
        begin
            case (lane)
                2'd0: select_lane = word[5:0];
                2'd1: select_lane = word[11:6];
                default: select_lane = word[17:12];
            endcase
        end
    endfunction

    wire [5:0] core_lane = select_lane(in_rd_data, rd_lane);

    sram512x45_sp u_in_bank0 (
        .clk(clk), .rst_n(rst_n),
        .rd_en(in0_rd_en), .rd_addr(proc_rd_addr), .rd_data(in0_rd_data),
        .wr_en(in0_wr_en), .wr_addr(wr_addr), .wr_data(input_pack_word)
    );

    sram512x45_sp u_in_bank1 (
        .clk(clk), .rst_n(rst_n),
        .rd_en(in1_rd_en), .rd_addr(proc_rd_addr), .rd_data(in1_rd_data),
        .wr_en(in1_wr_en), .wr_addr(wr_addr), .wr_data(input_pack_word)
    );

    wire fft_valid;
    wire signed [W-1:0] fft_re;
    wire signed [W-1:0] fft_im;

    fft512_dit_sdf_core #(.W(W)) u_fft512 (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (core_in_valid),
        .din_re    (core_in_re),
        .din_im    (core_in_im),
        .valid_out (fft_valid),
        .dout_re   (fft_re),
        .dout_im   (fft_im)
    );

    reg [10:0] fft_out_cnt;
    wire [1:0] fft_branch = fft_out_cnt[10:9];
    wire [8:0] fft_k = fft_out_cnt[8:0];

    wire        b0_wr_en = fft_valid && (fft_branch == 2'd0);
    wire        b1_wr_en = fft_valid && (fft_branch == 2'd1);
    wire        b01_rd_en = fft_valid && (fft_branch == 2'd2);
    wire [44:0] b0_rd_data;
    wire [44:0] b1_rd_data;
    wire [44:0] b_sram_wr_data = {1'b0, fft_im, fft_re};

    sram512x45_sp u_b0_align (
        .clk(clk), .rst_n(rst_n),
        .rd_en(b01_rd_en), .rd_addr(fft_k), .rd_data(b0_rd_data),
        .wr_en(b0_wr_en), .wr_addr(fft_k), .wr_data(b_sram_wr_data)
    );

    sram512x45_sp u_b1_align (
        .clk(clk), .rst_n(rst_n),
        .rd_en(b01_rd_en), .rd_addr(fft_k), .rd_data(b1_rd_data),
        .wr_en(b1_wr_en), .wr_addr(fft_k), .wr_data(b_sram_wr_data)
    );

    reg        r3_in_valid;
    reg [8:0]  r3_k;
    reg signed [W-1:0] r3_b0_re;
    reg signed [W-1:0] r3_b0_im;
    reg signed [W-1:0] r3_b1_re;
    reg signed [W-1:0] r3_b1_im;
    reg signed [W-1:0] r3_b2_re;
    reg signed [W-1:0] r3_b2_im;

    reg        b2_valid_d;
    reg [8:0]  b2_k_d;
    reg signed [W-1:0] b2_re_d;
    reg signed [W-1:0] b2_im_d;

    wire       r3_valid;
    wire [8:0] r3_k_out;
    wire signed [7:0] r3_x0_re;
    wire signed [7:0] r3_x0_im;
    wire signed [7:0] r3_x1_re;
    wire signed [7:0] r3_x1_im;
    wire signed [7:0] r3_x2_re;
    wire signed [7:0] r3_x2_im;

    radix3_back_end #(.W(W), .Q_SHIFT(Q_OUT)) u_radix3 (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (r3_in_valid),
        .k_in      (r3_k),
        .b0_re     (r3_b0_re),
        .b0_im     (r3_b0_im),
        .b1_re     (r3_b1_re),
        .b1_im     (r3_b1_im),
        .b2_re     (r3_b2_re),
        .b2_im     (r3_b2_im),
        .valid_out (r3_valid),
        .k_out     (r3_k_out),
        .x0_re     (r3_x0_re),
        .x0_im     (r3_x0_im),
        .x1_re     (r3_x1_re),
        .x1_im     (r3_x1_im),
        .x2_re     (r3_x2_re),
        .x2_im     (r3_x2_im)
    );

    reg        out_active;
    reg        out_read_phase;
    reg [8:0]  out_read_idx;
    reg        out_data_valid;
    reg        out_data_phase;
    reg        out_data_last;
    reg        out_data_from_head;
    reg [7:0]  out_head_x1_re;
    reg [7:0]  out_head_x1_im;

    wire [44:0] out_buf_rd_data;
    wire [44:0] out_buf_wr_data = {13'd0, r3_x2_im, r3_x2_re, r3_x1_im, r3_x1_re};
    wire        out_buf_rd_en = out_active && !(out_data_valid && out_data_phase && out_data_last);

    sram512x45_sp u_out_buf (
        .clk(clk), .rst_n(rst_n),
        .rd_en(out_buf_rd_en), .rd_addr(out_read_idx), .rd_data(out_buf_rd_data),
        .wr_en(!out_active && r3_valid), .wr_addr(r3_k_out), .wr_data(out_buf_wr_data)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_bank       <= 1'b0;
            wr_addr       <= 9'd0;
            wr_lane       <= 2'd0;
            pack_lo       <= 12'd0;
            proc_active   <= 1'b0;
            proc_bank     <= 1'b0;
            proc_cnt      <= 11'd0;
            pending_valid <= 1'b0;
            pending_bank  <= 1'b0;
            flush_active  <= 1'b0;
            flush_cnt     <= 11'd0;
            rd_valid      <= 1'b0;
            rd_bank_d     <= 1'b0;
            rd_lane       <= 2'd0;
            core_in_valid <= 1'b0;
            core_in_re    <= {W{1'b0}};
            core_in_im    <= {W{1'b0}};
            fft_out_cnt   <= 11'd0;
            r3_in_valid   <= 1'b0;
            r3_k          <= 9'd0;
            r3_b0_re      <= {W{1'b0}};
            r3_b0_im      <= {W{1'b0}};
            r3_b1_re      <= {W{1'b0}};
            r3_b1_im      <= {W{1'b0}};
            r3_b2_re      <= {W{1'b0}};
            r3_b2_im      <= {W{1'b0}};
            b2_valid_d    <= 1'b0;
            b2_k_d        <= 9'd0;
            b2_re_d       <= {W{1'b0}};
            b2_im_d       <= {W{1'b0}};
            out_active    <= 1'b0;
            out_read_phase <= 1'b0;
            out_read_idx   <= 9'd0;
            out_data_valid <= 1'b0;
            out_data_phase <= 1'b0;
            out_data_last  <= 1'b0;
            out_data_from_head <= 1'b0;
            out_head_x1_re <= 8'd0;
            out_head_x1_im <= 8'd0;
            valid_out     <= 1'b0;
            dout_re       <= 8'd0;
            dout_im       <= 8'd0;
        end else begin
            rd_valid      <= 1'b0;
            core_in_valid <= rd_valid || flush_active;
            r3_in_valid   <= b2_valid_d;
            valid_out     <= 1'b0;
            out_data_valid <= out_buf_rd_en;
            if (out_buf_rd_en) begin
                out_data_phase <= out_read_phase;
                out_data_last  <= out_read_phase && (out_read_idx == 9'd511);
                out_data_from_head <= 1'b0;

                if (out_read_idx == 9'd511) begin
                    out_read_idx   <= 9'd0;
                    out_read_phase <= 1'b1;
                end else begin
                    out_read_idx <= out_read_idx + 9'd1;
                end
            end

            if (rd_valid) begin
                core_in_re <= sign_extend_lane(core_lane[5:3]);
                core_in_im <= sign_extend_lane(core_lane[2:0]);
            end else begin
                core_in_re <= {W{1'b0}};
                core_in_im <= {W{1'b0}};
            end

            if (flush_active) begin
                if (flush_cnt == 11'd1535) begin
                    flush_active <= 1'b0;
                    flush_cnt    <= 11'd0;
                end else begin
                    flush_cnt <= flush_cnt + 11'd1;
                end
            end

            if (b2_valid_d) begin
                r3_k     <= b2_k_d;
                r3_b0_re <= b0_rd_data[W-1:0];
                r3_b0_im <= b0_rd_data[(2*W)-1:W];
                r3_b1_re <= b1_rd_data[W-1:0];
                r3_b1_im <= b1_rd_data[(2*W)-1:W];
                r3_b2_re <= b2_re_d;
                r3_b2_im <= b2_im_d;
            end

            if (valid_in) begin
                if (wr_lane == 2'd0) begin
                    pack_lo[5:0] <= input_lane;
                    wr_lane <= 2'd1;
                end else if (wr_lane == 2'd1) begin
                    pack_lo[11:6] <= input_lane;
                    wr_lane <= 2'd2;
                end else begin
                    wr_lane <= 2'd0;
                    pack_lo <= 12'd0;

                    if (wr_addr == 9'd511) begin
                        wr_addr <= 9'd0;
                        if (!proc_active) begin
                            proc_active <= 1'b1;
                            proc_bank   <= wr_bank;
                            proc_cnt    <= 11'd0;
                        end else if (proc_cnt != 11'd1535) begin
                            pending_valid <= 1'b1;
                            pending_bank  <= wr_bank;
                        end
                        wr_bank <= ~wr_bank;
                    end else begin
                        wr_addr <= wr_addr + 9'd1;
                    end
                end
            end

            if (proc_active) begin
                rd_valid <= 1'b1;
                rd_bank_d <= proc_bank;
                rd_lane  <= proc_cnt[10:9];

                if (proc_cnt == 11'd1535) begin
                    if (input_frame_done) begin
                        proc_bank     <= wr_bank;
                        proc_cnt      <= 11'd0;
                        pending_valid <= 1'b0;
                    end else if (pending_valid) begin
                        proc_bank     <= pending_bank;
                        proc_cnt      <= 11'd0;
                        pending_valid <= 1'b0;
                    end else begin
                        proc_active <= 1'b0;
                        proc_cnt    <= 11'd0;
                        flush_active <= 1'b1;
                        flush_cnt    <= 11'd0;
                    end
                end else begin
                    proc_cnt <= proc_cnt + 11'd1;
                end
            end

            if (fft_valid) begin
                if (fft_branch == 2'd2) begin
                    b2_valid_d <= 1'b1;
                    b2_k_d     <= fft_k;
                    b2_re_d    <= fft_re;
                    b2_im_d    <= fft_im;
                end else begin
                    b2_valid_d <= 1'b0;
                end

                if (fft_out_cnt == 11'd1535) begin
                    fft_out_cnt <= 11'd0;
                end else begin
                    fft_out_cnt <= fft_out_cnt + 11'd1;
                end
            end else begin
                b2_valid_d <= 1'b0;
            end

            if (!out_active && r3_valid && (r3_k_out == 9'd0)) begin
                out_head_x1_re <= r3_x1_re;
                out_head_x1_im <= r3_x1_im;
            end

            if (!out_active && r3_valid && (r3_k_out == 9'd511)) begin
                out_active         <= 1'b1;
                out_read_phase     <= 1'b0;
                out_read_idx       <= 9'd1;
                out_data_valid     <= 1'b1;
                out_data_phase     <= 1'b0;
                out_data_last      <= 1'b0;
                out_data_from_head <= 1'b1;
            end

            if (out_data_valid) begin
                valid_out <= 1'b1;
                if (out_data_from_head) begin
                    dout_re <= out_head_x1_re;
                    dout_im <= out_head_x1_im;
                end else if (!out_data_phase) begin
                    dout_re <= out_buf_rd_data[7:0];
                    dout_im <= out_buf_rd_data[15:8];
                end else begin
                    dout_re <= out_buf_rd_data[23:16];
                    dout_im <= out_buf_rd_data[31:24];
                end

                if (out_data_phase && out_data_last) begin
                    out_active         <= 1'b0;
                    out_read_phase     <= 1'b0;
                    out_read_idx       <= 9'd0;
                    out_data_valid     <= 1'b0;
                    out_data_phase     <= 1'b0;
                    out_data_last      <= 1'b0;
                    out_data_from_head <= 1'b0;
                end
            end

            if (!out_active && r3_valid) begin
                valid_out <= 1'b1;
                dout_re   <= r3_x0_re;
                dout_im   <= r3_x0_im;
            end
        end
    end
endmodule
