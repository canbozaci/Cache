// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

`timescale 1ns / 1ps

module cache_block_tb;
    localparam LINE_WIDTH = 128;
    localparam DATA_WIDTH = 64;
    localparam MEM_DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 19;
    localparam INDEX_WIDTH = 2;
    localparam SET_COUNT = 4;
    localparam TAG_WIDTH = 5;
    localparam LINE_BYTE_COUNT = LINE_WIDTH / 8;
    localparam L2_ADDR_WIDTH = ADDR_WIDTH - 4;

    reg clk;
    reg rst;
    integer error_count;
    integer controller_ram_read_count;

    reg l1_array_we;
    reg [LINE_BYTE_COUNT-1:0] l1_array_byte_enable;
    reg [INDEX_WIDTH-1:0] l1_array_addr;
    reg [LINE_WIDTH-1:0] l1_array_write_data;
    wire [LINE_WIDTH-1:0] l1_array_read_data;

    reg tag_we;
    reg tag_invalidate;
    reg [INDEX_WIDTH-1:0] tag_addr;
    reg [INDEX_WIDTH-1:0] tag_invalidate_addr;
    reg [TAG_WIDTH-1:0] tag_invalidate_tag;
    reg [TAG_WIDTH:0] tag_write_data;
    wire [TAG_WIDTH:0] tag_read_data;

    reg l2_we_p1;
    reg l2_we_p2;
    reg [LINE_BYTE_COUNT-1:0] l2_be_p1;
    reg [LINE_BYTE_COUNT-1:0] l2_be_p2;
    reg [INDEX_WIDTH-1:0] l2_addr_p1;
    reg [INDEX_WIDTH-1:0] l2_addr_p2;
    reg [LINE_WIDTH-1:0] l2_wdata_p1;
    reg [LINE_WIDTH-1:0] l2_wdata_p2;
    wire [LINE_WIDTH-1:0] l2_rdata_p1;
    wire [LINE_WIDTH-1:0] l2_rdata_p2;

    reg [LINE_WIDTH-1:0] load_block;
    reg [1:0] load_offset;
    reg [1:0] load_word;
    wire [DATA_WIDTH-1:0] load_data;

    reg store_write_l2;
    reg [LINE_WIDTH-1:0] store_data_l2;
    reg [DATA_WIDTH-1:0] store_write_data;
    reg [(DATA_WIDTH/8)-1:0] store_write_strobe;
    reg [1:0] store_offset;
    reg [1:0] store_word;
    wire [LINE_BYTE_COUNT-1:0] store_byte_enable;
    wire [LINE_WIDTH-1:0] store_data_in_write;

    reg l1_rep_read;
    reg l1_rep_write;
    reg [INDEX_WIDTH-1:0] l1_rep_idx;
    reg l1_rep_hit_s1;
    reg l1_rep_hit_s2;
    reg l1_rep_write_l2;
    reg l1_rep_write_through;
    reg l1_rep_valid_s1;
    reg l1_rep_valid_s2;
    wire l1_rep_we_s1;
    wire l1_rep_we_s2;

    reg l2_rep_read_p1;
    reg l2_rep_read_p2;
    reg l2_rep_write_p1;
    reg l2_rep_write_p2;
    reg [INDEX_WIDTH-1:0] l2_rep_idx_p1;
    reg [INDEX_WIDTH-1:0] l2_rep_idx_p2;
    reg l2_rep_hit_s1_p1;
    reg l2_rep_hit_s2_p1;
    reg l2_rep_hit_s1_p2;
    reg l2_rep_hit_s2_p2;
    reg l2_rep_valid_s1_p1;
    reg l2_rep_valid_s2_p1;
    reg l2_rep_valid_s1_p2;
    reg l2_rep_valid_s2_p2;
    reg l2_rep_ram_write_start;
    reg l2_rep_write_through;
    wire l2_rep_we_s1_p1;
    wire l2_rep_we_s2_p1;
    wire l2_rep_we_s1_p2;
    wire l2_rep_we_s2_p2;

    reg ctrl_ram_req_ready;
    reg ctrl_ram_rsp_valid;
    reg [LINE_WIDTH-1:0] ctrl_l2_data_block_p1;
    reg [ADDR_WIDTH-1:0] ctrl_l1_data_addr;
    reg [ADDR_WIDTH-1:0] ctrl_l1_instr_addr;
    reg ctrl_l2_p1_hit;
    reg ctrl_l2_p2_hit;
    reg ctrl_l1_data_hit;
    reg ctrl_l1_instr_hit;
    reg ctrl_l1_miss_next;
    reg ctrl_instr_request;
    reg ctrl_data_read_request;
    reg ctrl_data_write_request;
    reg [(DATA_WIDTH/8)-1:0] ctrl_data_write_strobe;
    wire ctrl_write_l2;
    wire ctrl_l1_instr_write;
    wire ctrl_l2_read_p1;
    wire ctrl_l2_read_p2;
    wire ctrl_l2_write_p1;
    wire ctrl_l2_write_p2;
    wire [LINE_BYTE_COUNT-1:0] ctrl_l2_byte_enable_p1;
    wire [LINE_BYTE_COUNT-1:0] ctrl_l2_byte_enable_p2;
    wire [L2_ADDR_WIDTH-1:0] ctrl_l2_p2_addr;
    wire [MEM_DATA_WIDTH-1:0] ctrl_ram_data;
    wire [31:0] ctrl_ram_read_addr;
    wire [31:0] ctrl_ram_write_addr;
    wire [7:0] ctrl_ram_read_beat_index;
    wire [7:0] ctrl_ram_write_beat_index;
    wire [7:0] ctrl_ram_write_burst_len;
    wire ctrl_ram_read;
    wire ctrl_miss;
    wire ctrl_ram_write_start;
    wire ctrl_write_next;
    wire [(MEM_DATA_WIDTH/8)-1:0] ctrl_wr_strb;
    wire ctrl_data_cache_read;
    wire ctrl_instr_cache_read;
    wire ctrl_memory_write;
    wire ctrl_write_through;
    wire ctrl_instr_write_start;

    cache_l1_memory_array #(
        .DATA_WIDTH(LINE_WIDTH),
        .ADDR_WIDTH(INDEX_WIDTH),
        .BYTE_COUNT(LINE_BYTE_COUNT)
    ) l1_array_dut (
        .clk(clk),
        .we(l1_array_we),
        .byte_enable(l1_array_byte_enable),
        .addr(l1_array_addr),
        .write_data(l1_array_write_data),
        .read_data(l1_array_read_data)
    );

    cache_l1_memory_tag_valid_array #(
        .DATA_WIDTH(TAG_WIDTH + 1),
        .ADDR_WIDTH(INDEX_WIDTH),
        .RAM_DEPTH(SET_COUNT)
    ) tag_array_dut (
        .clk(clk),
        .rst(rst),
        .we(tag_we),
        .invalidate(tag_invalidate),
        .addr(tag_addr),
        .invalidate_addr(tag_invalidate_addr),
        .invalidate_tag(tag_invalidate_tag),
        .write_data(tag_write_data),
        .read_data(tag_read_data)
    );

    cache_l2_memory_array #(
        .NUM_COL(LINE_BYTE_COUNT),
        .COL_WIDTH(8),
        .ADDR_WIDTH(INDEX_WIDTH),
        .DATA_WIDTH(LINE_WIDTH)
    ) l2_array_dut (
        .clk(clk),
        .we_p1(l2_we_p1),
        .we_p2(l2_we_p2),
        .byte_enable_p1(l2_be_p1),
        .byte_enable_p2(l2_be_p2),
        .addr_p1(l2_addr_p1),
        .addr_p2(l2_addr_p2),
        .write_data_p1(l2_wdata_p1),
        .write_data_p2(l2_wdata_p2),
        .read_data_p1(l2_rdata_p1),
        .read_data_p2(l2_rdata_p2)
    );

    cache_l1_memory_load #(
        .BYTE_OFFSET_WIDTH(2),
        .WORD_OFFSET_WIDTH(2),
        .LINE_WIDTH(LINE_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) load_dut (
        .data_block(load_block),
        .offset(load_offset),
        .word(load_word),
        .data(load_data)
    );

    cache_l1_memory_store #(
        .BYTE_OFFSET_WIDTH(2),
        .WORD_OFFSET_WIDTH(2),
        .LINE_WIDTH(LINE_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) store_dut (
        .write_L2(store_write_l2),
        .data_L2(store_data_l2),
        .write_data(store_write_data),
        .write_strobe(store_write_strobe),
        .offset(store_offset),
        .word(store_word),
        .byte_enable(store_byte_enable),
        .data_in_write(store_data_in_write)
    );

    cache_l1_replacement #(
        .INDEX_WIDTH(INDEX_WIDTH),
        .SET_COUNT(SET_COUNT)
    ) l1_replacement_dut (
        .clk(clk),
        .rst(rst),
        .read(l1_rep_read),
        .write(l1_rep_write),
        .idx(l1_rep_idx),
        .hit_s1(l1_rep_hit_s1),
        .hit_s2(l1_rep_hit_s2),
        .write_L2(l1_rep_write_l2),
        .write_through(l1_rep_write_through),
        .valid_out_s1(l1_rep_valid_s1),
        .valid_out_s2(l1_rep_valid_s2),
        .we_s1(l1_rep_we_s1),
        .we_s2(l1_rep_we_s2)
    );

    cache_l2_replacement #(
        .INDEX_WIDTH(INDEX_WIDTH),
        .SET_COUNT(SET_COUNT)
    ) l2_replacement_dut (
        .clk(clk),
        .rst(rst),
        .read_p1(l2_rep_read_p1),
        .read_p2(l2_rep_read_p2),
        .write_p1(l2_rep_write_p1),
        .write_p2(l2_rep_write_p2),
        .idx_p1(l2_rep_idx_p1),
        .idx_p2(l2_rep_idx_p2),
        .hit_s1_p1(l2_rep_hit_s1_p1),
        .hit_s2_p1(l2_rep_hit_s2_p1),
        .hit_s1_p2(l2_rep_hit_s1_p2),
        .hit_s2_p2(l2_rep_hit_s2_p2),
        .valid_out_s1_p1(l2_rep_valid_s1_p1),
        .valid_out_s2_p1(l2_rep_valid_s2_p1),
        .valid_out_s1_p2(l2_rep_valid_s1_p2),
        .valid_out_s2_p2(l2_rep_valid_s2_p2),
        .ram_write_start(l2_rep_ram_write_start),
        .write_through(l2_rep_write_through),
        .we_s1_p1(l2_rep_we_s1_p1),
        .we_s2_p1(l2_rep_we_s2_p1),
        .we_s1_p2(l2_rep_we_s1_p2),
        .we_s2_p2(l2_rep_we_s2_p2)
    );

    cache_controller #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .MEM_DATA_WIDTH(MEM_DATA_WIDTH),
        .LINE_WIDTH(LINE_WIDTH),
        .LINE_BYTE_COUNT(LINE_BYTE_COUNT),
        .DATA_BYTE_COUNT(DATA_WIDTH / 8),
        .MEM_BYTE_COUNT(MEM_DATA_WIDTH / 8),
        .LINE_OFFSET_WIDTH(4),
        .L2_ADDR_WIDTH(L2_ADDR_WIDTH)
    ) controller_dut (
        .clk(clk),
        .rst(rst),
        .ram_req_ready(ctrl_ram_req_ready),
        .ram_rsp_valid(ctrl_ram_rsp_valid),
        .l2_data_block_p1(ctrl_l2_data_block_p1),
        .L1_data_addr(ctrl_l1_data_addr),
        .L1_instr_addr(ctrl_l1_instr_addr),
        .L2_p1_hit(ctrl_l2_p1_hit),
        .L2_p2_hit(ctrl_l2_p2_hit),
        .L1_data_hit(ctrl_l1_data_hit),
        .L1_instr_hit(ctrl_l1_instr_hit),
        .L1_miss_next(ctrl_l1_miss_next),
        .instr_request(ctrl_instr_request),
        .data_read_request(ctrl_data_read_request),
        .data_write_request(ctrl_data_write_request),
        .data_write_strobe(ctrl_data_write_strobe),
        .write_L2(ctrl_write_l2),
        .L1_instr_write(ctrl_l1_instr_write),
        .L2_read_p1(ctrl_l2_read_p1),
        .L2_read_p2(ctrl_l2_read_p2),
        .L2_write_p1(ctrl_l2_write_p1),
        .L2_write_p2(ctrl_l2_write_p2),
        .L2_byte_enable_p1(ctrl_l2_byte_enable_p1),
        .L2_byte_enable_p2(ctrl_l2_byte_enable_p2),
        .L2_p2_addr(ctrl_l2_p2_addr),
        .ram_data(ctrl_ram_data),
        .ram_read_addr(ctrl_ram_read_addr),
        .ram_write_addr(ctrl_ram_write_addr),
        .ram_read_beat_index(ctrl_ram_read_beat_index),
        .ram_write_beat_index(ctrl_ram_write_beat_index),
        .ram_write_burst_len(ctrl_ram_write_burst_len),
        .ram_read(ctrl_ram_read),
        .miss(ctrl_miss),
        .ram_write_start(ctrl_ram_write_start),
        .write_next(ctrl_write_next),
        .wr_strb(ctrl_wr_strb),
        .data_cache_read(ctrl_data_cache_read),
        .instr_cache_read(ctrl_instr_cache_read),
        .memory_write(ctrl_memory_write),
        .write_through(ctrl_write_through),
        .instr_write_start(ctrl_instr_write_start)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        error_count = 0;
        initialize_inputs();
        pulse_reset();
        test_l1_array();
        test_l1_tag_valid_array();
        test_l2_array();
        test_load_store_helpers();
        test_replacement_helpers();
        test_controller_data_line_fill();
        if (error_count == 0) begin
            $display("CACHE BLOCK TEST PASS");
            $finish;
        end
        $display("CACHE BLOCK TEST FAIL: %0d mismatches", error_count);
        $fatal(1);
    end

    task initialize_inputs;
    begin
        rst = 1'b1;
        l1_array_we = 1'b0;
        l1_array_byte_enable = {LINE_BYTE_COUNT{1'b0}};
        l1_array_addr = {INDEX_WIDTH{1'b0}};
        l1_array_write_data = {LINE_WIDTH{1'b0}};
        tag_we = 1'b0;
        tag_invalidate = 1'b0;
        tag_addr = {INDEX_WIDTH{1'b0}};
        tag_invalidate_addr = {INDEX_WIDTH{1'b0}};
        tag_invalidate_tag = {TAG_WIDTH{1'b0}};
        tag_write_data = {(TAG_WIDTH+1){1'b0}};
        l2_we_p1 = 1'b0;
        l2_we_p2 = 1'b0;
        l2_be_p1 = {LINE_BYTE_COUNT{1'b0}};
        l2_be_p2 = {LINE_BYTE_COUNT{1'b0}};
        l2_addr_p1 = {INDEX_WIDTH{1'b0}};
        l2_addr_p2 = {INDEX_WIDTH{1'b0}};
        l2_wdata_p1 = {LINE_WIDTH{1'b0}};
        l2_wdata_p2 = {LINE_WIDTH{1'b0}};
        load_block = 128'h00112233445566778899aabbccddeeff;
        load_offset = 2'b0;
        load_word = 2'b0;
        store_write_l2 = 1'b0;
        store_data_l2 = {LINE_WIDTH{1'b0}};
        store_write_data = {DATA_WIDTH{1'b0}};
        store_write_strobe = {(DATA_WIDTH/8){1'b0}};
        store_offset = 2'b0;
        store_word = 2'b0;
        l1_rep_read = 1'b0;
        l1_rep_write = 1'b0;
        l1_rep_idx = {INDEX_WIDTH{1'b0}};
        l1_rep_hit_s1 = 1'b0;
        l1_rep_hit_s2 = 1'b0;
        l1_rep_write_l2 = 1'b0;
        l1_rep_write_through = 1'b0;
        l1_rep_valid_s1 = 1'b0;
        l1_rep_valid_s2 = 1'b0;
        l2_rep_read_p1 = 1'b0;
        l2_rep_read_p2 = 1'b0;
        l2_rep_write_p1 = 1'b0;
        l2_rep_write_p2 = 1'b0;
        l2_rep_idx_p1 = {INDEX_WIDTH{1'b0}};
        l2_rep_idx_p2 = {INDEX_WIDTH{1'b0}};
        l2_rep_hit_s1_p1 = 1'b0;
        l2_rep_hit_s2_p1 = 1'b0;
        l2_rep_hit_s1_p2 = 1'b0;
        l2_rep_hit_s2_p2 = 1'b0;
        l2_rep_valid_s1_p1 = 1'b0;
        l2_rep_valid_s2_p1 = 1'b0;
        l2_rep_valid_s1_p2 = 1'b0;
        l2_rep_valid_s2_p2 = 1'b0;
        l2_rep_ram_write_start = 1'b0;
        l2_rep_write_through = 1'b0;
        ctrl_ram_req_ready = 1'b1;
        ctrl_ram_rsp_valid = 1'b0;
        ctrl_l2_data_block_p1 = {LINE_WIDTH{1'b0}};
        ctrl_l1_data_addr = {ADDR_WIDTH{1'b0}};
        ctrl_l1_instr_addr = {ADDR_WIDTH{1'b0}};
        ctrl_l2_p1_hit = 1'b0;
        ctrl_l2_p2_hit = 1'b0;
        ctrl_l1_data_hit = 1'b0;
        ctrl_l1_instr_hit = 1'b0;
        ctrl_l1_miss_next = 1'b0;
        ctrl_instr_request = 1'b0;
        ctrl_data_read_request = 1'b0;
        ctrl_data_write_request = 1'b0;
        ctrl_data_write_strobe = {(DATA_WIDTH/8){1'b0}};
        controller_ram_read_count = 0;
    end
    endtask

    task pulse_reset;
    begin
        rst = 1'b1;
        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);
    end
    endtask

    task expect_bit;
        input actual;
        input expected;
        input [1023:0] label;
    begin
        if (actual !== expected) begin
            $display("BLOCK BIT MISMATCH: %0s expected=%0b actual=%0b", label, expected, actual);
            error_count = error_count + 1;
        end
    end
    endtask

    task expect_line;
        input [LINE_WIDTH-1:0] actual;
        input [LINE_WIDTH-1:0] expected;
        input [1023:0] label;
    begin
        if (actual !== expected) begin
            $display("BLOCK LINE MISMATCH: %0s expected=%032h actual=%032h", label, expected, actual);
            error_count = error_count + 1;
        end
    end
    endtask

    task test_l1_array;
    begin
        @(negedge clk);
        l1_array_addr = 2'd1;
        l1_array_write_data = {LINE_WIDTH{1'b0}};
        l1_array_byte_enable = 16'hffff;
        l1_array_we = 1'b1;
        @(negedge clk);
        l1_array_addr = 2'd1;
        l1_array_write_data = 128'hffff_eeee_dddd_cccc_bbbb_aaaa_9999_8888;
        l1_array_byte_enable = 16'h000f;
        l1_array_we = 1'b1;
        @(negedge clk);
        l1_array_we = 1'b0;
        l1_array_addr = 2'd1;
        @(posedge clk);
        @(negedge clk);
        expect_line(l1_array_read_data, 128'h0000_0000_0000_0000_0000_0000_9999_8888,
                    "l1 byte-enabled write");
    end
    endtask

    task test_l1_tag_valid_array;
    begin
        @(negedge clk);
        tag_addr = 2'd2;
        tag_write_data = {1'b1, 5'h15};
        tag_we = 1'b1;
        @(negedge clk);
        tag_we = 1'b0;
        tag_addr = 2'd2;
        @(posedge clk);
        @(negedge clk);
        if (tag_read_data !== {1'b1, 5'h15}) begin
            $display("BLOCK TAG MISMATCH: expected valid tag");
            error_count = error_count + 1;
        end
        tag_invalidate_addr = 2'd2;
        tag_invalidate_tag = 5'h15;
        tag_invalidate = 1'b1;
        @(negedge clk);
        tag_invalidate = 1'b0;
        tag_addr = 2'd2;
        @(posedge clk);
        @(negedge clk);
        expect_bit(tag_read_data[TAG_WIDTH], 1'b0, "tag invalidate clears valid");
    end
    endtask

    task test_l2_array;
    begin
        @(negedge clk);
        l2_addr_p1 = 2'd0;
        l2_addr_p2 = 2'd3;
        l2_wdata_p1 = {LINE_WIDTH{1'b0}};
        l2_wdata_p2 = {LINE_WIDTH{1'b0}};
        l2_be_p1 = 16'hffff;
        l2_be_p2 = 16'hffff;
        l2_we_p1 = 1'b1;
        l2_we_p2 = 1'b1;
        @(negedge clk);
        l2_addr_p1 = 2'd0;
        l2_addr_p2 = 2'd3;
        l2_wdata_p1 = 128'h1111_2222_3333_4444_5555_6666_7777_8888;
        l2_wdata_p2 = 128'haaaa_bbbb_cccc_dddd_eeee_ffff_0000_1234;
        l2_be_p1 = 16'hffff;
        l2_be_p2 = 16'h00ff;
        l2_we_p1 = 1'b1;
        l2_we_p2 = 1'b1;
        @(negedge clk);
        l2_we_p1 = 1'b0;
        l2_we_p2 = 1'b0;
        l2_addr_p1 = 2'd0;
        l2_addr_p2 = 2'd3;
        @(posedge clk);
        @(negedge clk);
        expect_line(l2_rdata_p1, 128'h1111_2222_3333_4444_5555_6666_7777_8888, "l2 port1 write/read");
        expect_line(l2_rdata_p2, 128'h0000_0000_0000_0000_eeee_ffff_0000_1234, "l2 port2 byte write/read");
    end
    endtask

    task test_load_store_helpers;
    begin
        load_word = 2'd1;
        load_offset = 2'd2;
        #1;
        if (load_data !== 64'h2233445566778899) begin
            $display("BLOCK LOAD MISMATCH: actual=%016h", load_data);
            error_count = error_count + 1;
        end
        store_write_data = 64'h0102_0304_0506_0708;
        store_write_strobe = 8'h3c;
        store_word = 2'd1;
        store_offset = 2'd1;
        #1;
        if (store_byte_enable !== 16'h0780) begin
            $display("BLOCK STORE MISMATCH: byte_enable expected=0780 actual=%04h", store_byte_enable);
            error_count = error_count + 1;
        end
        store_write_l2 = 1'b1;
        store_data_l2 = 128'h1234_5678_90ab_cdef_fedc_ba09_8765_4321;
        #1;
        expect_line(store_data_in_write, store_data_l2, "store fill block");
        if (store_byte_enable !== 16'hffff) begin
            $display("BLOCK STORE MISMATCH: fill byte_enable expected=ffff actual=%04h", store_byte_enable);
            error_count = error_count + 1;
        end
        store_write_l2 = 1'b0;
    end
    endtask

    task test_replacement_helpers;
    begin
        l1_rep_write = 1'b1;
        l1_rep_valid_s1 = 1'b0;
        l1_rep_valid_s2 = 1'b0;
        #1;
        expect_bit(l1_rep_we_s1, 1'b1, "l1 replacement empty writes way 0");
        expect_bit(l1_rep_we_s2, 1'b0, "l1 replacement empty does not write way 1");
        l1_rep_valid_s1 = 1'b1;
        #1;
        expect_bit(l1_rep_we_s2, 1'b1, "l1 replacement fills invalid way 1");
        l1_rep_valid_s2 = 1'b1;
        l1_rep_write = 1'b0;
        l1_rep_read = 1'b1;
        l1_rep_hit_s1 = 1'b1;
        @(posedge clk);
        @(negedge clk);
        l1_rep_read = 1'b0;
        l1_rep_hit_s1 = 1'b0;
        l1_rep_write = 1'b1;
        #1;
        expect_bit(l1_rep_we_s2, 1'b1, "l1 replacement evicts least recently used way 1");

        l2_rep_write_p1 = 1'b1;
        l2_rep_write_p2 = 1'b1;
        l2_rep_idx_p1 = 2'd1;
        l2_rep_idx_p2 = 2'd1;
        l2_rep_ram_write_start = 1'b1;
        #1;
        expect_bit(l2_rep_we_s1_p1, 1'b1, "l2 same-index p1 chooses way 0");
        expect_bit(l2_rep_we_s2_p1, 1'b0, "l2 same-index p1 not way 1");
        expect_bit(l2_rep_we_s1_p2, 1'b0, "l2 same-index p2 not way 0");
        expect_bit(l2_rep_we_s2_p2, 1'b1, "l2 same-index p2 chooses way 1");
        @(negedge clk);
        l2_rep_ram_write_start = 1'b0;
        l2_rep_write_p1 = 1'b0;
        l2_rep_write_p2 = 1'b0;
    end
    endtask

    task test_controller_data_line_fill;
        integer timeout_count;
    begin
        ctrl_l1_data_addr = 19'h00040;
        ctrl_data_read_request = 1'b1;
        timeout_count = 0;
        while ((controller_ram_read_count < 4) && (timeout_count < 200)) begin
            @(posedge clk);
            ctrl_ram_rsp_valid <= 1'b0;
            if (ctrl_ram_read && ctrl_ram_req_ready) begin
                if (ctrl_ram_read_beat_index !== controller_ram_read_count[7:0]) begin
                    $display("CONTROLLER MISMATCH: beat expected=%0d actual=%0d",
                             controller_ram_read_count, ctrl_ram_read_beat_index);
                    error_count = error_count + 1;
                end
                controller_ram_read_count = controller_ram_read_count + 1;
                ctrl_ram_rsp_valid <= 1'b1;
            end
            timeout_count = timeout_count + 1;
        end
        ctrl_data_read_request = 1'b0;
        ctrl_ram_rsp_valid = 1'b0;
        ctrl_l1_data_hit = 1'b1;
        repeat (8) @(posedge clk);
        ctrl_l1_data_hit = 1'b0;
        if (controller_ram_read_count != 4) begin
            $display("CONTROLLER MISMATCH: expected 4 line-fill reads actual=%0d", controller_ram_read_count);
            error_count = error_count + 1;
        end
    end
    endtask
endmodule
