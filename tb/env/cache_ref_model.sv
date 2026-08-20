// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Byte-accurate reference memory shared by the scoreboard (as the expected-value
// oracle) and the memory-side responder (as its backing store).
//
// Both start from the same generated pattern, which is what makes a read
// checkable without preloading an image: word W holds 32'h1000_0000 ^ W. The
// two copies then diverge only through the DUT: the scoreboard's copy is
// updated from observed CPU writes, the responder's from observed memory
// writes. A write-through bug shows up as a mismatch between them on the next
// read that misses.
class cache_ref_model extends uvm_object;

    // Matches the legacy tb REF_BYTES. Addresses at or above this read as zero
    // in the oracle, so tests must stay inside it.
    static const int unsigned REF_BYTES = 16384;

    // Sparse so a 21-bit address space costs nothing until touched.
    protected byte unsigned mem[int unsigned];

    `uvm_object_utils(cache_ref_model)

    function new(string name = "cache_ref_model");
        super.new(name);
    endfunction

    // The power-on pattern for a single byte, derived rather than stored.
    static function byte unsigned pattern_byte(int unsigned byte_addr);
        int unsigned word_index = byte_addr >> 2;
        bit [31:0]   word_value = 32'h1000_0000 ^ word_index;
        return word_value[(byte_addr % 4) * 8 +: 8];
    endfunction

    virtual function byte unsigned read_byte(int unsigned byte_addr);
        if (mem.exists(byte_addr)) return mem[byte_addr];
        return pattern_byte(byte_addr);
    endfunction

    virtual function void write_byte(int unsigned byte_addr, byte unsigned value);
        mem[byte_addr] = value;
    endfunction

    // Oracle read of a DATA_WIDTH-wide CPU load. Bytes past REF_BYTES read as
    // zero, mirroring the legacy read_reference64 bound check.
    virtual function bit [DATA_WIDTH_P-1:0] read_data(int unsigned byte_addr);
        read_data = '0;
        for (int lane = 0; lane < (DATA_WIDTH_P / 8); lane++) begin
            int unsigned a = byte_addr + lane;
            if (a < REF_BYTES) read_data[lane*8 +: 8] = read_byte(a);
        end
    endfunction

    // Oracle read of a 32-bit instruction fetch.
    virtual function bit [31:0] read_instr(int unsigned byte_addr);
        read_instr = '0;
        for (int lane = 0; lane < 4; lane++) begin
            int unsigned a = byte_addr + lane;
            if (a < REF_BYTES) read_instr[lane*8 +: 8] = read_byte(a);
        end
    endfunction

    // Apply a strobed CPU store to the oracle.
    virtual function void apply_write(int unsigned byte_addr,
                                      bit [DATA_WIDTH_P-1:0] wdata,
                                      bit [(DATA_WIDTH_P/8)-1:0] wstrb);
        for (int lane = 0; lane < (DATA_WIDTH_P / 8); lane++) begin
            int unsigned a = byte_addr + lane;
            if (wstrb[lane] && (a < REF_BYTES)) write_byte(a, wdata[lane*8 +: 8]);
        end
    endfunction

endclass
