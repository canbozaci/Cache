// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Interface wrapping the cache DUT ports. The cache is a blocking, command-style
// DUT: CPU-side requests are held until `busy` drops, and the memory side is a
// request/response pair where the DUT is the requester and the testbench is the
// responder.
//
// CPU-side and maintenance stimulus is driven off `negedge clk` and outputs are
// sampled on `posedge clk`, matching the setup/hold split the RTL was written
// against. Drivers therefore use plain signal assignments rather than clocking
// block outputs: a clocking output would defer the drive to the *next* clocking
// event, which shifts the two-cycle write pulse the controller expects.
// Monitor-only clocking blocks are used for sampling, where that hazard does
// not apply.
interface cache_if #(
    parameter int ADDR_WIDTH = 19,
    parameter int DATA_WIDTH = 64,
    parameter int MEM_DATA_WIDTH = 32
) (
    input logic clk
);

    logic                            rst_n;

    // CPU instruction port
    logic                            instr_req_valid;
    logic [ADDR_WIDTH-1:0]           instr_req_addr;
    logic [31:0]                     instr_resp_data;

    // CPU data port
    logic                            data_req_read;
    logic                            data_req_write;
    logic [ADDR_WIDTH-1:0]           data_req_addr;
    logic [DATA_WIDTH-1:0]           data_req_wdata;
    logic [(DATA_WIDTH/8)-1:0]       data_req_wstrb;
    logic [DATA_WIDTH-1:0]           data_resp_rdata;

    // Native memory port (DUT is the requester)
    logic                            mem_req_valid;
    logic                            mem_req_ready;
    logic                            mem_req_write;
    logic                            mem_req_burst;
    logic [7:0]                      mem_req_burst_len;
    logic [7:0]                      mem_req_beat_index;
    logic                            mem_req_burst_start;
    logic                            mem_req_burst_last;
    logic [31:0]                     mem_req_addr;
    logic [MEM_DATA_WIDTH-1:0]       mem_req_wdata;
    logic [(MEM_DATA_WIDTH/8)-1:0]   mem_req_wstrb;
    logic                            mem_rsp_valid;
    logic                            mem_rsp_ready;
    logic [MEM_DATA_WIDTH-1:0]       mem_rsp_rdata;

    // Maintenance port
    logic                            maint_flush_req;
    logic                            maint_invalidate_req;
    logic                            maint_flush_line_req;
    logic                            maint_invalidate_line_req;
    logic                            maint_addr_valid;
    logic [ADDR_WIDTH-1:0]           maint_addr;
    logic                            maint_ready;
    logic                            maint_done;
    logic                            maint_error;

    logic                            busy;

    // No clocking blocks or modports: every component takes the whole interface
    // as a plain `virtual cache_if`.
    //
    // That is a deliberate choice, not an omission. Monitors sample DUT outputs
    // in the Active region at `posedge`, which yields the pre-NBA value — the
    // same value the DUT itself sampled at that edge, and the same thing the
    // directed testbench this replaced observed. A monitor clocking block would
    // sample in the Preponed region instead, shifting `busy` observation by a
    // cycle relative to the drivers and desynchronising the two from the
    // blocking protocol they both have to agree on.

endinterface
