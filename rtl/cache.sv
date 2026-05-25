`timescale 1ns / 1ps

module cache #(
    parameter ADDR_WIDTH = 19,
    parameter DATA_WIDTH = 64,
    parameter MEM_DATA_WIDTH = 32,
    parameter LINE_WIDTH = 128,
    parameter L1_INDEX_WIDTH = 6,
    parameter L2_INDEX_WIDTH = 8,
    parameter MEMORY_BASE_ADDR = 32'h2000_0000
) (
    input clk,
    input rst,

    input instr_req_valid,
    input [ADDR_WIDTH-1:0] instr_req_addr,
    output [31:0] instr_resp_data,

    input data_req_read,
    input data_req_write,
    input [ADDR_WIDTH-1:0] data_req_addr,
    input [DATA_WIDTH-1:0] data_req_wdata,
    input [(DATA_WIDTH/8)-1:0] data_req_wstrb,
    output [DATA_WIDTH-1:0] data_resp_rdata,

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
    input mem_rsp_valid,
    output mem_rsp_ready,
    input [MEM_DATA_WIDTH-1:0] mem_rsp_rdata,

    input maint_flush_req,
    input maint_invalidate_req,
    output maint_ready,
    output maint_done,
    output maint_error,

    output busy
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
    localparam L1_TAG_WIDTH = ADDR_WIDTH - L1_INDEX_WIDTH - LINE_WORD_OFFSET_WIDTH - BYTE_OFFSET_WIDTH;
    localparam L2_ADDR_WIDTH = ADDR_WIDTH - LINE_OFFSET_WIDTH;
    localparam L2_TAG_WIDTH = L2_ADDR_WIDTH - L2_INDEX_WIDTH;

    wire write_through;
    wire cache_array_rst;
    reg maint_done_q;
    reg maint_error_q;
    reg maint_invalidate_pulse;

    wire [LINE_WIDTH-1:0] l2_write_block_p1;
    wire [LINE_WIDTH-1:0] l2_write_block_p2;
    wire [LINE_WIDTH-1:0] l2_read_block_p1;
    wire [LINE_WIDTH-1:0] l2_read_block_p2;
    wire [L2_ADDR_WIDTH-1:0] l2_p2_addr;
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

    assign mem_req_valid = mem_read_internal | mem_write_internal;
    assign mem_req_write = mem_write_internal;
    assign mem_req_burst = (mem_read_internal & ~mem_write_internal & (LINE_MEM_BEAT_COUNT != 1)) |
                           (mem_write_internal & (mem_write_burst_len_internal != 8'd1));
    assign mem_req_burst_len = mem_write_internal ? mem_write_burst_len_internal :
                               ((mem_read_internal & (LINE_MEM_BEAT_COUNT != 1)) ? LINE_MEM_BEAT_COUNT_8 : 8'd1);
    assign mem_req_beat_index = mem_write_internal ? mem_write_beat_index_internal :
                                ((mem_read_internal & (LINE_MEM_BEAT_COUNT != 1)) ? mem_read_beat_index_internal : 8'd0);
    assign mem_req_burst_start = mem_req_burst & (mem_req_beat_index == 8'd0);
    assign mem_req_burst_last = mem_req_burst &
                                (mem_req_beat_index == (mem_req_burst_len - 8'd1));
    assign mem_req_addr = mem_write_internal ? mem_write_addr_internal : mem_read_addr_internal;
    assign mem_req_wdata = mem_write_internal ? mem_req_wdata_aligned : mem_wdata_internal;
    assign mem_req_wstrb = mem_wstrb_internal;
    assign mem_rsp_ready = 1'b1;

    assign l2_write_block_p1 = (mem_rsp_valid_q == 1'b1) ? {LINE_MEM_BEAT_COUNT{mem_rsp_rdata_q}} : l1_data_block;
    assign l2_write_block_p2 = {LINE_MEM_BEAT_COUNT{mem_rsp_rdata_q}};
    assign unused_controller_outputs = instr_write_start | write_next;
    assign busy = controller_busy | (unused_controller_outputs & 1'b0);
    assign maint_ready = ~busy;
    assign maint_done = maint_done_q;
    assign maint_error = maint_error_q;
    assign cache_array_rst = rst | maint_invalidate_pulse;

    always @(*) begin
        mem_req_wdata_aligned = {MEM_DATA_WIDTH{1'b0}};
        write_addr_delta = (mem_write_addr_internal - MEMORY_BASE_ADDR) - {{(32-ADDR_WIDTH){1'b0}}, data_req_addr};
        for (write_byte_index = 0; write_byte_index < MEM_BYTE_COUNT; write_byte_index = write_byte_index + 1) begin
            write_source_byte_index = write_addr_delta + write_byte_index;
            if ((write_source_byte_index >= 0) && (write_source_byte_index < DATA_BYTE_COUNT)) begin
                mem_req_wdata_aligned[write_byte_index*8 +: 8] =
                    data_req_wdata[write_source_byte_index*8 +: 8];
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            mem_rsp_valid_q <= 1'b0;
            mem_rsp_rdata_q <= {MEM_DATA_WIDTH{1'b0}};
            l1_data_hit_q <= 1'b0;
            maint_done_q <= 1'b0;
            maint_error_q <= 1'b0;
            maint_invalidate_pulse <= 1'b0;
            data_memory_fill_active <= 1'b0;
            instr_memory_fill_active <= 1'b0;
            data_memory_fill_block <= {LINE_WIDTH{1'b0}};
            instr_memory_fill_block <= {LINE_WIDTH{1'b0}};
        end else begin
            mem_rsp_valid_q <= mem_rsp_valid;
            l1_data_hit_q <= l1_data_hit;
            maint_done_q <= maint_ready & (maint_flush_req | maint_invalidate_req) & ~(maint_flush_req & maint_invalidate_req);
            maint_error_q <= maint_ready & maint_flush_req & maint_invalidate_req;
            maint_invalidate_pulse <= maint_ready & maint_invalidate_req & ~maint_flush_req;
            if (mem_rsp_valid) begin
                mem_rsp_rdata_q <= mem_rsp_rdata;
            end
            if (mem_rsp_valid_q && l2_write_p1 && !mem_write_internal) begin
                data_memory_fill_active <= 1'b1;
                for (fill_byte_index = 0; fill_byte_index < LINE_BYTE_COUNT; fill_byte_index = fill_byte_index + 1) begin
                    if (l2_byte_enable_p1[fill_byte_index]) begin
                        data_memory_fill_block[fill_byte_index*8 +: 8] <=
                            mem_rsp_rdata_q[(fill_byte_index % MEM_BYTE_COUNT)*8 +: 8];
                    end
                end
            end
            if (mem_rsp_valid_q && l2_write_p2) begin
                instr_memory_fill_active <= 1'b1;
                for (fill_byte_index = 0; fill_byte_index < LINE_BYTE_COUNT; fill_byte_index = fill_byte_index + 1) begin
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

    Cache_MEM_L1_data #(
        .block_size(LINE_WIDTH),
        .tag_size(L1_TAG_WIDTH),
        .idx_size(L1_INDEX_WIDTH),
        .word_size(LINE_WORD_OFFSET_WIDTH),
        .offset_size(BYTE_OFFSET_WIDTH),
        .data_width(DATA_WIDTH),
        .line_byte_count(LINE_BYTE_COUNT)
    ) cache_l1_data_inst (
        .clk(clk),
        .rst(cache_array_rst),
        .read(data_cache_read | data_req_read),
        .write(write_l2 | (write_through & l1_data_hit_q)),
        .write_L2(write_l2),
        .write_through(write_through),
        .addr(data_req_addr),
        .write_data(data_req_wdata),
        .write_strobe(data_req_wstrb),
        .data_L2(data_memory_fill_active ? data_memory_fill_block : l2_read_block_p1),
        .data_block(l1_data_block),
        .data(data_resp_rdata),
        .hit(l1_data_hit)
    );

    cache_l1_read_cache #(
        .BLOCK_WIDTH(LINE_WIDTH),
        .DATA_WIDTH(32),
        .TAG_WIDTH(L1_TAG_WIDTH),
        .INDEX_WIDTH(L1_INDEX_WIDTH),
        .LINE_COUNT(1 << L1_INDEX_WIDTH),
        .WORD_OFFSET_WIDTH(LINE_WORD_OFFSET_WIDTH),
        .BYTE_OFFSET_WIDTH(BYTE_OFFSET_WIDTH)
    ) cache_l1_instr_inst (
        .clk(clk),
        .rst(cache_array_rst),
        .read(instr_cache_read | instr_req_valid),
        .fill(l1_instr_write),
        .addr(instr_req_addr),
        .fill_block(instr_memory_fill_active ? instr_memory_fill_block : l2_read_block_p2),
        .data(instr_resp_data),
        .hit(l1_instr_hit)
    );

    assign l1_miss_next = 1'b0;

    Cache_MEM_L2 #(
        .block_size(LINE_WIDTH),
        .tag_size(L2_TAG_WIDTH),
        .idx_size(L2_INDEX_WIDTH),
        .block_no(1 << L2_INDEX_WIDTH),
        .line_byte_count(LINE_BYTE_COUNT)
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
        .addr_p1(data_req_addr[L2_ADDR_WIDTH-1:0]),
        .addr_p2(l2_p2_addr),
        .ram_write_start(mem_write_start),
        .write_through(write_through),
        .data_block_read_p1(l2_read_block_p1),
        .data_block_read_p2(l2_read_block_p2),
        .hit_p1(l2_p1_hit),
        .hit_p2(l2_p2_hit)
    );

    Cache_controller #(
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
        .rst(rst),
        .ram_req_ready(mem_req_ready),
        .ram_rsp_valid(mem_rsp_valid_q),
        .L2_data_block_p1(l2_read_block_p1),
        .L1_data_addr(data_req_addr),
        .L1_instr_addr(instr_req_addr),
        .L2_p1_hit(l2_p1_hit),
        .L2_p2_hit(l2_p2_hit),
        .L1_data_hit(l1_data_hit),
        .L1_instr_hit(l1_instr_hit),
        .L1_miss_next(l1_miss_next),
        .instr_request(instr_req_valid),
        .data_read_request(data_req_read),
        .data_write_request(data_req_write),
        .data_write_strobe(data_req_wstrb),
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
