// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Reactive slave for the native memory port.
//
// The DUT is the requester here, so this component has no sequencer: it does
// not originate traffic, it answers it. It rolls three jobs into one process
// because they share the same clock edge and the same state:
//
//   1. `mem_req_ready` back-pressure, optionally stalling one cycle in four
//   2. the backing memory itself, byte-writable and pattern-initialised
//   3. `mem_rsp_valid` timing, with fixed or per-request-varying latency
//
// The response model is deliberately one-deep. That is sound because the cache
// is blocking and paces its own beats; a multiple-outstanding-miss cache would
// need a queue here, and that is called out as unsupported in the IP contract.
//
// Extends uvm_component rather than uvm_driver on purpose: a uvm_driver carries
// a seq_item_port, and since there is no sequencer to connect it to, UVM would
// (correctly) warn that it is dangling.
class cache_mem_driver extends uvm_component;

    cache_vif_t    vif;
    cache_env_cfg  cfg;

    // Backing store. Shares cache_ref_model with the scoreboard's oracle so
    // both power up holding the identical generated pattern, but this is a
    // separate instance: it is written by observed *memory* traffic, while the
    // oracle is written by observed *CPU* traffic. Divergence between them is a
    // write-through bug.
    cache_ref_model backing;

    // Address decode matching the legacy memory model: a 17-bit word index,
    // scaled by the memory data width.
    static const int MEM_ADDR_LSB   = (MEM_DATA_WIDTH_P == 64) ? 3 : 2;
    static const int RAM_ADDR_WIDTH = 17;

    `uvm_component_utils(cache_mem_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(cache_vif_t)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for cache_mem_driver")
        if (!uvm_config_db#(cache_env_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "cache_env_cfg not set for cache_mem_driver")
        backing = cache_ref_model::type_id::create("backing");
    endfunction

    // Byte address of the addressed memory word, after the same truncation the
    // legacy model applied.
    protected function int unsigned word_base(bit [31:0] addr);
        int unsigned word_index = (addr >> MEM_ADDR_LSB) & ((1 << RAM_ADDR_WIDTH) - 1);
        return word_index << MEM_ADDR_LSB;
    endfunction

    protected function bit [MEM_DATA_WIDTH_P-1:0] read_word(bit [31:0] addr);
        int unsigned base = word_base(addr);
        read_word = '0;
        for (int b = 0; b < (MEM_DATA_WIDTH_P / 8); b++)
            read_word[b*8 +: 8] = backing.read_byte(base + b);
    endfunction

    protected function void write_word(bit [31:0] addr,
                                       bit [MEM_DATA_WIDTH_P-1:0] data,
                                       bit [(MEM_DATA_WIDTH_P/8)-1:0] strb);
        int unsigned base = word_base(addr);
        for (int b = 0; b < (MEM_DATA_WIDTH_P / 8); b++)
            if (strb[b]) backing.write_byte(base + b, data[b*8 +: 8]);
    endfunction

    task run_phase(uvm_phase phase);
        bit [1:0]    ready_counter    = '0;
        bit          rsp_pending      = 1'b0;
        int          rsp_countdown    = 0;
        int unsigned read_handshakes  = 0;

        // Counter starts at 0, and the stall pattern only deasserts ready when
        // the counter reaches 1, so ready is high out of reset either way.
        vif.mem_req_ready = 1'b1;
        vif.mem_rsp_valid = 1'b0;
        vif.mem_rsp_rdata = '0;

        forever begin
            @(posedge vif.clk);

            // Reset also drops any in-flight response. The legacy model left
            // its pending flag set across reset, which could strand
            // mem_rsp_valid high if the cache came back up without consuming
            // it; clearing here removes that hazard from the reset-recovery
            // tests rather than relying on the cache to mop it up.
            if (!vif.rst_n) begin
                ready_counter   = '0;
                rsp_pending     = 1'b0;
                rsp_countdown   = 0;
                vif.mem_rsp_valid <= 1'b0;
                vif.mem_req_ready <= 1'b1;
                continue;
            end

            // --- response timing ------------------------------------------
            if (vif.mem_rsp_ready)
                vif.mem_rsp_valid <= 1'b0;

            if (rsp_pending) begin
                if (rsp_countdown == 0) begin
                    vif.mem_rsp_valid <= 1'b1;
                    if (vif.mem_rsp_ready) rsp_pending = 1'b0;
                end else begin
                    rsp_countdown = rsp_countdown - 1;
                end
            end

            // --- request handling -----------------------------------------
            if (vif.mem_req_valid && vif.mem_req_ready) begin
                if (vif.mem_req_write) begin
                    write_word(vif.mem_req_addr, vif.mem_req_wdata, vif.mem_req_wstrb);
                end else begin
                    // Registered read, matching the one-cycle memory model.
                    vif.mem_rsp_rdata <= read_word(vif.mem_req_addr);
                    rsp_pending       = 1'b1;
                    // Latency is derived from the count *before* this request
                    // is tallied, so the varying pattern starts at 0.
                    rsp_countdown     = cfg.mem_rsp_variable_latency ?
                                        (read_handshakes % 4) : cfg.mem_rsp_extra_latency;
                    read_handshakes   = read_handshakes + 1;
                end
            end

            // --- ready back-pressure --------------------------------------
            ready_counter = ready_counter + 1;
            vif.mem_req_ready <= (cfg.mem_ready_stalls == 0) ? 1'b1
                                                            : (ready_counter != 2'd1);
        end
    endtask

endclass
