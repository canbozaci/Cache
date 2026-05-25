# Cache Timing and Integration Contract

This document freezes the public timing contract for the generic `cache` top. It describes the current RTL behavior that CPU and memory adaptors must obey.

## Clock and Reset

- `cache` has one clock input, `clk`.
- `rst` is synchronous and active high.
- While `rst` is high, request, maintenance, and memory response inputs should be driven inactive.
- A reset can be asserted during an active cache transaction. The active transaction is abandoned, internal valid state is cleared, `busy` returns low after reset recovery, and external logic may retry the command.
- Repeated reset pulses are legal when each pulse is synchronous to `clk`.
- The native memory interface has no separate memory clock. Any crossing to a different memory clock domain belongs in a memory adaptor.

## CPU-Side Request Contract

The CPU-side interface is command-style and has no per-port ready signal. A CPU adaptor must use `busy` as the cache-level back-pressure signal.

- A new instruction or data command may be launched only when `busy == 0`.
- After launching a command, the adaptor must keep that command and its address/data/strobe inputs stable until `busy` returns to `0`.
- If `busy` never asserts for a hit, the command still occupies the launch cycle and the following response cycle.
- A command is complete when `busy` is `0` after the launch cycle has been sampled.
- `instr_resp_data` and `data_resp_rdata` are valid when the corresponding command completes.
- The cache accepts at most one data command and one instruction command from an idle launch cycle.
- `data_req_read` and `data_req_write` must not be asserted together.
- A data write with all byte strobes deasserted is not a useful transaction and should not be issued.
- A single data request must not cross a cache-line boundary. CPU adaptors must split such transfers before they reach `cache`.

Instruction fetches use:

- `instr_req_valid`
- `instr_req_addr`
- `instr_resp_data`

Data requests use:

- `data_req_read`
- `data_req_write`
- `data_req_addr`
- `data_req_wdata`
- `data_req_wstrb`
- `data_resp_rdata`

## Simultaneous Commands

Legal simultaneous command cases from an idle launch cycle are:

| Instruction command | Data command | Contract |
| --- | --- | --- |
| None | None | Idle. |
| Fetch | None | Legal. Completion is indicated by `busy` returning low. |
| None | Read | Legal. Completion is indicated by `busy` returning low. |
| None | Write | Legal. Completion is indicated by `busy` returning low. |
| Fetch | Read | Legal. The cache arbitrates any shared memory traffic internally. Both responses are valid when `busy` returns low. |
| Fetch | Write | Not release-supported. Adaptors should serialize this case. |

Instruction fetch with data read is covered by the scoreboard. Instruction fetch with data write is not a released simultaneous command because the instruction and data L1s are not coherent after data-side writes.

## Native Memory Request Contract

The native memory side is a single-clock ready/valid interface driven by the cache.

- `mem_req_valid` qualifies all `mem_req_*` request fields.
- The memory adaptor accepts one memory beat on `mem_req_valid && mem_req_ready`.
- While `mem_req_valid` is high and `mem_req_ready` is low, all `mem_req_*` fields must be treated as stable.
- The cache issues at most one logical memory transaction at a time.
- Writes complete when their request beats are accepted.
- Reads complete when the matching response beats are provided on `mem_rsp_valid`.

Request fields:

- `mem_req_write`: `0` for read, `1` for write.
- `mem_req_addr`: byte address for this beat.
- `mem_req_wdata`: write data for this beat.
- `mem_req_wstrb`: write byte enables for this beat.
- `mem_req_burst`: asserted for multi-beat cache transactions.
- `mem_req_burst_len`: total beat count for the cache transaction.
- `mem_req_beat_index`: zero-based beat number.
- `mem_req_burst_start`: asserted on beat zero of a multi-beat transaction.
- `mem_req_burst_last`: asserted on the final beat of a multi-beat transaction.

The generic cache emits one native memory beat per handshake. Bus-specific burst encoding, coalescing, IDs, locks, exclusives, protection, and CDC belong in a memory adaptor.

## Native Memory Response Contract

