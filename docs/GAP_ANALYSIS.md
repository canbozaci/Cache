# Cache Soft-IP Gap Analysis

This file tracks only unresolved gaps for the generic cache IP. Stable baseline and integration details live in:

- `docs/ARCHITECTURE.md` for repository boundaries, public interfaces, maintenance behavior, native memory protocol, and adaptor responsibilities.
- `docs/PARAMETERS.md` for legal parameter ranges, derived widths, supported configurations, and unsupported parameter claims.
- `docs/SRAM_INTEGRATION.md` for ASIC SRAM macro wrapper expectations and project-owned macro adapter hooks.
- `docs/TIMING_CONTRACT.md` for clocks, reset, CPU-side request timing, native memory handshakes, maintenance commands, known coherency limitations, and timing diagrams.
- `docs/VERIFICATION_PLAN.md` for the current regression gates, scoreboard matrix, random runs, block tests, and integration verification responsibilities.

## Fixed Defects

Kept here rather than deleted because each one says something about how this RTL
fails, and the same shapes recur. All were found by the constrained-random
traffic and the checkers added alongside it: the memory write-payload checker
for D1-D3, the duplicate-tag invariant for D5, and the directed configuration
matrix for D6. Every one of them is fixed, with a regression covering it; the
single defect still open is D4, in its own section below.

**D1 — write-through corrupted unaligned stores. Fixed.** For a store at a byte
address that is not a multiple of `MEM_DATA_WIDTH/8`, the write-through path
loaded `ram_addr_l2_data_write` with the raw CPU address, so memory beats went
out on an unaligned address. The two consumers of that address then disagreed:
the strobe generator places byte lane N at slot `(addr%MEM_BYTE_COUNT + N)`,
which assumes the address names a memory word, while `cache.sv` derives the data
shift from `beat_address - store_address`, which is zero when the beat address
carries the offset. The offset was therefore applied twice in the strobes and
not at all in the data, and the lowest byte lanes were never driven onto the
memory bus.

Fixed by masking the address to its memory word at both load points in
`cache_controller.sv`; the existing delta arithmetic then produces the correct
lane shift for every beat. The L1 array had always placed these stores
correctly, which is why the defect was invisible to any read-back that hit in
cache, and why it took a read-back after an invalidate to expose it.

**D2 — the L2 write enable disagreed with its data source. Fixed.** Independent
of D1: it reproduced unchanged after the D1 fix, at the identical time, address
and value.

The L2 port-1 write data is a mux, `mem_rsp_valid_q ? memory beat : l1_data_block`,
but the write enable was qualified by `(write_through | mem_rsp_valid_q)`.
`write_through` stays asserted across the whole write-through pipeline,
*including the line fill that follows a write miss*, so on every cycle of that
fill where `mem_rsp_valid_q` was low the enable was still on while the mux was
handing L2 the L1 line instead of the beat that had just arrived. Each arriving
beat was written correctly and then immediately overwritten.

A probe on the L2 port during the failing store shows it directly: thirteen
consecutive write cycles, of which exactly one carries the intended data and the
rest carry zeros over the top of it. The line ends up valid and tagged with an
all-zero payload, so it answers later misses with zeros and never refetches.

Fixed in `cache.sv` by requiring the selected source to be valid:
`l2_p1_write_source_valid = mem_rsp_valid_q | (&l2_byte_enable_p1)`. A fill
enables one memory beat's worth of bytes at a time; the write-through L2 write
is the only case that enables the whole line at once, which is exactly when
`l1_data_block` is the intended source.

This was invisible to every read-back that L1 answers, which was every read-back
in the suite until now: the line has to leave L1 before L2 is consulted. That is
why it took eviction pressure to surface, and why it first looked like a
maintenance defect — invalidation is simply another way for a line to leave L1.

Minimal reproduction, now a regression test (`cache_write_evict_vseq`):

    global invalidate
    write   0x200 = beefbeefbeefbeef
    read    0x200                      -> correct, answered by L1
    read    0x200 + one L1 way-span    -> fills the set
    read    0x200 + two L1 way-spans   -> evicts the written line from L1
    read    0x200                      -> was 0 with zero memory reads

D1, D2 and the earlier `busy` defect all shared one shape: **a control signal
held across a window in which its associated data is not valid.** `busy` over
the write-through pipeline, the memory write address over an unaligned store,
and the L2 write enable over a fill. D3 is the mirror image --- a control signal
suppressed across a window where it *was* needed --- and D5 is a third variant,
a check disabled in one mode. Worth keeping in mind when reading this RTL: the
recurring fault is the qualifier on a control signal, not the datapath. D6 is
the exception and the most dangerous kind: not a control-signal fault at all,
but a width that silently disagreed with its parameter.

**D3 — the L2 fill way selection was never armed. Fixed.** This one was a
regression introduced by the first attempt at the D2 fix, found by the
1500-access random run inside `make coverage`.

    random[822] TRAF_READ_AND_FETCH/TRAF_ADDR_HOT addr=0x1420
      expected=9d783846fa1ffb3c
      actual  =9d783646fa1ffb3c

