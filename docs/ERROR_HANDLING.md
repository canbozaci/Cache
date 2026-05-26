# Error Handling

The cache reports CPU-side errors through `instr_rsp_error` and `data_rsp_error`.

## Read Errors

If any native read response beat for a line fill has `mem_rd_rsp_error=1`:

- the full line fill fails;
- the cache does not mark the filled line valid;
- the matching CPU response completes with error set;
- response data is zero;
- the cache recovers and can accept later requests.

## Write Errors

For write-through data writes:

- the cache waits for all native write responses for the write beats;
- if any write response has `mem_wr_rsp_error=1`, the data response completes with
  `data_rsp_error=1`;
- if all write responses succeed, the data response completes with `data_rsp_error=0`.

## Illegal CPU Requests

The cache rejects data writes with all byte strobes cleared and data requests that cross a
cache-line boundary. Rejected requests complete on the data response channel with `data_rsp_error=1`
and zero read data.
