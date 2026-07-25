# RPC fixed-cost floor decomposition probe (2026-07-25)

Investigates the ~15 ms "loopback RPC fixed cost" reported for the family-2
`xop_*` cells, to determine whether it is intrinsic boundary cost or a property
of the specific deployment path (Jac's `jac start` provider + `sv import`
client). Pinned governor + turbo off, same machine as the canonical dataset.

## Method

Started the `xop_feed_payload` provider (`jac start feedbatch.jac`) once, kept it
warm, and timed three paths against the same endpoint:

1. **sv-import client** (`rpc_runner.jac`, the measured path) -- the number the
   paper's fixed cost comes from.
2. **raw HTTP, new connection per call** (python http.client, no keep-alive) --
   isolates server dispatch + connection setup, no sv-import client marshalling.
3. **raw HTTP, keep-alive** (one persistent connection) -- isolates pure
   server-side dispatch.

## Results (per-call, small N)

| path | per-call | what it includes |
|---|---|---|
| sv-import client (measured) | ~12.5-15 ms | server dispatch + client sv-import marshalling |
| raw HTTP, new connection | ~5.5-6.5 ms | server dispatch + TCP connect |
| raw HTTP, keep-alive | ~5.5-6.5 ms | server dispatch only |

Keep-alive vs new-connection: **~0 ms difference** -> loopback TCP connection
setup is NOT the cost.

## Decomposition of the ~15 ms fixed floor

- **~5.5-6.5 ms server-side dispatch.** The `jac start` provider is a *full
  application server* (its OpenAPI surface includes /admin/*, /sso/*,
  /admin/llm/telemetry/*, firebase, /user/*, /api-key/*, /jobs, /graph -- a
  production app server, not a minimal RPC endpoint). Each `feed_batch` call is
  routed through that stack: routing, auth middleware, request context,
  function-wrapper, JSON serialization. Flat in N until the payload itself grows.
- **~6-7 ms client-side.** The `sv import` runtime's per-call Python marshalling
  (HTTP call + JSON encode/decode + Jac object reconstruction).
- **~0 ms connection setup.** Negligible on loopback; keep-alive does not help.

## Consequence for the paper

The ~15 ms fixed floor -- and therefore the 374x / 241x cross-runtime ratios and
the N~17k break-even -- is **a property of this deployment path (jac-start app
server + sv-import client), not a lower bound on RPC-boundary cost**. A minimal
RPC endpoint with a tuned client would be far lower. Report these as floors for
the shipped path, explicitly attributed, not as boundary physics.

**The serialization slope (890 ns/element) is unaffected**: it is the genuine
per-element marshalling marginal cost (JSON-encode/HTTP/decode), which the fixed
framework floor does not touch. The paper's slope claim stands; only the
fixed-cost *interpretation* needs the attribution above.