`cache_l2_replacement` uses `write_p1` for two different jobs: producing the
per-way write enable, and *arming* a burst — on `ram_write_start` it latches
`fill_active_p1` together with the way the whole fill will use. The first D2 fix
qualified `write_p1` itself, which suppressed the arming pulse as well as the
unwanted write. With no way ever selected, every beat of the following fill was
dropped: the probe showed `we_s1=0, we_s2=0` while the address, byte enables and
data were all correct.

L2 therefore kept a stale copy of the line while L1 and main memory were both
updated, and the stale byte reappeared once L1 evicted the line.

Fixed by moving the qualification from `write_p1` to the byte enables
(`l2_byte_enable_p1_gated`), which suppresses the data without disturbing the
arming or the way selection. The tag and valid bits are still written on those
cycles, which is harmless — the line being tagged is the line being filled.

The regression's random op count is now 1200 per seed rather than 400, because
this defect was invisible below roughly 800 accesses.

**D5 - a fill could install a line that was already resident. Fixed.** Found
while investigating D4, by the duplicate-tag invariant in
`tb/sva/cache_dup_tag_check.sv`. It is not the cause of D4, which reproduces
unchanged with this fixed; it is a separate defect that happened to share the
symptom.

Both levels are two-way, and both chose the way to write like this:

    if (hit_s1 & (~write_L2 | write_through)) ...   // L1
    if (hit_s1_p1 & write_through) ...              // L2 port 1

The qualifier makes the residency check inactive during a fill. A fill of a line
the set already held therefore skipped the hit test, fell through to the LRU
victim, and installed a *second copy of the same tag in the other way*. The L2
instruction port had no residency check at all, so an instruction refill
duplicated unconditionally.

A two-way hit resolves to way 0 --- `cache_set_output_select` is asserted only
for `hit_s2 & ~hit_s1` --- so once a line existed in both ways, way 0 answered
every read and the way-1 copy became unreachable. Any store that landed in way 1
was lost silently until the set was evicted or invalidated.

Fixed by making residency win over the replacement policy unconditionally at
both levels: if the line is already in a way, rewrite that way. `write_L2` and
`write_through` are consequently unused in `cache_l1_replacement` and are kept
on the port list only so the two levels keep matching interfaces.

The invariant that found it now runs in every build. It fires on the cycle the
duplicate is created rather than whenever a read happens to land on the stale
copy, which in the case that motivated it would have been 275 accesses later.

**D6 - line invalidate did nothing on any non-default geometry. Fixed.** The
most severe defect found in this IP, and the one that had gone unnoticed
longest. Found by the directed configuration matrix once it was run again after
the checkers were added.

Both tag/valid arrays tested and cleared the valid bit by selecting bits
straight out of the memory array:

    if (invalidate && mem[invalidate_addr][DATA_WIDTH-1] &&
        (mem[invalidate_addr][DATA_WIDTH-2:0] == invalidate_tag))
      mem[invalidate_addr][DATA_WIDTH-1] <= 1'b0;

Chaining a variable array index with a parameter-width part select resolves the
width from the module's *default* `DATA_WIDTH`, not the overridden one. Printed
from inside the array at `L1_SET_COUNT=32`, where the tag is 10 bits:

    DW=11  $bits(mem[0])=10  mem=0x400  valid=0  tagmatch=0

The parameter says 11, the select uses 10, so the valid bit is read from bit 9
instead of bit 10 and the tag compare comes out false. The same error in the
assignment cleared a tag bit and left the valid bit standing. Routing the word
through a whole-word temporary gives the correct widths:

    $bits(inv_word)=11  inv_word=0x400  msb=1  eq=1

At the default geometry the tag is 9 bits, so `DATA_WIDTH` is 10 either way and
the defect is invisible. At any other tag width `maint_invalidate_line` reported
success while leaving the line valid and resident, and it kept answering hits
with stale data -- confirmed directly: `v0=1 tag0=0 hit=10` after the invalidate
at `L1_SET_COUNT=32`, against `v0=0 hit=00` at the default.

A maintenance operation that reports success and silently does nothing is the
worst failure mode this IP has, and it would have shipped invisible on any
configuration other than the default.

Fixed in `cache_l1_memory_tag_valid_array.sv` and
`cache_l2_memory_tag_valid_array.sv` by reading the stored word into a temporary
and writing it back whole, so no chained select remains on either the read or
the write side. The L2 array had the identical latent defect; it had simply not
been reached at the geometries exercised so far. Both sides had to change --
fixing only the read still failed, because the assignment continued to clear the
wrong bit.

The lesson generalises beyond this IP: **a parameter-width part select chained
onto a variable array index cannot be trusted to use the overridden width.**
Anywhere else this pattern appears it should be rewritten the same way.

## Open Defects

**D4 - a store to a resident line disappeared. Open.** Seed 1, access 99385,
found by the 100k-access soak. One error in 300,000 accesses; seeds 2 and 3 are
clean at 100k each.

    random[99385] TRAF_DATA_READ/TRAF_ADDR_HOT addr=0x1800
      expected=b1b6d110c17b3eac
      actual  =da6c0a2f59cc44be

