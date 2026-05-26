// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

`timescale 1ns / 1ps

module cache #(
    parameter ADDR_WIDTH = 19,
    parameter DATA_WIDTH = 64,
    parameter MEM_DATA_WIDTH = 32,
    parameter LINE_WIDTH = 128,
    /* verilator lint_off UNUSEDPARAM */
    parameter L1_SET_COUNT = 64,
    /* verilator lint_on UNUSEDPARAM */
    parameter L1_DATA_SET_COUNT = L1_SET_COUNT,
    parameter L1_INSTR_SET_COUNT = L1_SET_COUNT,
    parameter L2_SET_COUNT = 256,
    parameter MEMORY_BASE_ADDR = 32'h2000_0000
) (
    input clk,
    input rst,

    input instr_req_valid,
    output instr_req_ready,
    input [ADDR_WIDTH-1:0] instr_req_addr,
    output instr_rsp_valid,
    input instr_rsp_ready,
    output [31:0] instr_rsp_data,
    output instr_rsp_error,

    input data_req_valid,
    output data_req_ready,
    input data_req_write,
    input [ADDR_WIDTH-1:0] data_req_addr,
    input [DATA_WIDTH-1:0] data_req_wdata,
    input [(DATA_WIDTH/8)-1:0] data_req_wstrb,
    output data_rsp_valid,
    input data_rsp_ready,
    output [DATA_WIDTH-1:0] data_rsp_rdata,
    output data_rsp_error,

    output mem_req_valid,
    input mem_req_ready,
    output mem_req_write,
    output mem_req_burst,
    output [7:0] mem_req_burst_len,
    output [7:0] mem_req_beat_index,
    output mem_req_burst_start,
    output mem_req_burst_last,
    output [31:0] mem_req_addr,
    output [MEM_DATA_WIDTH-1:0] mem_req_wdata,
    output [(MEM_DATA_WIDTH/8)-1:0] mem_req_wstrb,
    input mem_rd_rsp_valid,
    output mem_rd_rsp_ready,
    input [MEM_DATA_WIDTH-1:0] mem_rd_rsp_rdata,
    input mem_rd_rsp_error,
    input mem_wr_rsp_valid,
    output mem_wr_rsp_ready,
    input mem_wr_rsp_error,

    input maint_flush_req,
    input maint_invalidate_req,
    input maint_flush_line_req,
    input maint_invalidate_line_req,
    input maint_addr_valid,
    input [ADDR_WIDTH-1:0] maint_addr,
    output maint_ready,
    output maint_done,
    output maint_error
);

    localparam DATA_BYTE_COUNT = DATA_WIDTH / 8;
    localparam MEM_BYTE_COUNT = MEM_DATA_WIDTH / 8;
    localparam LINE_BYTE_COUNT = LINE_WIDTH / 8;
    localparam LINE_MEM_BEAT_COUNT = LINE_WIDTH / MEM_DATA_WIDTH;
    localparam [7:0] LINE_MEM_BEAT_COUNT_8 =
        (LINE_MEM_BEAT_COUNT == 1)  ? 8'd1  :
        (LINE_MEM_BEAT_COUNT == 2)  ? 8'd2  :
        (LINE_MEM_BEAT_COUNT == 4)  ? 8'd4  :
        (LINE_MEM_BEAT_COUNT == 8)  ? 8'd8  :
        (LINE_MEM_BEAT_COUNT == 16) ? 8'd16 : 8'd32;
    localparam BYTE_OFFSET_WIDTH = 2;
    localparam LINE_WORD_OFFSET_WIDTH = $clog2(LINE_BYTE_COUNT / 4);
    localparam LINE_OFFSET_WIDTH = $clog2(LINE_BYTE_COUNT);
    localparam L1_DATA_INDEX_WIDTH = $clog2(L1_DATA_SET_COUNT);
    localparam L1_INSTR_INDEX_WIDTH = $clog2(L1_INSTR_SET_COUNT);
    localparam L2_INDEX_WIDTH = $clog2(L2_SET_COUNT);
    localparam L1_DATA_TAG_WIDTH = ADDR_WIDTH - L1_DATA_INDEX_WIDTH - LINE_WORD_OFFSET_WIDTH - BYTE_OFFSET_WIDTH;
    localparam L1_INSTR_TAG_WIDTH = ADDR_WIDTH - L1_INSTR_INDEX_WIDTH - LINE_WORD_OFFSET_WIDTH - BYTE_OFFSET_WIDTH;
    localparam L2_ADDR_WIDTH = ADDR_WIDTH - LINE_OFFSET_WIDTH;
    localparam L2_TAG_WIDTH = L2_ADDR_WIDTH - L2_INDEX_WIDTH;
    localparam STATE_IDLE = 2'd0;
    localparam STATE_RUN = 2'd1;

    reg [1:0] state_q;
    reg [7:0] run_age_q;
    reg core_activity_seen_q;
    reg active_instr_q;
    reg active_data_q;
    reg active_data_write_q;
    reg [ADDR_WIDTH-1:0] instr_addr_q;
    reg [ADDR_WIDTH-1:0] data_addr_q;
    reg [DATA_WIDTH-1:0] data_wdata_q;
    reg [(DATA_WIDTH/8)-1:0] data_wstrb_q;
    reg instr_rsp_valid_q;
    reg [31:0] instr_rsp_data_q;
    reg instr_rsp_error_q;
    reg data_rsp_valid_q;
    reg [DATA_WIDTH-1:0] data_rsp_rdata_q;
    reg data_rsp_error_q;
    reg write_error_seen_q;
    reg [7:0] write_req_count_q;
    reg [7:0] write_rsp_count_q;
    reg core_abort_q;
    reg [7:0] last_data_strobe_byte;
    integer strobe_index;

    wire write_through;
    wire cache_array_rst;
    wire core_rst;
    reg maint_done_q;
    reg maint_error_q;
    reg maint_invalidate_pulse;
    reg maint_invalidate_line_pulse;
    reg [ADDR_WIDTH-1:0] maint_addr_q;
    reg maint_pending;
    reg maint_pending_error;
    reg maint_pending_invalidate;
    reg maint_pending_invalidate_line;

    wire [LINE_WIDTH-1:0] l2_write_block_p1;
    wire [LINE_WIDTH-1:0] l2_write_block_p2;
    wire [LINE_WIDTH-1:0] l2_read_block_p1;
    wire [LINE_WIDTH-1:0] l2_read_block_p2;
    wire [L2_ADDR_WIDTH-1:0] l2_p2_addr;
    wire [L2_ADDR_WIDTH-1:0] l2_maint_addr;
    wire [L1_DATA_TAG_WIDTH+L1_DATA_INDEX_WIDTH-1:0] l1_data_maint_tag_and_idx;
    wire [L1_INSTR_TAG_WIDTH+L1_INSTR_INDEX_WIDTH-1:0] l1_instr_maint_tag_and_idx;
    wire [LINE_BYTE_COUNT-1:0] l2_byte_enable_p1;
    wire [LINE_BYTE_COUNT-1:0] l2_byte_enable_p2;
    wire l2_read_p1;
    wire l2_read_p2;
    wire l2_write_p1;
    wire l2_write_p2;
    wire l2_p1_hit;
    wire l2_p2_hit;
    wire mem_write_start;
    wire mem_read_internal;
    wire mem_write_internal;
    wire [7:0] mem_read_beat_index_internal;
    wire [7:0] mem_write_beat_index_internal;
    wire [7:0] mem_write_burst_len_internal;
    wire [31:0] mem_read_addr_internal;
    wire [31:0] mem_write_addr_internal;

    wire l1_instr_hit;
    wire l1_instr_write;
    wire l1_miss_next;
    wire instr_cache_read;
    wire instr_write_start;
    wire write_next;
    wire controller_busy;
    wire cache_traffic_busy;
    wire unused_controller_outputs;

    wire write_l2;
    wire data_cache_read;
    wire l1_data_hit;
    reg l1_data_hit_q;
    wire [LINE_WIDTH-1:0] l1_data_block;
    wire [MEM_DATA_WIDTH-1:0] mem_wdata_internal;
    wire [(MEM_DATA_WIDTH/8)-1:0] mem_wstrb_internal;
    reg mem_rsp_valid_q;
    reg [MEM_DATA_WIDTH-1:0] mem_rsp_rdata_q;
    reg data_memory_fill_active;
    reg instr_memory_fill_active;
    reg [LINE_WIDTH-1:0] data_memory_fill_block;
    reg [LINE_WIDTH-1:0] instr_memory_fill_block;
    reg [MEM_DATA_WIDTH-1:0] mem_req_wdata_aligned;
    integer fill_byte_index;
    integer write_byte_index;
    integer write_source_byte_index;
    integer write_addr_delta;
    wire maint_global_req;
    wire maint_line_req;
    wire maint_req;
    wire maint_req_error;
    wire maint_accept;
    wire maint_execute;
    wire idle_ready;
    wire data_wstrb_nonzero;
    wire [LINE_OFFSET_WIDTH-1:0] data_line_offset;
    wire data_line_crossing;
    wire data_request_legal;
    wire accept_instr;
    wire accept_data;
    wire start_core_transaction;
    wire complete_write_responses;
    wire complete_core_transaction;
    wire read_error_handshake;
    wire write_rsp_handshake;
    wire mem_rsp_valid;
    wire mem_rsp_ready;
    wire [MEM_DATA_WIDTH-1:0] mem_rsp_rdata;
    wire busy;
    wire [31:0] instr_resp_data;
    wire [DATA_WIDTH-1:0] data_resp_rdata;
    wire core_instr_request;
    wire core_data_read_request;
    wire core_data_write_request;

    always @(*) begin
        last_data_strobe_byte = 8'd0;
        for (strobe_index = 0; strobe_index < DATA_BYTE_COUNT; strobe_index = strobe_index + 1) begin
            if (data_req_wstrb[strobe_index]) begin
                last_data_strobe_byte = strobe_index[7:0];
            end
        end
    end

    assign data_wstrb_nonzero = |data_req_wstrb;
    assign data_line_offset = data_req_addr[LINE_OFFSET_WIDTH-1:0];
    assign data_line_crossing = ({{(32-LINE_OFFSET_WIDTH){1'b0}}, data_line_offset} +
                                 {24'b0, last_data_strobe_byte}) >= LINE_BYTE_COUNT;
    assign data_request_legal = (~data_req_write | data_wstrb_nonzero) & ~data_line_crossing;
    assign idle_ready = (state_q == STATE_IDLE) & ~busy & ~instr_rsp_valid_q & ~data_rsp_valid_q;
    assign data_req_ready = idle_ready;
    assign instr_req_ready = idle_ready & (~data_req_valid | (~data_req_write & data_request_legal));
    assign accept_data = data_req_valid & data_req_ready;
    assign accept_instr = instr_req_valid & instr_req_ready;
    assign start_core_transaction = (accept_instr | accept_data) & (~accept_data | data_request_legal);
    assign read_error_handshake = mem_rd_rsp_valid & mem_rd_rsp_ready & mem_rd_rsp_error;
    assign write_rsp_handshake = mem_wr_rsp_valid & mem_wr_rsp_ready;
    assign complete_write_responses = ~active_data_write_q |
                                      ((write_req_count_q != 8'd0) &&
                                       (write_rsp_count_q == write_req_count_q) &&
                                       !mem_wr_rsp_valid);
    assign complete_core_transaction = (state_q == STATE_RUN) & ~busy & ~mem_req_valid &
                                       ~mem_rd_rsp_valid & ~mem_wr_rsp_valid &
                                       complete_write_responses &
                                       ((!core_activity_seen_q & (run_age_q >= 8'd6)) |
                                        (core_activity_seen_q & (run_age_q >= 8'd32)));
    assign core_rst = rst | core_abort_q;
    assign mem_rsp_valid = mem_rd_rsp_valid & mem_rd_rsp_ready & ~mem_rd_rsp_error;
    assign mem_rsp_rdata = mem_rd_rsp_rdata;
    assign mem_rd_rsp_ready = (state_q == STATE_RUN) & mem_rsp_ready;
    assign mem_wr_rsp_ready = (state_q == STATE_RUN) & active_data_write_q;
    assign instr_rsp_valid = instr_rsp_valid_q;
    assign instr_rsp_data = instr_rsp_data_q;
    assign instr_rsp_error = instr_rsp_error_q;
    assign data_rsp_valid = data_rsp_valid_q;
    assign data_rsp_rdata = data_rsp_rdata_q;
    assign data_rsp_error = data_rsp_error_q;
    assign core_instr_request = (state_q == STATE_RUN) & active_instr_q;
    assign core_data_read_request = (state_q == STATE_RUN) & active_data_q & ~active_data_write_q;
    assign core_data_write_request = (state_q == STATE_RUN) & active_data_q & active_data_write_q & (run_age_q < 8'd2);

    assign mem_req_valid = mem_read_internal | mem_write_internal;
    assign mem_req_write = mem_write_internal;
    assign mem_req_burst = (mem_read_internal & ~mem_write_internal & (LINE_MEM_BEAT_COUNT != 1)) |
                           (mem_write_internal & (mem_write_burst_len_internal != 8'd1));
    assign mem_req_burst_len =
        mem_write_internal ? mem_write_burst_len_internal :
        ((mem_read_internal & (LINE_MEM_BEAT_COUNT != 1)) ? LINE_MEM_BEAT_COUNT_8 : 8'd1);
    assign mem_req_beat_index =
        mem_write_internal ? mem_write_beat_index_internal :
        ((mem_read_internal & (LINE_MEM_BEAT_COUNT != 1)) ? mem_read_beat_index_internal : 8'd0);
    assign mem_req_burst_start = mem_req_burst & (mem_req_beat_index == 8'd0);
    assign mem_req_burst_last = mem_req_burst &
                                (mem_req_beat_index == (mem_req_burst_len - 8'd1));
    assign mem_req_addr = mem_write_internal ? mem_write_addr_internal : mem_read_addr_internal;
    assign mem_req_wdata = mem_write_internal ? mem_req_wdata_aligned : mem_wdata_internal;
    assign mem_req_wstrb = mem_wstrb_internal;
    assign mem_rsp_ready = (state_q == STATE_RUN);

    assign l2_write_block_p1 = (mem_rsp_valid_q == 1'b1) ? {LINE_MEM_BEAT_COUNT{mem_rsp_rdata_q}} : l1_data_block;
    assign l2_write_block_p2 = {LINE_MEM_BEAT_COUNT{mem_rsp_rdata_q}};
    assign unused_controller_outputs = instr_write_start | write_next;
    assign cache_traffic_busy = controller_busy | (unused_controller_outputs & 1'b0);
    assign busy = cache_traffic_busy | maint_pending;
    assign maint_global_req = maint_flush_req | maint_invalidate_req;
    assign maint_line_req = maint_flush_line_req | maint_invalidate_line_req;
    assign maint_req = maint_global_req | maint_line_req;
    assign maint_req_error = (maint_global_req & maint_line_req) |
                             (maint_flush_req & maint_invalidate_req) |
                             (maint_flush_line_req & maint_invalidate_line_req) |
                             (maint_line_req & ~maint_addr_valid);
    assign maint_accept = ~maint_pending & ~maint_done_q & maint_req;
    assign maint_execute = maint_pending & ~cache_traffic_busy;
    assign maint_ready = ~maint_pending | maint_execute;
    assign maint_done = maint_done_q;
    assign maint_error = maint_error_q;
    assign cache_array_rst = core_rst | maint_invalidate_pulse;
    assign l2_maint_addr = maint_addr_q[L2_ADDR_WIDTH-1:0];
    assign l1_data_maint_tag_and_idx = maint_addr_q[ADDR_WIDTH-1:LINE_WORD_OFFSET_WIDTH+BYTE_OFFSET_WIDTH];
    assign l1_instr_maint_tag_and_idx = maint_addr_q[ADDR_WIDTH-1:LINE_WORD_OFFSET_WIDTH+BYTE_OFFSET_WIDTH];

    always @(*) begin
        mem_req_wdata_aligned = {MEM_DATA_WIDTH{1'b0}};
        write_addr_delta = (mem_write_addr_internal - MEMORY_BASE_ADDR) - {{(32-ADDR_WIDTH){1'b0}}, data_addr_q};
        for (write_byte_index = 0; write_byte_index < MEM_BYTE_COUNT; write_byte_index = write_byte_index + 1) begin
            write_source_byte_index = write_addr_delta + write_byte_index;
            if ((write_source_byte_index >= 0) && (write_source_byte_index < DATA_BYTE_COUNT)) begin
                mem_req_wdata_aligned[write_byte_index*8 +: 8] =
                    data_wdata_q[write_source_byte_index*8 +: 8];
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            state_q <= STATE_IDLE;
            run_age_q <= 8'd0;
            core_activity_seen_q <= 1'b0;
            active_instr_q <= 1'b0;
            active_data_q <= 1'b0;
            active_data_write_q <= 1'b0;
            instr_addr_q <= {ADDR_WIDTH{1'b0}};
            data_addr_q <= {ADDR_WIDTH{1'b0}};
            data_wdata_q <= {DATA_WIDTH{1'b0}};
            data_wstrb_q <= {DATA_BYTE_COUNT{1'b0}};
            instr_rsp_valid_q <= 1'b0;
            instr_rsp_data_q <= 32'b0;
            instr_rsp_error_q <= 1'b0;
            data_rsp_valid_q <= 1'b0;
            data_rsp_rdata_q <= {DATA_WIDTH{1'b0}};
            data_rsp_error_q <= 1'b0;
            write_error_seen_q <= 1'b0;
            write_req_count_q <= 8'd0;
            write_rsp_count_q <= 8'd0;
            core_abort_q <= 1'b0;
        end else begin
            core_abort_q <= 1'b0;

            if (instr_rsp_valid_q & instr_rsp_ready) begin
                instr_rsp_valid_q <= 1'b0;
            end
            if (data_rsp_valid_q & data_rsp_ready) begin
                data_rsp_valid_q <= 1'b0;
            end

            if (accept_data & ~data_request_legal) begin
                data_rsp_valid_q <= 1'b1;
                data_rsp_rdata_q <= {DATA_WIDTH{1'b0}};
                data_rsp_error_q <= 1'b1;
            end else if (start_core_transaction) begin
                state_q <= STATE_RUN;
                run_age_q <= 8'd0;
                core_activity_seen_q <= 1'b0;
                active_instr_q <= accept_instr;
                active_data_q <= accept_data;
                active_data_write_q <= accept_data & data_req_write;
                instr_addr_q <= instr_req_addr;
                data_addr_q <= data_req_addr;
                data_wdata_q <= data_req_wdata;
                data_wstrb_q <= data_req_wstrb;
                write_error_seen_q <= 1'b0;
                write_req_count_q <= 8'd0;
                write_rsp_count_q <= 8'd0;
            end else if (state_q == STATE_RUN) begin
                if (run_age_q != 8'hff) begin
                    run_age_q <= run_age_q + 8'd1;
                end
                if (busy | mem_req_valid | mem_rd_rsp_valid | mem_wr_rsp_valid) begin
                    core_activity_seen_q <= 1'b1;
                end
                if (mem_req_valid & mem_req_ready & mem_req_write) begin
                    write_req_count_q <= write_req_count_q + 8'd1;
                end
                if (write_rsp_handshake) begin
                    write_rsp_count_q <= write_rsp_count_q + 8'd1;
                    write_error_seen_q <= write_error_seen_q | mem_wr_rsp_error;
                end
                if (read_error_handshake) begin
                    state_q <= STATE_IDLE;
                    core_abort_q <= 1'b1;
                    if (active_instr_q) begin
                        instr_rsp_valid_q <= 1'b1;
                        instr_rsp_data_q <= 32'b0;
                        instr_rsp_error_q <= 1'b1;
                    end
                    if (active_data_q) begin
                        data_rsp_valid_q <= 1'b1;
                        data_rsp_rdata_q <= {DATA_WIDTH{1'b0}};
                        data_rsp_error_q <= 1'b1;
                    end
                    active_instr_q <= 1'b0;
                    active_data_q <= 1'b0;
                    active_data_write_q <= 1'b0;
                end else if (complete_core_transaction) begin
                    state_q <= STATE_IDLE;
                    if (active_instr_q) begin
                        instr_rsp_valid_q <= 1'b1;
                        instr_rsp_data_q <= instr_resp_data;
                        instr_rsp_error_q <= 1'b0;
                    end
                    if (active_data_q) begin
                        data_rsp_valid_q <= 1'b1;
                        data_rsp_rdata_q <= active_data_write_q ? {DATA_WIDTH{1'b0}} : data_resp_rdata;
                        data_rsp_error_q <= active_data_write_q & write_error_seen_q;
                    end
                    active_instr_q <= 1'b0;
                    active_data_q <= 1'b0;
                    active_data_write_q <= 1'b0;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (core_rst) begin
            mem_rsp_valid_q <= 1'b0;
            mem_rsp_rdata_q <= {MEM_DATA_WIDTH{1'b0}};
            l1_data_hit_q <= 1'b0;
            maint_done_q <= 1'b0;
            maint_error_q <= 1'b0;
            maint_invalidate_pulse <= 1'b0;
            maint_invalidate_line_pulse <= 1'b0;
            maint_addr_q <= {ADDR_WIDTH{1'b0}};
            maint_pending <= 1'b0;
            maint_pending_error <= 1'b0;
            maint_pending_invalidate <= 1'b0;
            maint_pending_invalidate_line <= 1'b0;
            data_memory_fill_active <= 1'b0;
            instr_memory_fill_active <= 1'b0;
            data_memory_fill_block <= {LINE_WIDTH{1'b0}};
            instr_memory_fill_block <= {LINE_WIDTH{1'b0}};
        end else begin
            mem_rsp_valid_q <= mem_rsp_valid;
            l1_data_hit_q <= l1_data_hit;
            maint_done_q <= maint_execute & ~maint_pending_error;
            maint_error_q <= maint_execute & maint_pending_error;
            maint_invalidate_pulse <= maint_execute & ~maint_pending_error & maint_pending_invalidate;
            maint_invalidate_line_pulse <= maint_execute & ~maint_pending_error & maint_pending_invalidate_line;
            if (maint_execute) begin
                maint_pending <= 1'b0;
            end else if (maint_accept) begin
                maint_pending <= 1'b1;
                maint_pending_error <= maint_req_error;
                maint_pending_invalidate <= maint_invalidate_req & ~maint_req_error;
                maint_pending_invalidate_line <= maint_invalidate_line_req & ~maint_req_error;
                if (maint_addr_valid) begin
                    maint_addr_q <= maint_addr;
                end
            end
            if (mem_rsp_valid) begin
                mem_rsp_rdata_q <= mem_rsp_rdata;
            end
            if (mem_rsp_valid_q && l2_write_p1 && !mem_write_internal) begin
                data_memory_fill_active <= 1'b1;
                for (
                    fill_byte_index = 0;
                    fill_byte_index < LINE_BYTE_COUNT;
                    fill_byte_index = fill_byte_index + 1
                ) begin
                    if (l2_byte_enable_p1[fill_byte_index]) begin
                        data_memory_fill_block[fill_byte_index*8 +: 8] <=
                            mem_rsp_rdata_q[(fill_byte_index % MEM_BYTE_COUNT)*8 +: 8];
                    end
                end
            end
            if (mem_rsp_valid_q && l2_write_p2) begin
                instr_memory_fill_active <= 1'b1;
                for (
                    fill_byte_index = 0;
                    fill_byte_index < LINE_BYTE_COUNT;
                    fill_byte_index = fill_byte_index + 1
                ) begin
                    if (l2_byte_enable_p2[fill_byte_index]) begin
                        instr_memory_fill_block[fill_byte_index*8 +: 8] <=
                            mem_rsp_rdata_q[(fill_byte_index % MEM_BYTE_COUNT)*8 +: 8];
                    end
                end
            end
            if (write_l2) begin
                data_memory_fill_active <= 1'b0;
            end
            if (l1_instr_write) begin
                instr_memory_fill_active <= 1'b0;
            end
        end
    end

    cache_l1_data #(
        .LINE_WIDTH(LINE_WIDTH),
        .TAG_WIDTH(L1_DATA_TAG_WIDTH),
        .INDEX_WIDTH(L1_DATA_INDEX_WIDTH),
        .SET_COUNT(L1_DATA_SET_COUNT),
        .WORD_OFFSET_WIDTH(LINE_WORD_OFFSET_WIDTH),
        .BYTE_OFFSET_WIDTH(BYTE_OFFSET_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .LINE_BYTE_COUNT(LINE_BYTE_COUNT)
    ) cache_l1_data_inst (
        .clk(clk),
        .rst(cache_array_rst),
        .read(data_cache_read | core_data_read_request),
        .write(write_l2 | (write_through & l1_data_hit_q)),
        .write_L2(write_l2),
        .write_through(write_through),
        .invalidate_line(maint_invalidate_line_pulse),
        .invalidate_tag_and_idx(l1_data_maint_tag_and_idx),
        .addr(data_addr_q),
        .write_data(data_wdata_q),
        .write_strobe(data_wstrb_q),
        .data_L2(data_memory_fill_active ? data_memory_fill_block : l2_read_block_p1),
        .data_block(l1_data_block),
        .data(data_resp_rdata),
        .hit(l1_data_hit)
    );

    cache_l1_instr #(
        .LINE_WIDTH(LINE_WIDTH),
        .DATA_WIDTH(32),
        .TAG_WIDTH(L1_INSTR_TAG_WIDTH),
        .INDEX_WIDTH(L1_INSTR_INDEX_WIDTH),
        .SET_COUNT(L1_INSTR_SET_COUNT),
        .WORD_OFFSET_WIDTH(LINE_WORD_OFFSET_WIDTH),
        .BYTE_OFFSET_WIDTH(BYTE_OFFSET_WIDTH)
    ) cache_l1_instr_inst (
        .clk(clk),
        .rst(cache_array_rst),
        .read(instr_cache_read | core_instr_request),
        .fill(l1_instr_write),
        .invalidate_line(maint_invalidate_line_pulse),
        .invalidate_tag_and_idx(l1_instr_maint_tag_and_idx),
        .addr(instr_addr_q),
        .fill_block(instr_memory_fill_active ? instr_memory_fill_block : l2_read_block_p2),
        .data(instr_resp_data),
        .hit(l1_instr_hit)
    );

    assign l1_miss_next = 1'b0;

    cache_l2 #(
        .LINE_WIDTH(LINE_WIDTH),
        .TAG_WIDTH(L2_TAG_WIDTH),
        .INDEX_WIDTH(L2_INDEX_WIDTH),
        .SET_COUNT(L2_SET_COUNT),
        .LINE_BYTE_COUNT(LINE_BYTE_COUNT)
    ) cache_l2_inst (
        .clk(clk),
        .rst(cache_array_rst),
        .read_p1(l2_read_p1),
        .read_p2(l2_read_p2),
        .write_p1(l2_write_p1 & (write_through | mem_rsp_valid_q)),
        .write_p2(l2_write_p2 & mem_rsp_valid_q),
        .data_block_write_p1(l2_write_block_p1),
        .data_block_write_p2(l2_write_block_p2),
        .byte_enable_p1(l2_byte_enable_p1),
        .byte_enable_p2(l2_byte_enable_p2),
        .addr_p1(data_addr_q[L2_ADDR_WIDTH-1:0]),
        .addr_p2(l2_p2_addr),
        .invalidate_line(maint_invalidate_line_pulse),
        .invalidate_addr(l2_maint_addr),
        .ram_write_start(mem_write_start),
        .write_through(write_through),
        .data_block_read_p1(l2_read_block_p1),
        .data_block_read_p2(l2_read_block_p2),
        .hit_p1(l2_p1_hit),
        .hit_p2(l2_p2_hit)
    );

    cache_controller #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .MEM_DATA_WIDTH(MEM_DATA_WIDTH),
        .LINE_WIDTH(LINE_WIDTH),
        .LINE_BYTE_COUNT(LINE_BYTE_COUNT),
        .DATA_BYTE_COUNT(DATA_BYTE_COUNT),
        .MEM_BYTE_COUNT(MEM_BYTE_COUNT),
        .LINE_OFFSET_WIDTH(LINE_OFFSET_WIDTH),
        .L2_ADDR_WIDTH(L2_ADDR_WIDTH),
        .MEMORY_BASE_ADDR(MEMORY_BASE_ADDR)
    ) cache_controller_inst (
        .clk(clk),
        .rst(core_rst),
        .ram_req_ready(mem_req_ready),
        .ram_rsp_valid(mem_rsp_valid_q),
        .l2_data_block_p1(l2_read_block_p1),
        .L1_data_addr(data_addr_q),
        .L1_instr_addr(instr_addr_q),
        .L2_p1_hit(l2_p1_hit),
        .L2_p2_hit(l2_p2_hit),
        .L1_data_hit(l1_data_hit),
        .L1_instr_hit(l1_instr_hit),
        .L1_miss_next(l1_miss_next),
        .instr_request(core_instr_request),
        .data_read_request(core_data_read_request),
        .data_write_request(core_data_write_request),
        .data_write_strobe(data_wstrb_q),
        .write_L2(write_l2),
        .L1_instr_write(l1_instr_write),
        .L2_read_p1(l2_read_p1),
        .L2_read_p2(l2_read_p2),
        .L2_write_p1(l2_write_p1),
        .L2_write_p2(l2_write_p2),
        .L2_byte_enable_p1(l2_byte_enable_p1),
        .L2_byte_enable_p2(l2_byte_enable_p2),
        .L2_p2_addr(l2_p2_addr),
        .ram_data(mem_wdata_internal),
        .ram_read_addr(mem_read_addr_internal),
        .ram_write_addr(mem_write_addr_internal),
        .ram_read_beat_index(mem_read_beat_index_internal),
        .ram_write_beat_index(mem_write_beat_index_internal),
        .ram_write_burst_len(mem_write_burst_len_internal),
        .ram_read(mem_read_internal),
        .miss(controller_busy),
        .ram_write_start(mem_write_start),
        .write_next(write_next),
        .wr_strb(mem_wstrb_internal),
        .data_cache_read(data_cache_read),
        .instr_cache_read(instr_cache_read),
        .memory_write(mem_write_internal),
        .write_through(write_through),
        .instr_write_start(instr_write_start)
    );

endmodule
