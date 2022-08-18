`timescale 1ns / 1ps
module Cache_MEM_L2_tb();
parameter block_size = 128;
parameter tag_size = 7;
parameter idx_size = 8;
parameter word_size = 2;
parameter offset_size = 2;

reg clk_i;
reg rst_i;
reg read_p1_i;                // disaridan gelen read sinyali port 1 
reg read_p2_i;                // disaridan gelen read sinyali port 2 
reg write_p1_i;               // disaridan gelen write sinyali port 1 
reg write_p2_i;               // disaridan gelen write sinyali port 2 
reg [block_size-1:0] data_block_p1_i;// 128 bitlik gelen input data port 1 
reg [block_size-1:0] data_block_p2_i;// 128 bitlik gelen input data port 2 
reg [3:0] word_enable_p1_i;   // disaridan gelen write icin word enable sinyali port 1 
reg [3:0] word_enable_p2_i;   // disaridan gelen write icin word enable sinyali port 2 
wire [tag_size+idx_size+word_size+offset_size-1:0] addr_p1_i;         
wire [tag_size+idx_size+word_size+offset_size-1:0] addr_p2_i;      
wire [block_size-1:0] data_block_p1_o; // data out read port 1 (data cache & main memory write)
wire [block_size-1:0] data_block_p2_o; // data out read port 2 (instr cache write)
wire hit_p1_o; // read-port 1 hit
wire hit_p2_o;  // read-port 2 hit

reg cpu_clk;
reg [tag_size-1:0] tag_p1;
reg [idx_size-1:0] idx_p1;
reg [word_size-1:0] word_p1;
reg [offset_size-1:0] offset_p1;
assign addr_p1_i = {tag_p1, idx_p1, word_p1, offset_p1};

reg [tag_size-1:0] tag_p2;
reg [idx_size-1:0] idx_p2;
reg [word_size-1:0] word_p2;
reg [offset_size-1:0] offset_p2;
assign addr_p2_i = {tag_p2, idx_p2, word_p2, offset_p2};


    Cache_MEM_L2 Cache_MEM_L2_inst( 
    .clk_i(clk_i),
    .rst_i(rst_i),
    .read_p1_i(read_p1_i),                // disaridan gelen read sinyali port 1 
    .read_p2_i(read_p2_i),                // disaridan gelen read sinyali port 2 
    .write_p1_i(write_p1_i),               // disaridan gelen write sinyali port 1 
    .write_p2_i(write_p2_i),               // disaridan gelen write sinyali port 2 
    .data_block_p1_i(data_block_p1_i), // 128 bitlik gelen input data port 1 
    .data_block_p2_i(data_block_p2_i), // 128 bitlik gelen input data port 2 
    .byte_enable_p1_i(16'hFFFF),   // disaridan gelen write icin word enable sinyali port 1 
    .byte_enable_p2_i(16'hFFFF),   // disaridan gelen write icin word enable sinyali port 2 
    .addr_p1_i(addr_p1_i),         // 32 bitlik address read port 1 
    .addr_p2_i(addr_p2_i),         // 32 bitlik address read port 2 
    .data_block_p1_o(data_block_p1_o), // data out read port 1 (data cache & main memory write)
    .data_block_p2_o(data_block_p2_o), // data out read port 2 (instr cache write)
    .hit_p1_o(hit_p1_o),        // read-port 1 hit
    .hit_p2_o(hit_p2_o)         // read-port 2 hit
    );

    always #5 clk_i = ~clk_i;
    always #20 cpu_clk =~cpu_clk;
    initial begin
        cpu_clk = 0;
        clk_i = 0;
        reset_mem;
        write_port1_port2(128'd15,8'd1,7'd5,2'd0,2'd0,4'b1111,128'd20,8'd1,7'd6,2'd0,2'd0,4'b1111);
        read_port1(8'd1,7'd5,2'd0,2'd0); // read 15 port 1
        read_port1(8'd1,7'd6,2'd0,2'd0); // read 20 port 1
        read_port2(8'd1,7'd5,2'd0,2'd0); // read 15 port 2
        read_port2(8'd1,7'd6,2'd0,2'd0); // read 20 port 2
        read_port1_port2(8'd1,7'd5,2'd0,2'd0,8'd1,7'd6,2'd0,2'd0); // read 15 port 1 - read 20 port 2
        
        write_port1_port2(128'd10,8'd1,7'd9,2'd0,2'd0,4'b1111,128'd30,8'd6,7'd6,2'd0,2'd0,4'b1111); 
        read_port1_port2(8'd1,7'd9,2'd0,2'd0,8'd1,7'd6,2'd0,2'd0); // read 10 port 1 - read 20 port 2
        read_port1(8'd6,7'd6,2'd0,2'd0); // read 30 port 1
        read_port2(8'd1,7'd6,2'd0,2'd0); // read 20 port 2 
        write_port2(128'd40,8'd0,7'd5,2'd0,2'd0,4'b1111); 
        read_port1_port2(8'd0,7'd5,2'd0,2'd0,8'd6,7'd6,2'd0,2'd0); // read 40 port 1 - read 30 port 2
        read_port1(8'd0,7'd5,2'd0,2'd0); // read 40 port 1
        write_port2(128'd10,8'd0,7'd1,2'd0,2'd0,4'b1111);
        read_port1_port2(8'd0,7'd1,2'd0,2'd0,8'd0,7'd5,2'd0,2'd0); // read 10 port 1 - read 40 port 2
        read_port1(8'd0,7'd5,2'd0,2'd0); // read 40 port 1
        read_port1(8'd0,7'd1,2'd0,2'd0); // read 10 port 1
        read_port2(8'd0,7'd1,2'd0,2'd0); // read 10 port 2
        read_port2(8'd0,7'd5,2'd0,2'd0); // read 40 port 2
        $finish;
    end


    task reset_mem();
    begin
        rst_i = 1'b1;
        #100;
        rst_i = 1'b0;
        #100;
    end
    endtask

    task read_port1_port2(
        input [idx_size-1:0] idx_i,
        input [tag_size-1:0] tag_i,
        input [word_size-1:0] word_i,
        input [offset_size-1:0] offset_i,
        input [idx_size-1:0] idx_i2,
        input [tag_size-1:0] tag_i2,
        input [word_size-1:0] word_i2,
        input [offset_size-1:0] offset_i2
    );
    begin
        @(posedge cpu_clk);
        idx_p1 = idx_i;
        tag_p1 = tag_i;
        word_p1 = word_i;
        offset_p1 = offset_i;
        idx_p2 = idx_i2;
        tag_p2 = tag_i2;
        word_p2 = word_i2;
        offset_p2 = offset_i2;
        read_p1_i = 1'b1;
        read_p2_i = 1'b1;
        #5;
        @(posedge cpu_clk);
        read_p1_i = 1'b0;
        read_p2_i = 1'b0;
    end
    endtask
    task write_port1_port2(
        input [block_size-1:0] data,
        input [idx_size-1:0] idx_i,
        input [tag_size-1:0] tag_i,
        input [word_size-1:0] word_i,
        input [offset_size-1:0] offset_i,
        input [3:0] word_enable,
        input [block_size-1:0] data2,
        input [idx_size-1:0] idx_i2,
        input [tag_size-1:0] tag_i2,
        input [word_size-1:0] word_i2,
        input [offset_size-1:0] offset_i2,
        input [3:0] word_enable2
    );
    begin
        @(posedge cpu_clk);
        idx_p1 = idx_i;
        tag_p1 = tag_i;
        word_p1 = word_i;
        offset_p1 = offset_i;
        word_enable_p1_i = word_enable;
        data_block_p1_i = data;
        idx_p2 = idx_i2;
        tag_p2 = tag_i2;
        word_p2 = word_i2;
        offset_p2 = offset_i2;
        word_enable_p2_i = word_enable2;
        data_block_p2_i = data2;
        write_p1_i = 1'b1;
        write_p2_i = 1'b1;
        #5;
        @(posedge cpu_clk);
        write_p1_i = 1'b0;
        write_p2_i = 1'b0;
    end
    endtask
    task write_port1(
        input [block_size-1:0] data,
        input [idx_size-1:0] idx_i,
        input [tag_size-1:0] tag_i,
        input [word_size-1:0] word_i,
        input [offset_size-1:0] offset_i,
        input [3:0] word_enable
    );
    begin
        @(posedge cpu_clk);
        idx_p1 = idx_i;
        tag_p1 = tag_i;
        word_p1 = word_i;
        offset_p1 = offset_i;
        word_enable_p1_i = word_enable;
        data_block_p1_i = data;
        write_p1_i = 1'b1;
        #5;
        @(posedge cpu_clk);
        write_p1_i = 1'b0;
    end
    endtask

    task write_port2(
        input [block_size-1:0] data,
        input [idx_size-1:0] idx_i,
        input [tag_size-1:0] tag_i,
        input [word_size-1:0] word_i,
        input [offset_size-1:0] offset_i,
        input [3:0] word_enable
    );
    begin
        @(posedge cpu_clk);
        idx_p2 = idx_i;
        tag_p2 = tag_i;
        word_p2 = word_i;
        offset_p2 = offset_i;
        word_enable_p2_i = word_enable;
        data_block_p2_i = data;
        write_p2_i = 1'b1;
        #5;
        @(posedge cpu_clk);
        write_p2_i = 1'b0;
    end
    endtask

    task read_port1(
        input [idx_size-1:0] idx_i,
        input [tag_size-1:0] tag_i,
        input [word_size-1:0] word_i,
        input [offset_size-1:0] offset_i
    );
    begin
        @(posedge cpu_clk);
        idx_p1 = idx_i;
        tag_p1 = tag_i;
        word_p1 = word_i;
        offset_p1 = offset_i;
        read_p1_i = 1'b1;
        #5;
        @(posedge cpu_clk);
        read_p1_i = 1'b0;
    end
    endtask

    task read_port2(
        input [idx_size-1:0] idx_i,
        input [tag_size-1:0] tag_i,
        input [word_size-1:0] word_i,
        input [offset_size-1:0] offset_i
    );
    begin
        @(posedge cpu_clk);
        idx_p2 = idx_i;
        tag_p2 = tag_i;
        word_p2 = word_i;
        offset_p2 = offset_i;
        read_p2_i = 1'b1;
        #5;
        @(posedge cpu_clk);
        read_p2_i = 1'b0;
    end
    endtask
endmodule
