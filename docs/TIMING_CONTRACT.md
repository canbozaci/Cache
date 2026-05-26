# Cache Timing and Integration Contract

`cache` exposes ready/valid request and response channels on the CPU side and a beat-based native
memory interface. The cache remains internally blocking: it accepts a bounded set of requests,
completes the internal transaction, then returns the matching response before accepting a later
unrelated transaction.

## Clock and Reset

- `clk` is the only cache clock.
- `rst` is synchronous and active high.
- Reset abandons active CPU and native-memory transactions.
- Reset clears valid cache state and deasserts CPU response valid outputs.
- After reset, external requesters must relaunch any abandoned request.

## Instruction Channel

Instruction requests use `instr_req_valid`, `instr_req_ready`, and `instr_req_addr`.

Instruction responses use `instr_rsp_valid`, `instr_rsp_ready`, `instr_rsp_data`, and
`instr_rsp_error`.

Rules:

- A request is accepted on `instr_req_valid && instr_req_ready`.
- The requester must keep `instr_req_addr` stable while `instr_req_valid && !instr_req_ready`.
- The cache holds `instr_rsp_valid`, `instr_rsp_data`, and `instr_rsp_error` stable while
  `instr_rsp_valid && !instr_rsp_ready`.
- `instr_rsp_error=1` reports an error while fetching the requested line. Error response data is
  zero.

## Data Channel

Data requests use `data_req_valid`, `data_req_ready`, `data_req_write`, `data_req_addr`,
`data_req_wdata`, and `data_req_wstrb`.

Data responses use `data_rsp_valid`, `data_rsp_ready`, `data_rsp_rdata`, and `data_rsp_error`.

Rules:

- A request is accepted on `data_req_valid && data_req_ready`.
- `data_req_write=0` is a read.
- `data_req_write=1` is a write-through write.
- Write requests must have nonzero `data_req_wstrb`.
- A single data request must not cross a cache-line boundary.
- Illegal data requests complete with `data_rsp_error=1` and zero read data.
- Data response fields remain stable while `data_rsp_valid && !data_rsp_ready`.

## Simultaneous Requests

The cache supports:

- instruction fetch alone;
- data read alone;
- data write alone;
- simultaneous instruction fetch plus data read.

Simultaneous instruction fetch plus data write is serialized by backpressure: `instr_req_ready` is
deasserted while a data write is being accepted.

## Maintenance

The maintenance interface is unchanged and uses `maint_ready` for command acceptance and
`maint_done` / `maint_error` for completion. Maintenance does not depend on a public `busy` output.

## Native Memory

Native memory timing is defined in `docs/NATIVE_MEMORY_PROTOCOL.md`. Error propagation is defined in
`docs/ERROR_HANDLING.md`.
