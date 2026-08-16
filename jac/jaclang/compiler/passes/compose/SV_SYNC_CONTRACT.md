# SV sync endpoint contract (local-first)

Clients built with `[sv] deploy = "local-first"` and `[sv] sync = "https://host/"` POST
an append-only oplog batch to the sync server when WorkManager runs (and after each
local walker mutation enqueues a one-shot sync).

**Server-side Jac work is out of scope for the Android target** - a matching ingest
endpoint must be implemented separately on the Jac server.

## Endpoint

```
POST {sync_url}/sync
Content-Type: application/json
Accept: application/json
```

`sync_url` is the `[sv].sync` value from `jac.toml` with any trailing `/` stripped.

## Request body (`SyncPushRequest`)

```json
{
  "deviceId": "550e8400-e29b-41d4-a716-446655440000",
  "lastSyncedClock": 42,
  "ops": [
    {
      "opId": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "anchorId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "kind": "spawn",
      "payload": { "kind": "Todo", "id": "...", "title": "Buy milk", "done": false },
      "logicalClock": 43
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `deviceId` | Stable UUID generated once per app install |
| `lastSyncedClock` | Highest remote clock this device has acknowledged |
| `ops` | Pending local mutations not yet acknowledged by the server |

### Op kinds

| `kind` | `anchorId` | `payload` |
|---|---|---|
| `spawn` | Node id | Full serialized node JSON (same shape as graph snapshot nodes) |
| `connect` | Source node id | `{ "from": "<id>", "to": "<id>" }` |
| `delete` | Deleted node id | `{ "id": "<id>" }` tombstone |

Field-level edits are represented as a `spawn` op with a newer `logicalClock` for the
same `anchorId` (last-writer-wins).

## Response body (`SyncPushResponse`)

HTTP 200 with JSON:

```json
{
  "remoteClock": 100,
  "ops": []
}
```

| Field | Meaning |
|---|---|
| `remoteClock` | Server's highest logical clock after ingesting the batch; client marks local pending ops with `logicalClock <= remoteClock` as synced |
| `ops` | Remote mutations this device has not yet applied (same `GraphOp` shape as request) |

## Conflict policy (client merge)

Implemented in generated `JacSync.kt` (swappable in one place):

1. **Last-writer-wins per anchor** by `logicalClock` for `spawn` ops.
2. **Deletes are tombstones** - a `delete` with `logicalClock >=` the anchor's local clock removes the node and wins over concurrent field edits.
3. **`connect` ops** apply when their clock is >= the source anchor's local clock.

A CRDT merge is explicitly out of scope for this first cut.

## Error handling

Non-2xx responses cause the WorkManager worker to retry with backoff. The local graph
and oplog remain intact; pending ops are not dropped until the server acknowledges them
via `remoteClock`.

## Testing without a live server

Unit-test the worker against a fake HTTP server that accepts `POST /sync` and returns an
empty `ops` array with `remoteClock` equal to the max clock in the request batch.
