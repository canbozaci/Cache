# Native Memory Protocol

The native memory side is a single-clock, one-outstanding, beat-based interface. It is not AXI, AHB,
TileLink, or Wishbone. Bus adaptation belongs outside this repository.

## Request Channel

A memory beat is accepted on `mem_req_valid && mem_req_ready`.

Request fields:

- `mem_req_write`: read when `0`, write when `1`.
- `mem_req_burst`: asserted for multi-beat cache transactions.
- `mem_req_burst_len`: total number of beats in the cache transaction.
- `mem_req_beat_index`: zero-based beat index.
- `mem_req_burst_start`: asserted on beat zero of a multi-beat transaction.
- `mem_req_burst_last`: asserted on the final beat of a multi-beat transaction.
- `mem_req_addr`: byte address for this beat.
- `mem_req_wdata`: write data for this beat.
- `mem_req_wstrb`: write byte strobes for this beat.

The cache issues one logical native memory transaction at a time and does not use request IDs.

## Read Response Channel

Read responses use `mem_rd_rsp_valid`, `mem_rd_rsp_ready`, `mem_rd_rsp_rdata`, and
`mem_rd_rsp_error`.

Rules:

- A read response beat is accepted on `mem_rd_rsp_valid && mem_rd_rsp_ready`.
- Read responses must return in request order.
- One accepted read request beat must produce exactly one read response beat.
- `mem_rd_rsp_error=1` marks the current line fill as failed.

## Write Response Channel

Write responses use `mem_wr_rsp_valid`, `mem_wr_rsp_ready`, and `mem_wr_rsp_error`.

Rules:

- A write response beat is accepted on `mem_wr_rsp_valid && mem_wr_rsp_ready`.
- One accepted write request beat must produce exactly one write response beat.
- A data-side write-through request is not complete until all corresponding write responses have
  been accepted.
- Any asserted `mem_wr_rsp_error` completes the data response with `data_rsp_error=1`.
