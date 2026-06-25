`timescale 1ns/10ps

module tb_core;
    parameter W_DATA = 20;
    parameter W_TW   = 12;
    parameter N      = 1536;
    parameter FRAMES = 10;
    parameter TOTAL_SAMPLES = N * FRAMES;
    parameter FLUSH_SAMPLES = 1536 + 512 + 128 + 32 + 8;
    parameter RESET_CYCLES  = 8;
    parameter POST_RESET_IDLE_CYCLES = 2;

    reg                         clk;
    reg                         rst_n;
    reg                         valid_in;
    reg signed [W_DATA-1:0]     din_re;
    reg signed [W_DATA-1:0]     din_im;

    wire                        valid_out;
    wire signed [W_DATA-1:0]    dout_re;
    wire signed [W_DATA-1:0]    dout_im;

    fft1536_core #(.W_DATA(W_DATA), .W_TW(W_TW)) u_core (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .din_re(din_re), .din_im(din_im),
        .valid_out(valid_out), .dout_re(dout_re), .dout_im(dout_im)
    );

    initial begin
        clk = 1'b0;
        forever #1.2 clk = ~clk;
    end

    initial begin
        $dumpfile("tb_core_debug.vcd");
        $dumpvars(0, tb_core);
    end

    integer fd_in_re, fd_in_im, fd_gold_re, fd_gold_im;
    integer scan_re, scan_im;
    integer tmp_re, tmp_im;
    integer in_cnt, out_cnt, err_cnt, flush_cnt;
    integer dump_r3_re, dump_r3_im;
    integer dump_s1_re, dump_s1_im;
    integer dump_s2_re, dump_s2_im;
    integer dump_s3_re, dump_s3_im;
    integer dump_s4_re, dump_s4_im;
    integer dump_r2_re, dump_r2_im;
    integer cnt_r3, cnt_s1, cnt_s2, cnt_s3, cnt_s4, cnt_r2;
    integer rst_wait_cnt;
    integer post_rst_wait_cnt;

    reg signed [W_DATA-1:0] gold_re [0:TOTAL_SAMPLES-1];
    reg signed [W_DATA-1:0] gold_im [0:TOTAL_SAMPLES-1];

    initial begin
        fd_gold_re = $fopen("hw_core_raw_re.txt", "r");
        fd_gold_im = $fopen("hw_core_raw_im.txt", "r");
        if (fd_gold_re == 0 || fd_gold_im == 0) begin
            $display("ERROR: cannot open golden output files.");
            $finish;
        end
        for (out_cnt = 0; out_cnt < TOTAL_SAMPLES; out_cnt = out_cnt + 1) begin
            scan_re = $fscanf(fd_gold_re, "%d\n", tmp_re);
            scan_im = $fscanf(fd_gold_im, "%d\n", tmp_im);
            gold_re[out_cnt] = tmp_re;
            gold_im[out_cnt] = tmp_im;
        end
        $fclose(fd_gold_re);
        $fclose(fd_gold_im);

        fd_in_re = $fopen("tb_in_re.txt", "r");
        fd_in_im = $fopen("tb_in_im.txt", "r");
        if (fd_in_re == 0 || fd_in_im == 0) begin
            $display("ERROR: cannot open input files.");
            $finish;
        end

        dump_r3_re = $fopen("stage_r3_re.txt", "w");
        dump_r3_im = $fopen("stage_r3_im.txt", "w");
        dump_s1_re = $fopen("stage_r22_1_re.txt", "w");
        dump_s1_im = $fopen("stage_r22_1_im.txt", "w");
        dump_s2_re = $fopen("stage_r22_2_re.txt", "w");
        dump_s2_im = $fopen("stage_r22_2_im.txt", "w");
        dump_s3_re = $fopen("stage_r22_3_re.txt", "w");
        dump_s3_im = $fopen("stage_r22_3_im.txt", "w");
        dump_s4_re = $fopen("stage_r22_4_re.txt", "w");
        dump_s4_im = $fopen("stage_r22_4_im.txt", "w");
        dump_r2_re = $fopen("stage_r2_re.txt", "w");
        dump_r2_im = $fopen("stage_r2_im.txt", "w");

        rst_n = 1'b0;
        valid_in = 1'b0;
        din_re = {W_DATA{1'b0}};
        din_im = {W_DATA{1'b0}};
        in_cnt = 0;
        out_cnt = 0;
        err_cnt = 0;
        flush_cnt = 0;
        cnt_r3 = 0;
        cnt_s1 = 0;
        cnt_s2 = 0;
        cnt_s3 = 0;
        cnt_s4 = 0;
        cnt_r2 = 0;

        for (rst_wait_cnt = 0; rst_wait_cnt < RESET_CYCLES; rst_wait_cnt = rst_wait_cnt + 1)
            @(negedge clk);

        rst_n = 1'b1;

        for (post_rst_wait_cnt = 0; post_rst_wait_cnt < POST_RESET_IDLE_CYCLES; post_rst_wait_cnt = post_rst_wait_cnt + 1) begin
            @(negedge clk);
            valid_in = 1'b0;
            din_re = {W_DATA{1'b0}};
            din_im = {W_DATA{1'b0}};
        end

        while (!$feof(fd_in_re) && in_cnt < TOTAL_SAMPLES) begin
            @(negedge clk);
            valid_in = 1'b1;
            scan_re = $fscanf(fd_in_re, "%d\n", tmp_re);
            scan_im = $fscanf(fd_in_im, "%d\n", tmp_im);
            din_re = tmp_re;
            din_im = tmp_im;
            in_cnt = in_cnt + 1;
        end

        while (flush_cnt < FLUSH_SAMPLES) begin
            @(negedge clk);
            valid_in = 1'b1;
            din_re = {W_DATA{1'b0}};
            din_im = {W_DATA{1'b0}};
            flush_cnt = flush_cnt + 1;
        end

        @(negedge clk);
        valid_in = 1'b0;
        din_re = {W_DATA{1'b0}};
        din_im = {W_DATA{1'b0}};
    end

    always @(negedge clk) begin
        if (u_core.v0) begin
            $fwrite(dump_r3_re, "%0d\n", u_core.d0_re);
            $fwrite(dump_r3_im, "%0d\n", u_core.d0_im);
            cnt_r3 = cnt_r3 + 1;
        end
        if (u_core.v1) begin
            $fwrite(dump_s1_re, "%0d\n", u_core.d1_re);
            $fwrite(dump_s1_im, "%0d\n", u_core.d1_im);
            cnt_s1 = cnt_s1 + 1;
        end
        if (u_core.v2) begin
            $fwrite(dump_s2_re, "%0d\n", u_core.d2_re);
            $fwrite(dump_s2_im, "%0d\n", u_core.d2_im);
            cnt_s2 = cnt_s2 + 1;
        end
        if (u_core.v3) begin
            $fwrite(dump_s3_re, "%0d\n", u_core.d3_re);
            $fwrite(dump_s3_im, "%0d\n", u_core.d3_im);
            cnt_s3 = cnt_s3 + 1;
        end
        if (u_core.v4) begin
            $fwrite(dump_s4_re, "%0d\n", u_core.d4_re);
            $fwrite(dump_s4_im, "%0d\n", u_core.d4_im);
            cnt_s4 = cnt_s4 + 1;
        end
        if (u_core.v5) begin
            $fwrite(dump_r2_re, "%0d\n", u_core.d5_re);
            $fwrite(dump_r2_im, "%0d\n", u_core.d5_im);
            cnt_r2 = cnt_r2 + 1;

            if (u_core.d5_re !== gold_re[out_cnt] || u_core.d5_im !== gold_im[out_cnt]) begin
                if (err_cnt < 20) begin
                    $display("[ERROR] Final mismatch at index %0d", out_cnt);
                    $display("  RTL   : %0d + j(%0d)", u_core.d5_re, u_core.d5_im);
                    $display("  GOLD  : %0d + j(%0d)", gold_re[out_cnt], gold_im[out_cnt]);
                end
                err_cnt = err_cnt + 1;
            end
            out_cnt = out_cnt + 1;

            if (out_cnt == TOTAL_SAMPLES) begin
                $display("========================================");
                $display("inputs=%0d flush=%0d outputs=%0d", in_cnt, flush_cnt, out_cnt);
                $display("stage counts: r3=%0d s1=%0d s2=%0d s3=%0d s4=%0d r2=%0d", cnt_r3, cnt_s1, cnt_s2, cnt_s3, cnt_s4, cnt_r2);
                if (err_cnt == 0)
                    $display(">>> SUCCESS: CORE RTL matches MATLAB exactly!");
                else
                    $display(">>> FAIL: %0d mismatches found.", err_cnt);
                $display("Generated dump files: stage_r3_*, stage_r22_1_*, stage_r22_2_*, stage_r22_3_*, stage_r22_4_*, stage_r2_*");
                $display("========================================");
                $fclose(fd_in_re);    $fclose(fd_in_im);
                $fclose(dump_r3_re);  $fclose(dump_r3_im);
                $fclose(dump_s1_re);  $fclose(dump_s1_im);
                $fclose(dump_s2_re);  $fclose(dump_s2_im);
                $fclose(dump_s3_re);  $fclose(dump_s3_im);
                $fclose(dump_s4_re);  $fclose(dump_s4_im);
                $fclose(dump_r2_re);  $fclose(dump_r2_im);
                $finish;
            end
        end
    end
endmodule
