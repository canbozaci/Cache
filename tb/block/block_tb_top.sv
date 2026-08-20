// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

`timescale 1ns / 1ps

module block_tb_top;
    import uvm_pkg::*;
    import cache_block_pkg::*;

    localparam int LINE_BYTE_COUNT = BLK_LINE_WIDTH / 8;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    cache_block_if #(
        .LINE_WIDTH(BLK_LINE_WIDTH),
        .DATA_WIDTH(BLK_DATA_WIDTH),
        .MEM_DATA_WIDTH(BLK_MEM_DATA_WIDTH),
        .ADDR_WIDTH(BLK_ADDR_WIDTH),
        .INDEX_WIDTH(BLK_INDEX_WIDTH),
        .TAG_WIDTH(BLK_TAG_WIDTH),
        .L2_ADDR_WIDTH(BLK_L2_ADDR_WIDTH)
    ) vif (.clk(clk));

    cache_l1_memory_array #(
        .DATA_WIDTH(BLK_LINE_WIDTH),
        .ADDR_WIDTH(BLK_INDEX_WIDTH),
        .BYTE_COUNT(LINE_BYTE_COUNT)
    ) l1_array_dut (
        .clk(clk),
        .we(vif.l1_array_we),
        .byte_enable(vif.l1_array_byte_enable),
        .addr(vif.l1_array_addr),
        .write_data(vif.l1_array_write_data),
        .read_data(vif.l1_array_read_data)
    );

    cache_l1_memory_tag_valid_array #(
        .DATA_WIDTH(BLK_TAG_WIDTH + 1),
        .ADDR_WIDTH(BLK_INDEX_WIDTH),
        .RAM_DEPTH(BLK_SET_COUNT)
    ) tag_array_dut (
        .clk(clk),
        .rst_n(vif.rst_n),
        .we(vif.tag_we),
        .invalidate(vif.tag_invalidate),
        .addr(vif.tag_addr),
        .invalidate_addr(vif.tag_invalidate_addr),
        .invalidate_tag(vif.tag_invalidate_tag),
        .write_data(vif.tag_write_data),
        .read_data(vif.tag_read_data)
    );

    cache_l2_memory_array #(
        .NUM_COL(LINE_BYTE_COUNT),
        .COL_WIDTH(8),
        .ADDR_WIDTH(BLK_INDEX_WIDTH),
        .DATA_WIDTH(BLK_LINE_WIDTH)
    ) l2_array_dut (
        .clk(clk),
        .we_p1(vif.l2_we_p1),
        .we_p2(vif.l2_we_p2),
        .byte_enable_p1(vif.l2_be_p1),
        .byte_enable_p2(vif.l2_be_p2),
        .addr_p1(vif.l2_addr_p1),
        .addr_p2(vif.l2_addr_p2),
        .write_data_p1(vif.l2_wdata_p1),
        .write_data_p2(vif.l2_wdata_p2),
        .read_data_p1(vif.l2_rdata_p1),
        .read_data_p2(vif.l2_rdata_p2)
    );

    cache_l1_memory_load #(
        .BYTE_OFFSET_WIDTH(2),
        .WORD_OFFSET_WIDTH(2),
        .LINE_WIDTH(BLK_LINE_WIDTH),
        .DATA_WIDTH(BLK_DATA_WIDTH)
    ) load_dut (
        .data_block(vif.load_block),
        .offset(vif.load_offset),
        .word(vif.load_word),
        .data(vif.load_data)
    );

    cache_l1_memory_store #(
        .BYTE_OFFSET_WIDTH(2),
        .WORD_OFFSET_WIDTH(2),
        .LINE_WIDTH(BLK_LINE_WIDTH),
        .DATA_WIDTH(BLK_DATA_WIDTH)
    ) store_dut (
        .write_L2(vif.store_write_l2),
        .data_L2(vif.store_data_l2),
        .write_data(vif.store_write_data),
        .write_strobe(vif.store_write_strobe),
        .offset(vif.store_offset),
        .word(vif.store_word),
        .byte_enable(vif.store_byte_enable),
        .data_in_write(vif.store_data_in_write)
    );

    cache_l1_replacement #(
        .INDEX_WIDTH(BLK_INDEX_WIDTH),
        .SET_COUNT(BLK_SET_COUNT)
    ) l1_replacement_dut (
        .clk(clk),
        .rst_n(vif.rst_n),
        .read(vif.l1_rep_read),
        .write(vif.l1_rep_write),
        .idx(vif.l1_rep_idx),
        .hit_s1(vif.l1_rep_hit_s1),
        .hit_s2(vif.l1_rep_hit_s2),
        .write_L2(vif.l1_rep_write_l2),
        .write_through(vif.l1_rep_write_through),
        .valid_out_s1(vif.l1_rep_valid_s1),
        .valid_out_s2(vif.l1_rep_valid_s2),
        .we_s1(vif.l1_rep_we_s1),
        .we_s2(vif.l1_rep_we_s2)
    );

    cache_l2_replacement #(
        .INDEX_WIDTH(BLK_INDEX_WIDTH),
        .SET_COUNT(BLK_SET_COUNT)
    ) l2_replacement_dut (
        .clk(clk),
        .rst_n(vif.rst_n),
        .read_p1(vif.l2_rep_read_p1),
        .read_p2(vif.l2_rep_read_p2),
        .write_p1(vif.l2_rep_write_p1),
        .write_p2(vif.l2_rep_write_p2),
        .idx_p1(vif.l2_rep_idx_p1),
        .idx_p2(vif.l2_rep_idx_p2),
        .hit_s1_p1(vif.l2_rep_hit_s1_p1),
        .hit_s2_p1(vif.l2_rep_hit_s2_p1),
        .hit_s1_p2(vif.l2_rep_hit_s1_p2),
        .hit_s2_p2(vif.l2_rep_hit_s2_p2),
        .valid_out_s1_p1(vif.l2_rep_valid_s1_p1),
        .valid_out_s2_p1(vif.l2_rep_valid_s2_p1),
        .valid_out_s1_p2(vif.l2_rep_valid_s1_p2),
        .valid_out_s2_p2(vif.l2_rep_valid_s2_p2),
        .ram_write_start(vif.l2_rep_ram_write_start),
        .write_through(vif.l2_rep_write_through),
        .we_s1_p1(vif.l2_rep_we_s1_p1),
        .we_s2_p1(vif.l2_rep_we_s2_p1),
        .we_s1_p2(vif.l2_rep_we_s1_p2),
        .we_s2_p2(vif.l2_rep_we_s2_p2)
    );

    cache_controller #(
        .ADDR_WIDTH(BLK_ADDR_WIDTH),
        .DATA_WIDTH(BLK_DATA_WIDTH),
        .MEM_DATA_WIDTH(BLK_MEM_DATA_WIDTH),
        .LINE_WIDTH(BLK_LINE_WIDTH),
        .LINE_BYTE_COUNT(LINE_BYTE_COUNT),
        .DATA_BYTE_COUNT(BLK_DATA_WIDTH / 8),
        .MEM_BYTE_COUNT(BLK_MEM_DATA_WIDTH / 8),
        .LINE_OFFSET_WIDTH(4),
        .L2_ADDR_WIDTH(BLK_L2_ADDR_WIDTH)
    ) controller_dut (
        .clk(clk),
        .rst_n(vif.rst_n),
        .ram_req_ready(vif.ctrl_ram_req_ready),
        .ram_rsp_valid(vif.ctrl_ram_rsp_valid),
        .l2_data_block_p1(vif.ctrl_l2_data_block_p1),
        .L1_data_addr(vif.ctrl_l1_data_addr),
        .L1_instr_addr(vif.ctrl_l1_instr_addr),
        .L2_p1_hit(vif.ctrl_l2_p1_hit),
        .L2_p2_hit(vif.ctrl_l2_p2_hit),
        .L1_data_hit(vif.ctrl_l1_data_hit),
        .L1_instr_hit(vif.ctrl_l1_instr_hit),
        .L1_miss_next(vif.ctrl_l1_miss_next),
        .instr_request(vif.ctrl_instr_request),
        .data_read_request(vif.ctrl_data_read_request),
        .data_write_request(vif.ctrl_data_write_request),
        .data_write_strobe(vif.ctrl_data_write_strobe),
        .write_L2(vif.ctrl_write_l2),
        .L1_instr_write(vif.ctrl_l1_instr_write),
        .L2_read_p1(vif.ctrl_l2_read_p1),
        .L2_read_p2(vif.ctrl_l2_read_p2),
        .L2_write_p1(vif.ctrl_l2_write_p1),
        .L2_write_p2(vif.ctrl_l2_write_p2),
        .L2_byte_enable_p1(vif.ctrl_l2_byte_enable_p1),
        .L2_byte_enable_p2(vif.ctrl_l2_byte_enable_p2),
        .L2_p2_addr(vif.ctrl_l2_p2_addr),
        .ram_data(vif.ctrl_ram_data),
        .ram_read_addr(vif.ctrl_ram_read_addr),
        .ram_write_addr(vif.ctrl_ram_write_addr),
        .ram_read_beat_index(vif.ctrl_ram_read_beat_index),
        .ram_write_beat_index(vif.ctrl_ram_write_beat_index),
        .ram_write_burst_len(vif.ctrl_ram_write_burst_len),
        .ram_read(vif.ctrl_ram_read),
        .miss(vif.ctrl_miss),
        .ram_write_start(vif.ctrl_ram_write_start),
        .write_next(vif.ctrl_write_next),
        .wr_strb(vif.ctrl_wr_strb),
        .data_cache_read(vif.ctrl_data_cache_read),
        .instr_cache_read(vif.ctrl_instr_cache_read),
        .memory_write(vif.ctrl_memory_write),
        .write_through(vif.ctrl_write_through),
        .instr_write_start(vif.ctrl_instr_write_start)
    );

    // Power-on reset and input idle state.
    initial begin
        vif.rst_n = 1'b0;
        vif.l1_array_we            = 1'b0;
        vif.l1_array_byte_enable   = '0;
        vif.l1_array_addr          = '0;
        vif.l1_array_write_data    = '0;
        vif.tag_we                 = 1'b0;
        vif.tag_invalidate         = 1'b0;
        vif.tag_addr               = '0;
        vif.tag_invalidate_addr    = '0;
        vif.tag_invalidate_tag     = '0;
        vif.tag_write_data         = '0;
        vif.l2_we_p1               = 1'b0;
        vif.l2_we_p2               = 1'b0;
        vif.l2_be_p1               = '0;
        vif.l2_be_p2               = '0;
        vif.l2_addr_p1             = '0;
        vif.l2_addr_p2             = '0;
        vif.l2_wdata_p1            = '0;
        vif.l2_wdata_p2            = '0;
        vif.load_block             = '0;
        vif.load_offset            = '0;
        vif.load_word              = '0;
        vif.store_write_l2         = 1'b0;
        vif.store_data_l2          = '0;
        vif.store_write_data       = '0;
        vif.store_write_strobe     = '0;
        vif.store_offset           = '0;
        vif.store_word             = '0;
        vif.l1_rep_read            = 1'b0;
        vif.l1_rep_write           = 1'b0;
        vif.l1_rep_idx             = '0;
        vif.l1_rep_hit_s1          = 1'b0;
        vif.l1_rep_hit_s2          = 1'b0;
        vif.l1_rep_write_l2        = 1'b0;
        vif.l1_rep_write_through   = 1'b0;
        vif.l1_rep_valid_s1        = 1'b0;
        vif.l1_rep_valid_s2        = 1'b0;
        vif.l2_rep_read_p1         = 1'b0;
        vif.l2_rep_read_p2         = 1'b0;
        vif.l2_rep_write_p1        = 1'b0;
        vif.l2_rep_write_p2        = 1'b0;
        vif.l2_rep_idx_p1          = '0;
        vif.l2_rep_idx_p2          = '0;
        vif.l2_rep_hit_s1_p1       = 1'b0;
        vif.l2_rep_hit_s2_p1       = 1'b0;
        vif.l2_rep_hit_s1_p2       = 1'b0;
        vif.l2_rep_hit_s2_p2       = 1'b0;
        vif.l2_rep_valid_s1_p1     = 1'b0;
        vif.l2_rep_valid_s2_p1     = 1'b0;
        vif.l2_rep_valid_s1_p2     = 1'b0;
        vif.l2_rep_valid_s2_p2     = 1'b0;
        vif.l2_rep_ram_write_start = 1'b0;
        vif.l2_rep_write_through   = 1'b0;
        vif.ctrl_ram_req_ready     = 1'b1;
        vif.ctrl_ram_rsp_valid     = 1'b0;
        vif.ctrl_l2_data_block_p1  = '0;
        vif.ctrl_l1_data_addr      = '0;
        vif.ctrl_l1_instr_addr     = '0;
        vif.ctrl_l2_p1_hit         = 1'b0;
        vif.ctrl_l2_p2_hit         = 1'b0;
        vif.ctrl_l1_data_hit       = 1'b0;
        vif.ctrl_l1_instr_hit      = 1'b0;
        vif.ctrl_l1_miss_next      = 1'b0;
        vif.ctrl_instr_request     = 1'b0;
        vif.ctrl_data_read_request = 1'b0;
        vif.ctrl_data_write_request = 1'b0;
        vif.ctrl_data_write_strobe = '0;

        repeat (4) @(posedge clk);
        vif.rst_n = 1'b1;
    end

    initial begin
        #1ms;
        `uvm_fatal("TIMEOUT", "block simulation exceeded 1ms watchdog")
    end

    initial begin
        uvm_config_db#(virtual cache_block_if)::set(null, "*", "vif", vif);
        run_test("cache_block_test");
    end

endmodule
