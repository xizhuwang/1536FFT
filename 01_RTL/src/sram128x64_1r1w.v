`timescale 1 ns / 10 ps

module sram128x64_1r1w (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        rd_en,
    input  wire [6:0]  rd_addr,
    output wire [63:0] rd_data,
    input  wire        wr_en,
    input  wire [6:0]  wr_addr,
    input  wire [63:0] wr_data
);
    reg [63:0] mem [0:127];
    reg [63:0] rd_q;
    assign rd_data = rd_q;

    integer i;
    initial begin
        for (i = 0; i < 128; i = i + 1) begin
            mem[i] = 64'd0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_q <= 64'd0;
        end else begin
            if (wr_en) begin
                mem[wr_addr] <= wr_data;
            end
            if (rd_en) begin
                rd_q <= mem[rd_addr];
            end
        end
    end
endmodule
