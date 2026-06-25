`timescale 1ns/10ps

module tb_chip;
    parameter N               = 1536;
    parameter FRAMES          = 10;
    parameter TOTAL_SAMPLES   = N * FRAMES;
    parameter OUT_SHIFT       = 7;
    parameter INPUT_SCALE     = 1024;
    parameter FLUSH_CYCLES    = 2216;
    parameter DEFAULT_ABS_TOL = 0;
    parameter MAX_ERR_PRINT   = 50;

    reg                  clk;
    reg                  rst_n;
    reg                  valid_in;
    reg  signed [2:0]    din_re;
    reg  signed [2:0]    din_im;

    wire signed [7:0]    dout_re;
    wire signed [7:0]    dout_im;
    wire                 valid_out;

    `ifdef POST_SIM
    supply1 VDD;
    supply0 VSS;

    CHIP U_CHIP (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .din_re   (din_re),
        .din_im   (din_im),
        .dout_re  (dout_re),
        .dout_im  (dout_im),
        .valid_out(valid_out),
        .VDD      (VDD),
        .VSS      (VSS)
    );
    `else
        CHIP U_CHIP (
            .clk      (clk),
            .rst_n    (rst_n),
            .valid_in (valid_in),
            .din_re   (din_re),
            .din_im   (din_im),
            .dout_re  (dout_re),
            .dout_im  (dout_im),
            .valid_out(valid_out)
        );
    `endif

    `ifdef POST_SIM
    initial begin
        $display("[POST_SIM] SDF annotation block is ACTIVE at %0t", $time);
        $sdf_annotate("post.sdf", U_CHIP, , "sdf_annotate.log", "MAXIMUM");
    end
    `endif
    initial begin
        clk = 1'b0;
        forever #1.2 clk = ~clk;
    end
    initial begin
        if (!$test$plusargs("NO_VCD")) begin
            $dumpfile("tb_chip_debug.vcd");
            if ($test$plusargs("DUMP_ALL")) begin
                $dumpvars(0, tb_chip);
            end else begin
                // Depth-1 dump is much smaller/faster. Use +DUMP_ALL only when deep debug is needed.
                $dumpvars(1, tb_chip);
            end
        end
    end

    integer fd_in_re, fd_in_im, fd_gold_re, fd_gold_im;
    integer fd_dump_re, fd_dump_im;
    integer scan_re, scan_im;
    integer tmp_re, tmp_im;
    integer vin_re, vin_im;
    integer in_cnt, out_cnt, err_cnt, flush_cnt;
    integer sim_frames, sim_samples, timeout_cycles;
    integer gold_re [0:TOTAL_SAMPLES-1];
    integer gold_im [0:TOTAL_SAMPLES-1];
    integer exp_re, exp_im;
    integer abs_tol;
    integer diff_re, diff_im;
    integer max_abs_err_re, max_abs_err_im;
    integer printed_errs;

    function integer abs_int;
        input integer vin;
        begin
            if (vin < 0)
                abs_int = -vin;
            else
                abs_int = vin;
        end
    endfunction

    function integer quant_ref;
        input integer vin;
        integer rounded;
        begin
            if (vin >= 0)
                rounded = vin + (1 << (OUT_SHIFT-1));
            else
                rounded = vin - (1 << (OUT_SHIFT-1));
            rounded = rounded >>> OUT_SHIFT;

            if (rounded > 127)
                quant_ref = 127;
            else if (rounded < -128)
                quant_ref = -128;
            else
                quant_ref = rounded;
        end
    endfunction

    initial begin
        abs_tol = DEFAULT_ABS_TOL;
        if ($value$plusargs("ABS_TOL=%d", abs_tol)) begin
        end
        if ($test$plusargs("EXACT"))
            abs_tol = 0;

        sim_frames = FRAMES;
        if ($value$plusargs("SIM_FRAMES=%d", sim_frames)) begin
        end
        if (sim_frames < 1)
            sim_frames = 1;
        if (sim_frames > FRAMES)
            sim_frames = FRAMES;
        sim_samples = N * sim_frames;

        if (!$value$plusargs("TIMEOUT_CYCLES=%d", timeout_cycles)) begin
            // Conservative timeout for functional post-sim; increase with +TIMEOUT_CYCLES if needed.
            timeout_cycles = sim_samples + FLUSH_CYCLES + 10000;
        end

        $display("[tb_chip] MAX_FRAMES=%0d SIM_FRAMES=%0d SIM_SAMPLES=%0d OUT_SHIFT=%0d INPUT_SCALE=%0d FLUSH_CYCLES=%0d ABS_TOL=%0d",
                 FRAMES, sim_frames, sim_samples, OUT_SHIFT, INPUT_SCALE, FLUSH_CYCLES, abs_tol);

        fd_gold_re = $fopen("hw_core_raw_re.txt", "r");
        fd_gold_im = $fopen("hw_core_raw_im.txt", "r");
        fd_in_re   = $fopen("tb_in_re.txt", "r");
        fd_in_im   = $fopen("tb_in_im.txt", "r");
        fd_dump_re = $fopen("chip_out_re.txt", "w");
        fd_dump_im = $fopen("chip_out_im.txt", "w");

        if (fd_gold_re == 0 || fd_gold_im == 0 || fd_in_re == 0 || fd_in_im == 0 ||
            fd_dump_re == 0 || fd_dump_im == 0) begin
            $display("ERROR: cannot open one or more vector files.");
            $finish;
        end

        for (out_cnt = 0; out_cnt < sim_samples; out_cnt = out_cnt + 1) begin
            scan_re = $fscanf(fd_gold_re, "%d\n", tmp_re);
            scan_im = $fscanf(fd_gold_im, "%d\n", tmp_im);
            gold_re[out_cnt] = tmp_re;
            gold_im[out_cnt] = tmp_im;
        end
        $fclose(fd_gold_re);
        $fclose(fd_gold_im);

        rst_n          = 1'b1;
        valid_in       = 1'b0;
        din_re         = 3'sd0;
        din_im         = 3'sd0;
        in_cnt         = 0;
        out_cnt        = 0;
        err_cnt        = 0;
        max_abs_err_re = 0;
        max_abs_err_im = 0;
        printed_errs   = 0;

        #10 rst_n = 1'b0;
        #20 rst_n = 1'b1;
        #10;

        while (!$feof(fd_in_re) && in_cnt < sim_samples) begin
            @(negedge clk);
            valid_in = 1'b1;
            scan_re = $fscanf(fd_in_re, "%d\n", tmp_re);
            scan_im = $fscanf(fd_in_im, "%d\n", tmp_im);

            vin_re = tmp_re / INPUT_SCALE;
            vin_im = tmp_im / INPUT_SCALE;
            din_re = vin_re[2:0];
            din_im = vin_im[2:0];
            in_cnt = in_cnt + 1;
        end

        for (flush_cnt = 0; flush_cnt < FLUSH_CYCLES; flush_cnt = flush_cnt + 1) begin
            @(negedge clk);
            valid_in = 1'b1;
            din_re   = 3'sd0;
            din_im   = 3'sd0;
        end

        @(negedge clk);
        valid_in = 1'b0;
        din_re   = 3'sd0;
        din_im   = 3'sd0;
    end

    initial begin
        // Prevent infinite post-sim runs if valid_out never reaches the requested sample count.
        #1;
        wait (rst_n === 1'b1);
        repeat (timeout_cycles) @(posedge clk);
        if (out_cnt < sim_samples) begin
            $display("========================================");
            $display(">>> TIMEOUT: outputs=%0d expected=%0d after timeout_cycles=%0d",
                     out_cnt, sim_samples, timeout_cycles);
            $display("========================================");
            $finish;
        end
    end

    always @(negedge clk) begin
        if (valid_out) begin
            exp_re = quant_ref(gold_re[out_cnt]);
            exp_im = quant_ref(gold_im[out_cnt]);

            $fwrite(fd_dump_re, "%0d\n", $signed(dout_re));
            $fwrite(fd_dump_im, "%0d\n", $signed(dout_im));

            diff_re = $signed(dout_re) - exp_re;
            diff_im = $signed(dout_im) - exp_im;

            if (abs_int(diff_re) > max_abs_err_re)
                max_abs_err_re = abs_int(diff_re);
            if (abs_int(diff_im) > max_abs_err_im)
                max_abs_err_im = abs_int(diff_im);

            if (abs_int(diff_re) > abs_tol || abs_int(diff_im) > abs_tol) begin
                if (printed_errs < MAX_ERR_PRINT) begin
                    $display("[ERROR] CHIP mismatch at index %0d", out_cnt);
                    $display("  CHIP  : %0d + j(%0d)", $signed(dout_re), $signed(dout_im));
                    $display("  GOLDQ : %0d + j(%0d)", exp_re, exp_im);
                    $display("  DIFF  : %0d + j(%0d)", diff_re, diff_im);
                end
                err_cnt = err_cnt + 1;
                printed_errs = printed_errs + 1;
            end

            out_cnt = out_cnt + 1;
            if (out_cnt == sim_samples) begin
                $display("========================================");
                $display("inputs=%0d flush=%0d outputs=%0d", in_cnt, FLUSH_CYCLES, out_cnt);
                $display("ABS_TOL=%0d max_abs_error: re=%0d im=%0d", abs_tol, max_abs_err_re, max_abs_err_im);
                if (err_cnt == 0)
                    $display(">>> SUCCESS: CHIP quantized output matches golden within tolerance!");
                else
                    $display(">>> FAIL: %0d mismatches found.", err_cnt);
                if (printed_errs > MAX_ERR_PRINT)
                    $display("(Only first %0d mismatches were printed)", MAX_ERR_PRINT);
                $display("========================================");
                $fclose(fd_in_re);
                $fclose(fd_in_im);
                $fclose(fd_dump_re);
                $fclose(fd_dump_im);
                $finish;
            end
        end
    end
endmodule
