// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

typedef enum int {
    TRAF_DATA_READ               = 0,
    TRAF_DATA_WRITE              = 1,
    TRAF_INSTR_FETCH             = 2,
    TRAF_READ_AND_FETCH          = 3,
    TRAF_MAINT_GLOBAL_INVALIDATE = 4,
    TRAF_MAINT_GLOBAL_FLUSH      = 5,
    TRAF_MAINT_LINE_INVALIDATE   = 6,
    TRAF_MAINT_LINE_FLUSH        = 7,
    TRAF_MAINT_WHILE_BUSY        = 8,
    TRAF_RESET                   = 9
} cache_traffic_op_e;

// How an address is chosen. This matters more than the op mix: a uniformly
// random address over a large space almost never revisits a set, so it
// exercises refill and very little else.
typedef enum int {
    TRAF_ADDR_HOT   = 0,  // a handful of sets, hammered until they thrash
    TRAF_ADDR_LOCAL = 1,  // any set, first two aliases only, so it mostly hits
    TRAF_ADDR_ANY   = 2   // uniform over the region
} cache_traffic_addr_mode_e;

// One randomly generated cache access.
//
// Addresses are built from geometry rather than drawn flat, because what makes
// a cache misbehave is set pressure, and set pressure is a function of the
// index bits. An address here is `alias * stride + set * line + offset`, where
// `stride` is exactly the span of one L1 way — so two items with the same
// `set_index` and different `alias_index` are guaranteed to collide in the same
// set with different tags. With more aliases in the region than there are ways,
// picking a few hot sets produces back-to-back evictions on purpose instead of
// by luck.
//
// The data and instruction regions are disjoint. That is not tidiness: the IP
// documents its L1s as non-coherent after a data-side write, so an address
// written through the data port and later fetched through the instruction port
// has no single correct answer. Directed tests pin that case down deliberately
// (cache_id_incoherency_vseq); random traffic has to stay out of it, or the
// scoreboard would be checking an expectation the contract does not promise.
//
// ---- On why the weighted choices are not `dist` constraints ----------------
//
// They were, and the weights were silently ignored. Measured against Verilator
// 5.050, `op dist { A := 30, B := 26, C := 44 }` over 300 draws produced
// 109/107/84 — a uniform draw with the weights discarded, not a weighted one.
// In this sequence that turned a read/write/fetch mix into a flat pick over ten
// enum values, so half of every run was maintenance and some runs contained no
// stores at all. A run like that still passes, which is the worst kind of
// wrong: the regression stays green while the stimulus stops covering the write
// path entirely.
//
// The cumulative tables below do the weighting explicitly. Range and alignment
// constraints stay declarative, because those the solver does handle — and
// post_randomize re-checks the addresses it produced, so if that ever stops
// being true the run fails loudly instead of quietly testing nothing.
class cache_traffic_item extends uvm_object;

    // ---- geometry-derived layout ----------------------------------------
    static const int unsigned LINE_BYTES = LINE_WIDTH_P / 8;
    static const int unsigned DATA_BYTES = DATA_WIDTH_P / 8;

    // Half the reference memory for data, half for instructions. Both halves
    // are a whole number of L1 way-spans for every supported geometry, since a
    // way-span is a power of two no larger than 2 KiB.
    static const int unsigned REGION_BYTES      = cache_ref_model::REF_BYTES / 2;
    static const int unsigned INSTR_REGION_BASE = REGION_BYTES;

    static const int unsigned DATA_STRIDE   = L1_DATA_SET_COUNT_P  * LINE_BYTES;
    static const int unsigned INSTR_STRIDE  = L1_INSTR_SET_COUNT_P * LINE_BYTES;
    static const int unsigned DATA_ALIASES  = REGION_BYTES / DATA_STRIDE;
    static const int unsigned INSTR_ALIASES = REGION_BYTES / INSTR_STRIDE;

    // L1 is two-way, so three aliases of one set already force an eviction.
    // Four hot sets keeps the pressure high without collapsing the run into a
    // single set, which would stop exercising index decode.
    static const int unsigned HOT_SETS = 4;

    // ---- weighted choices, indexed by the enum encodings above -----------
    // Dynamic rather than fixed-size arrays so one helper can walk either: a
    // fixed-size unpacked array is not an allowed `ref` argument type.
    static int unsigned OP_WEIGHT[] = '{
        30,  // TRAF_DATA_READ
        26,  // TRAF_DATA_WRITE
        20,  // TRAF_INSTR_FETCH
        10,  // TRAF_READ_AND_FETCH
         2,  // TRAF_MAINT_GLOBAL_INVALIDATE
         1,  // TRAF_MAINT_GLOBAL_FLUSH
         4,  // TRAF_MAINT_LINE_INVALIDATE
         3,  // TRAF_MAINT_LINE_FLUSH
         3,  // TRAF_MAINT_WHILE_BUSY
         1   // TRAF_RESET
    };
    static int unsigned ADDR_MODE_WEIGHT[] = '{50, 25, 25};

    // Chosen in pre_randomize rather than solved for. They are plain state
    // variables by the time constraints are solved, so the implications below
    // still select the right address ranges.
    cache_traffic_op_e        op;
    cache_traffic_addr_mode_e addr_mode;

    rand int unsigned set_index;
    rand int unsigned alias_index;
    rand int unsigned offset;

    rand int unsigned instr_set_index;
    rand int unsigned instr_alias_index;
    rand int unsigned instr_offset;

    rand bit [DATA_WIDTH_P-1:0] wdata;
    rand int unsigned           reset_cycles;

    // Shaped in post_randomize; see build_wstrb.
    bit [(DATA_WIDTH_P/8)-1:0] wstrb;

    constraint c_set_index {
        set_index < L1_DATA_SET_COUNT_P;
        instr_set_index < L1_INSTR_SET_COUNT_P;
        (addr_mode == TRAF_ADDR_HOT) -> set_index < HOT_SETS;
        (addr_mode == TRAF_ADDR_HOT) -> instr_set_index < HOT_SETS;
    }

    constraint c_alias_index {
        alias_index < DATA_ALIASES;
        instr_alias_index < INSTR_ALIASES;
        // A working set small enough to fit in the ways, so this mode mostly
        // hits and exercises the hit path and the replacement policy's LRU
        // update rather than the fill path.
        (addr_mode == TRAF_ADDR_LOCAL) -> alias_index < 2;
        (addr_mode == TRAF_ADDR_LOCAL) -> instr_alias_index < 2;
    }

    // Naturally aligned and inside one line: a single request may not cross a
    // line boundary, and performing that split is the CPU adaptor's job by
    // contract.
    constraint c_offset {
        offset < LINE_BYTES;
        offset % DATA_BYTES == 0;
        instr_offset < LINE_BYTES;
        instr_offset % 4 == 0;
    }

    constraint c_reset_cycles { reset_cycles inside {[2:6]}; }

    `uvm_object_utils_begin(cache_traffic_item)
        `uvm_field_int(set_index, UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(alias_index, UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(offset, UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(wdata, UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(wstrb, UVM_DEFAULT | UVM_HEX)
    `uvm_object_utils_end

    function new(string name = "cache_traffic_item");
        super.new(name);
    endfunction

    // ---- weighted selection ---------------------------------------------

    protected static function int unsigned weighted_pick(input int unsigned weights[]);
        int unsigned total = 0;
        int unsigned draw;
        int unsigned running = 0;
        for (int unsigned i = 0; i < weights.size(); i++) total += weights[i];
        draw = $urandom_range(total - 1, 0);
        for (int unsigned i = 0; i < weights.size(); i++) begin
            running += weights[i];
            if (draw < running) return i;
        end
        return 0;
    endfunction

    function void pre_randomize();
        super.pre_randomize();
        op        = cache_traffic_op_e'(weighted_pick(OP_WEIGHT));
        addr_mode = cache_traffic_addr_mode_e'(weighted_pick(ADDR_MODE_WEIGHT));
    endfunction

    // Byte strobes are shaped rather than drawn flat. A uniform nonzero pattern
    // is almost never all-ones and almost never a single byte, but those two
    // are the ends of the byte-enable mapping and the ones a write-through has
    // to get right; a gapped pattern is what splits a store across memory beats
    // discontiguously.
    protected function bit [(DATA_WIDTH_P/8)-1:0] build_wstrb();
        // Widths come from the package parameter rather than the DATA_BYTES
        // shorthand: a static class constant is not constant enough to size a
        // cast with.
        bit [(DATA_WIDTH_P/8)-1:0] one  = 1;
        int unsigned               kind = $urandom_range(99, 0);
        int unsigned               lo, hi;

        if (kind < 30) begin
            return '1;                                        // full width
        end else if (kind < 55) begin
            return one << $urandom_range(DATA_BYTES - 1, 0);   // single byte
        end else if (kind < 80) begin
            lo = $urandom_range(DATA_BYTES - 1, 0);            // contiguous run
            hi = $urandom_range(DATA_BYTES - 1, lo);
            build_wstrb = '0;
            for (int unsigned b = lo; b <= hi; b++) build_wstrb[b] = 1'b1;
            return build_wstrb;
        end else begin
            do build_wstrb = (DATA_WIDTH_P/8)'($urandom());    // arbitrary, gaps and all
            while (build_wstrb == '0);
            return build_wstrb;
        end
    endfunction

    function void post_randomize();
        super.post_randomize();
        wstrb = build_wstrb();
        check_addresses();
    endfunction

    // The stimulus is only as trustworthy as the solver that produced it, and
    // this environment has already been bitten once by a constraint that was
    // accepted and then not honoured. Re-deriving the contract here costs
    // nothing per item and turns any future solver regression into a failed run
    // rather than a quietly degraded one.
    protected function void check_addresses();
        bit [ADDR_WIDTH_P-1:0] da = data_addr();
        bit [ADDR_WIDTH_P-1:0] ia = instr_addr();

        if ((32'(da) + DATA_BYTES) > REGION_BYTES)
            `uvm_error("TRAFFIC_ADDR",
                       $sformatf("data address 0x%0h escapes the data region [0,0x%0h)",
                                 da, REGION_BYTES))
        if ((32'(da) % DATA_BYTES) != 0)
            `uvm_error("TRAFFIC_ADDR",
                       $sformatf("data address 0x%0h is not %0d-byte aligned", da, DATA_BYTES))
        if (((32'(da) % LINE_BYTES) + DATA_BYTES) > LINE_BYTES)
            `uvm_error("TRAFFIC_ADDR",
                       $sformatf("data access at 0x%0h crosses a cache line", da))
        if ((32'(ia) < INSTR_REGION_BASE) ||
            ((32'(ia) + 4) > (INSTR_REGION_BASE + REGION_BYTES)))
            `uvm_error("TRAFFIC_ADDR",
                       $sformatf("instruction address 0x%0h escapes the instruction region", ia))
        if ((32'(ia) % 4) != 0)
            `uvm_error("TRAFFIC_ADDR",
                       $sformatf("instruction address 0x%0h is not word aligned", ia))
    endfunction

    // ---- derived addresses ----------------------------------------------

    function bit [ADDR_WIDTH_P-1:0] data_addr();
        return ADDR_WIDTH_P'(alias_index * DATA_STRIDE + set_index * LINE_BYTES + offset);
    endfunction

    function bit [ADDR_WIDTH_P-1:0] instr_addr();
        return ADDR_WIDTH_P'(INSTR_REGION_BASE +
                             instr_alias_index * INSTR_STRIDE +
                             instr_set_index * LINE_BYTES + instr_offset);
    endfunction

    // Line-aligned form of the data address, for line maintenance commands.
    function bit [ADDR_WIDTH_P-1:0] data_line_addr();
        return ADDR_WIDTH_P'(alias_index * DATA_STRIDE + set_index * LINE_BYTES);
    endfunction

endclass
