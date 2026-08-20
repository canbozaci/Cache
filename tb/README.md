# Cache UVM Testbench

UVM environment for the `cache` soft IP. Replaces the directed module
testbenches that previously lived in this directory.

## Requirements

- Verilator >= 5.046 (UVM support; this was developed against 5.050)
- Accellera `uvm-core` sources, with `UVM_HOME` pointing at their `src/`
  directory. Compiled with `+define+UVM_NO_DPI`.

**Distribution packages are generally too old.** Debian and Ubuntu currently
ship 5.020, which does not implement `##` cycle delays in sequence expressions
at all. Three checks here use them -- `a_line_maint_needs_addr` in
`sva/cache_sva.sv`, and the `c_req_back_to_back` and
`c_maint_retires_after_traffic` bins in `cov/cache_cov.sv` -- so on 5.020 the
build fails to elaborate rather than degrading gracefully. CI therefore builds
Verilator from source pinned to the version above; see
`.github/workflows/ci.yml`.

## Two environments

`tb/` holds the cache-level environment: the `cache` top is the DUT, and the
tests exercise its public contract.

`tb/block/` holds a separate block-level environment whose DUTs are the leaf
modules themselves — there is no cache instance in it at all. It has its own
interface, package, top and test. It exists because the cache-level environment
can only reach the submodules through the cache's behaviour, which leaves
internal decisions like replacement-way selection and byte-lane placement
observable only indirectly.

Its agent has a driver but no monitor. The leaf DUTs have no handshake and
several are combinational, so the sampling instant is defined by the stimulus;
an independent monitor could only re-derive the driver's timing rather than
check it. The comparison still lives in a scoreboard.

## Layout

```text
cache_if.sv                 DUT pin bundle
cache_pkg.sv                geometry parameters + include manifest
tb_top.sv                   clock, DUT instance, power-on reset, checkers, run_test
agents/data_agent/          CPU data port master
agents/instr_agent/         CPU instruction port master
agents/maint_agent/         maintenance port master
agents/mem_agent/           native memory port reactive slave + backing memory
env/                        reference model, scoreboard, burst checker, env
seq/                        stimulus, one sequence per contract, plus random traffic
sva/                        protocol assertions
cov/                        functional coverage bins
tests/                      base test + full regression + random traffic test
block/                      block-level environment for the leaf modules
```

## Assertions and coverage

`sva/cache_sva.sv` holds the protocol assertions and `cov/cache_cov.sv` the
functional coverage bins. Both are instantiated from `tb_top` against the
interface rather than `bind`-ed into the DUT: binding a module that imports
`uvm_pkg` makes Verilator 5.050 re-elaborate the UVM package inside every
parameterized submodule and abort. Every signal they check is an interface
signal, so an ordinary instance sees the same thing.

Assertion failures are reported through the UVM report server, so they count as
`UVM_ERROR` and suppress the pass banner. A bare `$error` would leave a failing
run reporting success.

The functional bins are SVA `cover property` directives rather than covergroups,
because Verilator implements the former under `--coverage-user` and does not
implement covergroups at all.

`make coverage` builds an instrumented model, runs the directed suite, a random
soak and a stalled-memory soak, and reports RTL line/branch/toggle coverage plus
every functional bin with its hit count. It is deliberately not part of
`make verify`: the regression answers "does it still pass", and this answers
"against how much".

## Why the environment is shaped this way

**Four agents, one of them reactive.** The cache is a master on its memory
port, so `mem_agent` has no sequencer — it answers traffic rather than
originating it. It also owns the backing memory, because the memory model and
the response timing are the same state machine.

**No parameterized classes.** Cache geometry changes port widths, field widths
and the beat structure of every burst, so a simulation is tied to one geometry
regardless. Geometry arrives as `+define+CACHE_*` and the configuration matrix
recompiles per case. Knobs that *don't* change widths — memory ready stalls,
response latency — are runtime instead, in `cache_env_cfg`, driven by plusargs,
so those cases reuse one build.

**Two copies of the reference memory.** `cache_ref_model` is instantiated
twice: once as the scoreboard's oracle, updated from observed CPU writes, and
once as the memory responder's backing store, updated from observed memory
writes. Both power up holding the same generated pattern (`word W` =
`32'h1000_0000 ^ W`), so no memory image is needed and a write-through defect
shows up as divergence between them on the next miss.

