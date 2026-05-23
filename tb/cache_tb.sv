`timescale 1ns / 1ps

module cache_tb();
    localparam ADDR_WIDTH = 19;
    localparam DATA_WIDTH = 64;
    localparam RAM_ADDR_WIDTH = 17;

    reg clk;
    reg mem_clk;
    reg rst;

    reg instr_req_valid;
    reg data_req_read;
    reg data_req_write;
    reg [ADDR_WIDTH-1:0] instr_req_addr;
    reg [ADDR_WIDTH-1:0] data_req_addr;
    reg [DATA_WIDTH-1:0] data_req_wdata;
    reg [(DATA_WIDTH/8)-1:0] data_req_wstrb;

    wire [31:0] instr_resp_data;
    wire [DATA_WIDTH-1:0] data_resp_rdata;
    wire [31:0] mem_rdata;
    wire [31:0] mem_wdata;
    wire [31:0] mem_read_addr;
    wire [31:0] mem_write_addr;
    wire mem_read;
    wire [3:0] mem_wstrb;
    wire mem_write;
    wire busy;

    cache_memory_model #(
        .ADDR_WIDTH(RAM_ADDR_WIDTH),
        .DATA_WIDTH(32)
    ) main_memory (
        .clk(mem_clk),
        .rst_ni(~rst),
        .write_addr(mem_write_addr[18:2]),
        .read_addr(mem_read_addr[18:2]),
        .write_data(mem_wdata),
        .write_strobe(mem_wstrb),
        .read_enable(mem_read),
        .read_data(mem_rdata)
    );

    cache dut (
        .clk(clk),
        .mem_clk(mem_clk),
        .rst(rst),
        .instr_req_valid(instr_req_valid),
        .instr_req_addr(instr_req_addr),
        .instr_resp_data(instr_resp_data),
        .data_req_read(data_req_read),
        .data_req_write(data_req_write),
        .data_req_addr(data_req_addr),
        .data_req_wdata(data_req_wdata),
        .data_req_wstrb(data_req_wstrb),
        .data_resp_rdata(data_resp_rdata),
        .mem_rdata(mem_rdata),
        .mem_wdata(mem_wdata),
        .mem_read_addr(mem_read_addr),
        .mem_write_addr(mem_write_addr),
        .mem_read(mem_read),
        .mem_wstrb(mem_wstrb),
        .mem_write(mem_write),
        .busy(busy)
    );

    always #6.25 clk = ~clk;
    always #6.25 mem_clk = ~mem_clk;

    initial begin
        clk = 1'b1;
        mem_clk = 1'b1;
        rst = 1'b1;
        instr_req_valid = 1'b0;
        data_req_read = 1'b0;
        data_req_write = 1'b0;
        instr_req_addr = {ADDR_WIDTH{1'b0}};
        data_req_addr = {ADDR_WIDTH{1'b0}};
        data_req_wdata = {DATA_WIDTH{1'b0}};
        data_req_wstrb = {(DATA_WIDTH/8){1'b0}};

        #1000;
        rst = 1'b0;
        #1500;

        read_data(19'h00014);
        read_data(19'h00018);
        write_data(19'h00000, 64'h0000_0000_0000_0064, 8'b0000_0001);
        read_data(19'h00000);
        read_instr(19'h00000);
        read_instr(19'h00008);
        read_data_instr(19'h00014, 19'h00020);

        #500;
        $finish;
    end

    task read_instr(input [ADDR_WIDTH-1:0] addr);
    begin
        #4;
        instr_req_addr = addr;
        instr_req_valid = 1'b1;
        repeat(2) @(posedge clk);
        instr_req_valid = 1'b0;
        @(posedge clk);
        while (busy) begin
            @(posedge clk);
        end
    end
    endtask

    task read_data(input [ADDR_WIDTH-1:0] addr);
    begin
        #4;
        data_req_addr = addr;
        data_req_read = 1'b1;
        repeat(2) @(posedge clk);
        data_req_read = 1'b0;
        @(posedge clk);
        while (busy) begin
            @(posedge clk);
        end
    end
    endtask

    task write_data(
        input [ADDR_WIDTH-1:0] addr,
        input [DATA_WIDTH-1:0] data,
        input [(DATA_WIDTH/8)-1:0] strobe
    );
    begin
        #4;
        data_req_addr = addr;
        data_req_wdata = data;
        data_req_wstrb = strobe;
        data_req_write = 1'b1;
        repeat(2) @(posedge clk);
        data_req_write = 1'b0;
        @(posedge clk);
        while (busy | mem_write) begin
            @(posedge clk);
        end
        data_req_wstrb = {(DATA_WIDTH/8){1'b0}};
    end
    endtask

    task read_data_instr(
        input [ADDR_WIDTH-1:0] data_addr,
        input [ADDR_WIDTH-1:0] instr_addr
    );
    begin
        #4;
        data_req_addr = data_addr;
        instr_req_addr = instr_addr;
        data_req_read = 1'b1;
        instr_req_valid = 1'b1;
        repeat(2) @(posedge clk);
        data_req_read = 1'b0;
        instr_req_valid = 1'b0;
        while (busy) begin
            @(posedge clk);
        end
    end
    endtask
endmodule
