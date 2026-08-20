// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Pin bundle for the block-level DUTs.
//
// One interface covers all seven leaf modules rather than one interface each.
// They are independent, never exercised concurrently, and share a clock, so
// separate interfaces would multiply plumbing without separating anything real.
interface cache_block_if #(
    parameter int LINE_WIDTH      = 128,
    parameter int DATA_WIDTH      = 64,
    parameter int MEM_DATA_WIDTH  = 32,
    parameter int ADDR_WIDTH      = 19,
    parameter int INDEX_WIDTH     = 2,
    parameter int TAG_WIDTH       = 5,
    parameter int L2_ADDR_WIDTH   = 15
) (
    input logic clk
);

    localparam int LINE_BYTE_COUNT = LINE_WIDTH / 8;

    logic rst_n;

    // ---- cache_l1_memory_array -------------------------------------------
    logic                       l1_array_we;
    logic [LINE_BYTE_COUNT-1:0] l1_array_byte_enable;
    logic [INDEX_WIDTH-1:0]     l1_array_addr;
    logic [LINE_WIDTH-1:0]      l1_array_write_data;
    logic [LINE_WIDTH-1:0]      l1_array_read_data;

    // ---- cache_l1_memory_tag_valid_array ---------------------------------
    logic                       tag_we;
    logic                       tag_invalidate;
    logic [INDEX_WIDTH-1:0]     tag_addr;
    logic [INDEX_WIDTH-1:0]     tag_invalidate_addr;
    logic [TAG_WIDTH-1:0]       tag_invalidate_tag;
    logic [TAG_WIDTH:0]         tag_write_data;
    logic [TAG_WIDTH:0]         tag_read_data;

    // ---- cache_l2_memory_array -------------------------------------------
    logic                       l2_we_p1;
    logic                       l2_we_p2;
    logic [LINE_BYTE_COUNT-1:0] l2_be_p1;
    logic [LINE_BYTE_COUNT-1:0] l2_be_p2;
    logic [INDEX_WIDTH-1:0]     l2_addr_p1;
    logic [INDEX_WIDTH-1:0]     l2_addr_p2;
    logic [LINE_WIDTH-1:0]      l2_wdata_p1;
    logic [LINE_WIDTH-1:0]      l2_wdata_p2;
    logic [LINE_WIDTH-1:0]      l2_rdata_p1;
    logic [LINE_WIDTH-1:0]      l2_rdata_p2;

    // ---- cache_l1_memory_load --------------------------------------------
    logic [LINE_WIDTH-1:0]      load_block;
    logic [1:0]                 load_offset;
    logic [1:0]                 load_word;
    logic [DATA_WIDTH-1:0]      load_data;

    // ---- cache_l1_memory_store -------------------------------------------
    logic                       store_write_l2;
    logic [LINE_WIDTH-1:0]      store_data_l2;
    logic [DATA_WIDTH-1:0]      store_write_data;
    logic [(DATA_WIDTH/8)-1:0]  store_write_strobe;
    logic [1:0]                 store_offset;
    logic [1:0]                 store_word;
    logic [LINE_BYTE_COUNT-1:0] store_byte_enable;
    logic [LINE_WIDTH-1:0]      store_data_in_write;

    // ---- cache_l1_replacement --------------------------------------------
    logic                       l1_rep_read;
    logic                       l1_rep_write;
    logic [INDEX_WIDTH-1:0]     l1_rep_idx;
    logic                       l1_rep_hit_s1;
    logic                       l1_rep_hit_s2;
    logic                       l1_rep_write_l2;
    logic                       l1_rep_write_through;
    logic                       l1_rep_valid_s1;
    logic                       l1_rep_valid_s2;
    logic                       l1_rep_we_s1;
    logic                       l1_rep_we_s2;

    // ---- cache_l2_replacement --------------------------------------------
    logic                       l2_rep_read_p1;
    logic                       l2_rep_read_p2;
    logic                       l2_rep_write_p1;
    logic                       l2_rep_write_p2;
    logic [INDEX_WIDTH-1:0]     l2_rep_idx_p1;
    logic [INDEX_WIDTH-1:0]     l2_rep_idx_p2;
    logic                       l2_rep_hit_s1_p1;
    logic                       l2_rep_hit_s2_p1;
    logic                       l2_rep_hit_s1_p2;
    logic                       l2_rep_hit_s2_p2;
    logic                       l2_rep_valid_s1_p1;
    logic                       l2_rep_valid_s2_p1;
    logic                       l2_rep_valid_s1_p2;
    logic                       l2_rep_valid_s2_p2;
    logic                       l2_rep_ram_write_start;
    logic                       l2_rep_write_through;
    logic                       l2_rep_we_s1_p1;
    logic                       l2_rep_we_s2_p1;
    logic                       l2_rep_we_s1_p2;
    logic                       l2_rep_we_s2_p2;

    // ---- cache_controller (line-fill subflow) ----------------------------
    logic                       ctrl_ram_req_ready;
    logic                       ctrl_ram_rsp_valid;
    logic [LINE_WIDTH-1:0]      ctrl_l2_data_block_p1;
    logic [ADDR_WIDTH-1:0]      ctrl_l1_data_addr;
    logic [ADDR_WIDTH-1:0]      ctrl_l1_instr_addr;
    logic                       ctrl_l2_p1_hit;
    logic                       ctrl_l2_p2_hit;
    logic                       ctrl_l1_data_hit;
    logic                       ctrl_l1_instr_hit;
    logic                       ctrl_l1_miss_next;
    logic                       ctrl_instr_request;
    logic                       ctrl_data_read_request;
    logic                       ctrl_data_write_request;
    logic [(DATA_WIDTH/8)-1:0]  ctrl_data_write_strobe;
    logic                       ctrl_write_l2;
    logic                       ctrl_l1_instr_write;
    logic                       ctrl_l2_read_p1;
    logic                       ctrl_l2_read_p2;
    logic                       ctrl_l2_write_p1;
    logic                       ctrl_l2_write_p2;
    logic [LINE_BYTE_COUNT-1:0] ctrl_l2_byte_enable_p1;
    logic [LINE_BYTE_COUNT-1:0] ctrl_l2_byte_enable_p2;
    logic [L2_ADDR_WIDTH-1:0]   ctrl_l2_p2_addr;
    logic [MEM_DATA_WIDTH-1:0]  ctrl_ram_data;
    logic [31:0]                ctrl_ram_read_addr;
    logic [31:0]                ctrl_ram_write_addr;
    logic [7:0]                 ctrl_ram_read_beat_index;
    logic [7:0]                 ctrl_ram_write_beat_index;
    logic [7:0]                 ctrl_ram_write_burst_len;
    logic                       ctrl_ram_read;
    logic                       ctrl_miss;
    logic                       ctrl_ram_write_start;
    logic                       ctrl_write_next;
    logic [(MEM_DATA_WIDTH/8)-1:0] ctrl_wr_strb;
    logic                       ctrl_data_cache_read;
    logic                       ctrl_instr_cache_read;
    logic                       ctrl_memory_write;
    logic                       ctrl_write_through;
    logic                       ctrl_instr_write_start;

endinterface
