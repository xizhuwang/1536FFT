`timescale 1 ns / 10 ps

module sram512x45_sp (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        rd_en,
    input  wire [8:0]  rd_addr,
    output wire [44:0] rd_data,
    input  wire        wr_en,
    input  wire [8:0]  wr_addr,
    input  wire [44:0] wr_data
);
    reg [44:0] mem [0:511];
    reg [44:0] rd_q;
    assign rd_data = rd_q;

    integer mi;
    initial begin
        for (mi = 0; mi < 512; mi = mi + 1) begin
            mem[mi] = 45'd0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_q <= 45'd0;
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