- `mem_rsp_ready` is currently tied high by the cache.
- `mem_rsp_valid` qualifies `mem_rsp_rdata`.
- Read responses must return in request order.
- A memory adaptor may add arbitrary response latency as long as each accepted read beat eventually receives exactly one response beat.
- Write responses are not part of the native cache contract.

## Maintenance Contract

Maintenance commands use:

- `maint_flush_req`
- `maint_invalidate_req`
- `maint_flush_line_req`
- `maint_invalidate_line_req`
- `maint_addr_valid`
- `maint_addr`
- `maint_ready`
- `maint_done`
- `maint_error`

Rules:

- A maintenance command may be launched when `maint_ready == 1`.
- The maintenance command inputs must remain stable for the launch cycle.
- The cache has one fixed maintenance queue entry.
- A maintenance command accepted during active cache traffic executes after the active traffic drains.
- `maint_done` pulses for one cycle when a legal maintenance command completes.
- `maint_error` pulses for one cycle when an illegal maintenance command is accepted and retired.
- `busy` remains high while a maintenance command is queued or executing.

Legal maintenance commands:

| Command | Address required | Behavior |
| --- | --- | --- |
| `maint_flush_req` | No | Legal write-through no-op. |
| `maint_invalidate_req` | No | Clears cache valid state globally. |
| `maint_flush_line_req` | Yes | Legal write-through no-op for `maint_addr`. |
| `maint_invalidate_line_req` | Yes | Invalidates matching L1 data, L1 instruction, and L2 entries for `maint_addr`. |

Illegal combinations return `maint_error`:

- More than one global maintenance request in the same command.
- More than one line maintenance request in the same command.
- Any global request asserted with any line request.
- Any line request without `maint_addr_valid`.

## Known Coherency Limitation

The instruction L1 and data L1 are intentionally not coherent with each other after data-side writes.

If software or an integration writes data that may later be fetched as instructions, it must issue an address-selective line invalidate or a global invalidate before fetching that address through the instruction side. The scoreboard locks this contract by checking that an already-filled instruction line remains stale after a data-side write until line invalidate forces a refill.

## Timing Diagrams

The diagrams below use one column per rising edge. `X` means the command is held stable by the requester.

### Read Hit

```text
cycle          N      N+1
busy           0       0
data_req_read  1       0
data_req_addr  X       -
data_resp      -       valid
mem_req_valid  0       0
```

### Read Miss

```text
cycle          N      N+1 ... N+k      N+k+1
busy           0       1       1        0
data_req_read  1       1       1        0
data_req_addr  X       X       X        -
mem_req_valid  0       R       R        0
mem_rsp_valid  0       0/R     R        0
data_resp      -       -       -        valid
```

### Instruction Miss

```text
cycle             N      N+1 ... N+k      N+k+1
busy              0       1       1        0
instr_req_valid   1       1       1        0
instr_req_addr    X       X       X        -
mem_req_valid     0       R       R        0
mem_rsp_valid     0       0/R     R        0
instr_resp_data   -       -       -        valid
```

### Data Write Hit

```text
cycle           N      N+1 ... N+k      N+k+1
busy            0       1       1        0
data_req_write  1       1       1        0
data_req_addr   X       X       X        -
data_req_wdata  X       X       X        -
data_req_wstrb  X       X       X        -
mem_req_valid   0       W       W        0
```

### Data Write Miss

```text
cycle           N      N+1 ... N+k ... N+m      N+m+1
busy            0       1       1       1        0
data_req_write  1       1       1       1        0
data_req_*      X       X       X       X        -
mem_req_valid   0       W       R/W     R        0
mem_rsp_valid   0       0       0/R     R        0
```

The write-through request is emitted to native memory. If the line is missing locally, the cache also refills the line before completing.

### Simultaneous Instruction Fetch and Data Read

```text
cycle             N      N+1 ... N+k      N+k+1
busy              0       1       1        0
instr_req_valid   1       1       1        0
data_req_read     1       1       1        0
instr_req_addr    X       X       X        -
data_req_addr     X       X       X        -
mem_req_valid     0       R       R        0
instr_resp_data   -       -       -        valid
data_resp_rdata   -       -       -        valid
```
