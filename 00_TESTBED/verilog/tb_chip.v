`timescale 1 ns / 10 ps

module tb_chip;
    parameter t = 2;
    parameter real OUT_SHIFT = -2;
    parameter th = t * 0.5;

    parameter INPUT_SIZE = 3;
    parameter OUTPUT_SIZE = 8;
    parameter N_POINTS = 1536;
    parameter N_FRAME = 10;
    parameter TOTAL_POINTS = N_POINTS * N_FRAME;

    reg clk, rst_n, valid_in;
    reg [INPUT_SIZE-1:0] din_re, din_im;
    wire valid_out;
    wire [OUTPUT_SIZE-1:0] dout_re, dout_im;

    integer in_mem_re [0:TOTAL_POINTS-1];
    integer in_mem_im [0:TOTAL_POINTS-1];
    real gd_mem_re [0:TOTAL_POINTS-1];
    real gd_mem_im [0:TOTAL_POINTS-1];

    integer out_cnt = 0, hit_cnt = 0, n_loop = 0;
    real sig_pwr_sum = 0, err_pwr_sum = 0;
    real start_time, end_time, exe_time, throughput;
    integer fp_in, fp_gd, fp_out, i, scan_cnt1, scan_cnt2;
    integer t_r, t_i;
    real g_r, g_i, gd_r, gd_i, hw_r, hw_i, er_r, er_i, p_s, p_e;
    real snr, acc;

    CHIP U_CHIP (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .din_re(din_re),
        .din_im(din_im),
        .valid_out(valid_out),
        .dout_re(dout_re),
        .dout_im(dout_im)
    );
    initial begin $dumpfile("tb_chip.vcd"); $dumpvars(0, tb_chip); end
    initial begin $sdf_annotate("post.sdf", U_CHIP); end

    initial begin
        fp_in = $fopen("fft_1536_input.txt", "r");
        fp_gd = $fopen("fft_1536_output.txt", "r");
        fp_out = $fopen("my_output_scaled.txt", "w");
        if (fp_in == 0 || fp_gd == 0) begin
            $display("Failed to open data files!");
            $finish;
        end
        for (i = 0; i < TOTAL_POINTS; i = i + 1) begin
            scan_cnt1 = $fscanf(fp_in, "%d %d\n", t_r, t_i);
            in_mem_re[i] = t_r;
            in_mem_im[i] = t_i;
            scan_cnt2 = $fscanf(fp_gd, "%f %f\n", g_r, g_i);
            gd_mem_re[i] = g_r;
            gd_mem_im[i] = g_i;
        end
        $fclose(fp_in);
        $fclose(fp_gd);
        $display("Initialization completed.");
    end

    always #th clk = ~clk;

    initial begin
        clk = 1;
        rst_n = 1;
        valid_in = 0;
        din_re = 0;
        din_im = 0;
        #th rst_n = 0;
        // Release reset away from clock edges so SDF recovery/removal checks are meaningful.
        #(t*2 + th*0.5) rst_n = 1;
        start_time = $realtime;
        for (n_loop = 0; n_loop < TOTAL_POINTS; n_loop = n_loop + 1) begin
            valid_in = 1;
            din_re = in_mem_re[n_loop][INPUT_SIZE-1:0];
            din_im = in_mem_im[n_loop][INPUT_SIZE-1:0];
            #(t);
        end
        valid_in = 0;
        din_re = 0;
        din_im = 0;
    end

    always @(negedge clk) begin
        if (valid_out) begin
            gd_r = gd_mem_re[out_cnt];
            gd_i = gd_mem_im[out_cnt];
            hw_r = $signed(dout_re) / (2.0 ** OUT_SHIFT);
            hw_i = $signed(dout_im) / (2.0 ** OUT_SHIFT);
            $fdisplay(fp_out, "%f %f", hw_r, hw_i);
            er_r = hw_r - gd_r;
            er_i = hw_i - gd_i;
            p_s = (gd_r * gd_r) + (gd_i * gd_i);
            p_e = (er_r * er_r) + (er_i * er_i);
            sig_pwr_sum = sig_pwr_sum + p_s;
            err_pwr_sum = err_pwr_sum + p_e;
            if (p_e <= 1.0) hit_cnt = hit_cnt + 1;
            out_cnt = out_cnt + 1;
            if (out_cnt == TOTAL_POINTS) begin
                end_time = $realtime;
                exe_time = end_time - start_time;
                throughput = (TOTAL_POINTS * 1000.0) / exe_time;
                snr = 10.0 * $log10(sig_pwr_sum / err_pwr_sum);
                acc = (hit_cnt * 100.0) / TOTAL_POINTS;
                $fclose(fp_out);
                $display("=========================================================");
                $display("Throughput = %0.2f MS/s", throughput);
                $display("SNR        = %5.2f dB", snr);
                $display("out_cnt    = %0d", out_cnt);
                $display("=========================================================");
                #(t*10) $finish;
            end
        end
    end
endmodule