The full history of line `0x1800` shows the returned value is not stale in any
interesting sense --- it is simply the last value anyone successfully wrote:

    99110  write 0x1800 = da6c0a2f59cc44be  wstrb=0xff
    99130  line invalidate
    99246  line flush
    99299  read  0x1800 -> da6c...           correct
    99314  write 0x1808                      (other word of the same line)
    99334  read  0x1800 -> da6c...           correct
    99344  write 0x1800 = b1b6d110c17b3eac  wstrb=0xff, hit, +0 memory reads
    99372  read  0x1808                      correct
    99385  read  0x1800 -> da6c...           WRONG

Every observation collapses into "access 99344 did not happen". The reads at
99299 and 99334 are correct because nothing had overwritten word 0 since 99110;
the read of `0x1808` at 99372 is correct because that word was written at 99314
and survived. So this is a **lost store**, not a stale or shadowed copy, and the
same shape as the earlier `busy` defect: a store accepted at the interface that
never reaches an array.

**Mechanism, established from a probe on the failing line.** The store was not
lost. It wrote L1 way 1 correctly (`hit=01 we=01 be=0xff`) and emitted both
memory beats. What never happened was the L2 write: no L2 write to that line
appears anywhere in the window, the last one having been 310us earlier. Fifteen
microseconds later L1 lost the line and refilled it *from L2* (`wL2=1`), which
handed back the pre-store word. Main memory held the correct value throughout
and was never consulted, which is why the failing read reports zero memory
reads.

So a write-through hit updated L1 and main memory but skipped L2, and L2 is what
answers the next refill. `cache_wt_l2_check.sv` now asserts this invariant
directly; it was validated by injecting the fault (gating write-through out of
L2's write enable), which made it fire within 9us.

**Not reproducible on demand, and this matters for release.** The failure was
deterministic across three runs of one build, then disappeared when the probe
was extended: identical stimulus, but the schedule shifted 0.5% (access 99385 at
50.17ms rather than 50.41ms) and the defect fell out of its window. Testbench
changes perturb the memory responder's random delays, so the defect cannot be
instrumented further by adding signals.

What has been tried since, all clean:

- 100000 random accesses over four seeds with the invariant checker compiled in
- `cache_wt_l2_vseq`, a directed sweep of 128 combinations per run: the line's
  maintenance history (invalidate, flush, both, neither), store order and width
  across the two words of the line, and instruction-port concurrency
- that sequence re-run across nine memory responder timing configurations
  (extra latency 0/1/3 x ready stalls 0/1/2, variable latency on)

The trigger is therefore narrower than any of those dimensions. Two
write-through hits to the same line thirty accesses apart behaved differently in
the failing trace, and what separated them is still unknown.

The original failing binary is preserved at `sim/build/uvm_probesmoke/uvm_sim`
and reproduces with `+TRAFFIC_OPS=99400 +verilator+seed+1 +PROBE_LINE=1800`. `tb/sva/cache_store_probe.sv` --- a temporary, opt-in
single-line trace armed with `+PROBE_LINE=<addr>` --- logs the CPU port, both L1
and L2 way write-enables with their byte enables, and the memory write beats, to
answer exactly that.

Note that none of the interface assertions can see this defect: the write was
accepted, `busy` behaved, and no protocol rule was broken.

## Remaining Design Gaps

- Data widths above 128 bits are not release-supported yet.
- A write burst always opens at beat 0 but is only as long as its highest
  strobed beat, so a store confined to an upper beat spends a bus cycle with
  `mem_req_wstrb == 0`. Harmless against a strobe-honouring memory, but a bus
  without byte enables cannot express it. Counted by the `c_write_beat_no_strobe`
  functional bin.

## Remaining Verification Gaps

- No parameter legality checks in the RTL: `docs/PARAMETERS.md` states the legal
  ranges, and nothing enforces them, so an illegal configuration elaborates into
  broken hardware rather than failing the build.
- Random traffic keeps data and instruction accesses in disjoint regions, so the
  documented I/D incoherency case is exercised only by the directed sequence.
- Random stores are naturally aligned, so D1's path is reached only by the
  directed write sequence.

## Priority Plan

P0 before first real version:

- Confirm whether a write miss should leave the line resident in L2. Since the
  D2 fix the read after eviction refetches from main memory rather than being
  answered by L2, so a write-missed line is not L2-resident until something
  reads it. That is correct but possibly slower than intended; it was previously
  masked because the line *was* installed, holding zeros.
- Keep `make verify` passing after every update. It runs in CI on every push
  and pull request.
- Keep release collateral aligned with the current public IP contract.

P1 for stronger bus-width genericity:

- Add parameter checks for illegal combinations.
- Add scoreboard coverage for `DATA_WIDTH` values above 128 bits when needed.
- Sweep more L1/L2 set counts. D6 was a geometry-dependent defect that the
  default configuration could not expose, so breadth here has already paid for
  itself once.
- Extend random traffic to unaligned stores. D1 is fixed, so this is no
  longer blocked.

P2 before release maturity:

- Raise RTL toggle coverage, which `make coverage` reports well below line and
  branch coverage.
