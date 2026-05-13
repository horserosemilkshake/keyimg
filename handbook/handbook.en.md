# Keyimg Handbook (English)

## 1. What This Project Is
Keyimg is a distributed image storage service built with Elixir/OTP and Phoenix.
It supports HTTP upload/read APIs, deduplication by content hash, replication planning, and cluster-aware coordination.

## 2. Main Features
- HTTP API for image upload, read, and resumable upload.
- Deduplication by SHA-256 content hash.
- Multi-node behavior through cluster membership and remote RPC lookups.
- Distributed upload ownership via Horde-based upload coordinator.
- Rate limiting using a CRDT-style distributed counter.

## 3. Quick Start
1. Install Elixir/Erlang.
2. In project root, fetch dependencies:
   - mix deps.get
3. Run tests:
   - mix test
4. Start service locally:
   - mix run --no-halt

Default endpoint: http://127.0.0.1:4000

## 4. API Summary
- GET /health
- POST /images
- GET /images/:id
- POST /uploads
- PUT /uploads/:id
- POST /uploads/:id/complete
- DELETE /uploads/:id

## 5. Testing and Load
- Functional tests:
  - mix test
- HTTP benchmark:
  - mix run bench/http_e2e_rps.exs
- k6 load test:
  - ./scripts/run_k6_loadtest.sh

## 6. Multi-Node Notes
- Cluster hosts can be configured by KEYIMG_CLUSTER_NODES.
- For local cluster startup, use scripts/start_cluster_node.sh.
- RPC timeout and replica behavior are controlled in config files.

## 7. Troubleshooting
- 404 on image read: verify image metadata exists and image not expired.
- Upload errors: check upload status and temp storage path permissions.
- Cluster behavior not visible: check node connectivity and cookie consistency.

## 8. Maintenance Tips
- Keep storage and temp directories writable.
- Run cleanup worker with sensible TTL and interval settings.
- Use integration tests for HTTP paths when changing distributed behavior.

## 9. Typical Use Cases
- Anonymous image sharing:
  Upload an image and return a short ID for direct retrieval.
- Content deduplication:
  Multiple uploads of the same file reuse the existing image ID.
- Large file ingestion with resume:
  Use upload sessions and chunk append API before finalizing.
- Distributed read fallback:
  If local node lacks image body, service can fetch from remote node.
- Temporary image hosting:
  Set TTL so files expire automatically and are cleaned by worker.

## 10. Postman Testing Guide
### 10.1 Create Environment
1. Open Postman and create an environment named `keyimg-local`.
2. Add variable:
   - `base_url` = `http://127.0.0.1:4000`

### 10.2 Recommended Collection Structure
Create a collection named `Keyimg API` with these requests:
- Health
- Upload Image
- Get Image
- Create Upload Session
- Append Upload Chunk
- Complete Upload
- Abort Upload

### 10.3 Request Examples
Health check:
- Method: `GET`
- URL: `{{base_url}}/health`
- Expect: HTTP 200 with JSON status.

Direct image upload:
- Method: `POST`
- URL: `{{base_url}}/images`
- Header: `Content-Type: image/png`
- Body: `binary` (choose a file)
- Test snippet (save image id):

```javascript
const json = pm.response.json();
pm.environment.set("image_id", json.id);
```

Read image by ID:
- Method: `GET`
- URL: `{{base_url}}/images/{{image_id}}`
- Expect: HTTP 200 and binary body.

Create resumable upload session:
- Method: `POST`
- URL: `{{base_url}}/uploads`
- Header: `Content-Type: application/json`
- Body:

```json
{ "ttl_seconds": 300 }
```

- Test snippet (save upload id):

```javascript
const json = pm.response.json();
pm.environment.set("upload_id", json.upload_id);
```

Append chunk:
- Method: `PUT`
- URL: `{{base_url}}/uploads/{{upload_id}}`
- Body: `raw` text or `binary`

Complete upload:
- Method: `POST`
- URL: `{{base_url}}/uploads/{{upload_id}}/complete`
- Header: `Content-Type: application/json`
- Body:

```json
{ "content_type": "image/png", "ttl_seconds": 300 }
```

- Test snippet (save final image id):

```javascript
const json = pm.response.json();
pm.environment.set("image_id", json.id);
```

Abort upload:
- Method: `DELETE`
- URL: `{{base_url}}/uploads/{{upload_id}}`
- Expect: HTTP 200 when session is active.

### 10.4 Suggested Postman Test Checks
- Status code is expected (`200`, `404`, etc.).
- Response has expected JSON keys (`id`, `upload_id`, `error`).
- For dedup checks:
  upload same binary twice and compare returned `id` values.

### 10.5 Common Postman Pitfalls
- Missing content type on `POST /images` can cause validation failures.
- Using `raw JSON` instead of `binary` when uploading image body.
- Forgetting to persist `image_id` or `upload_id` environment variables.