**Contracts checked through memory traffic, not just data.** The cache exposes
no hit/miss signal, and several of its guarantees are invisible in the data:
a broken replacement policy still returns correct values, it just evicts the
wrong way. Sequences therefore snapshot `ctx.mem_read_count` around a step and
assert on whether a memory read occurred. That is what makes the replacement,
line-maintenance and queued-maintenance tests meaningful.

**Raw signal access instead of clocking blocks.** Drivers apply stimulus on
`negedge` and everything samples on `posedge` in the Active region, which is
the timing discipline the RTL was written against. A monitor clocking block
would sample in the Preponed region and shift `busy` observation by a cycle
relative to the drivers — and since `busy` is the *only* back-pressure signal
for both CPU ports, the drivers and monitors have to agree on it exactly.
`cache_sync` holds that shared timing so it is defined once.

**Reset is not an agent.** It is a testbench-wide event, driven by
`cache_base_vseq`. Drivers and monitors are reset-aware: a mid-transaction
reset aborts the in-flight item and the monitor discards the observation rather
than checking a response that was never produced. That is what allows the
reset-during-transaction contract to be tested at all.

## Running

```sh
make uvm-smoke        # default configuration
make uvm-scoreboard   # directed configuration matrix
make uvm-random       # seeded random geometries, directed stimulus
make uvm-traffic      # constrained-random stimulus, fixed geometry
make uvm-soak         # long random traffic over six seeds
make coverage         # instrumented build, RTL and functional coverage report
make block-tests      # block-level environment
make verify           # everything except the soak and coverage
```

`uvm-random` and `uvm-traffic` randomise different axes and neither substitutes
for the other: the first runs the directed suite against many geometries, the
second runs unplanned stimulus against one. Thirty directed accesses cannot
produce an eviction landing on a queued invalidate however many shapes they run
in.

**Run length is load-bearing.** `uvm-traffic` uses 1200 accesses per seed
because that is what the design has been shown to need, not a round number: the
defect recorded as D3 in docs/GAP_ANALYSIS.md first appeared at access 822 and
was invisible below roughly 800. Two of the four defects found while this
environment was being built were reachable only by random traffic, and one of
them was a regression introduced by the fix for another — which is the argument
for keeping this length rather than trimming it for runtime.

Random traffic seeds are explicit, so a failure reproduces exactly:

```sh
TRAFFIC_SEEDS=2 TRAFFIC_OPS=1200 ./scripts/run_traffic.sh
```

`cache_random_test` accepts `+TRAFFIC_OPS=<n>`, and long runs need
`+WATCHDOG_MS=<n>` raised above the 5 ms default.

Single case, directly:

```sh
./scripts/run_uvm_tb.sh default
./scripts/run_uvm_tb.sh dw32 +define+CACHE_DATA_WIDTH=32
REUSE_BUILD=default ./scripts/run_uvm_tb.sh stalls -- +MEM_READY_STALLS=1
```

Waveforms: add `-- +DUMP` to write `sim/build/waves.fst`.

Reproducing a random failure: the seed is printed as `RANDOM UVM SEED: <n>`;
re-run with `RANDOM_SEED=<n> make uvm-random`.

## Sequences

| Sequence | Contract |
|---|---|
| `cache_maint_vseq` | global flush and invalidate retire successfully |
| `cache_illegal_maint_vseq` | every illegal request combination returns `maint_error` |
| `cache_line_maint_vseq` | line invalidate is precise; line flush is a write-through no-op |
| `cache_busy_maint_vseq` | maintenance issued mid-miss is queued, not rejected |
| `cache_reset_vseq` | reset mid-transaction, and repeated short resets, recover |
| `cache_replacement_vseq` | L1 evicts the least recently used way |
| `cache_id_incoherency_vseq` | the documented I/D incoherency limitation holds |
| `cache_write_vseq` | write-through across strobe and memory-beat boundaries |
| `cache_concurrent_vseq` | fetch and read together across the whole miss/hit matrix |
| `cache_write_invalidate_vseq` | a written line survives in memory across a line invalidate |
| `cache_full_vseq` | all of the above, in an order the state depends on |
| `cache_random_vseq` | constrained-random traffic; checks nothing itself |

The step order inside `cache_full_vseq` is load-bearing: the line-maintenance
and queued-maintenance checks need particular lines resident. Reordering them
would not fail, it would silently stop testing what they claim to test.
