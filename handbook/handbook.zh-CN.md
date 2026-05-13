# Keyimg 手册（简体中文）

## 1. 项目简介
Keyimg 是一个基于 Elixir/OTP 与 Phoenix 的分布式图片存储服务。
它提供 HTTP 上传/读取接口、基于内容哈希的去重、复制规划以及集群协调能力。

## 2. 核心功能
- 提供图片上传、读取、可恢复上传的 HTTP API。
- 基于 SHA-256 内容哈希进行去重。
- 通过集群成员信息与远程 RPC 查询实现多节点行为。
- 使用 Horde 上传协调器实现分布式上传所有权迁移。
- 使用类 CRDT 分布式计数器实现限流。

## 3. 快速开始
1. 安装 Elixir/Erlang。
2. 在项目根目录安装依赖：
   - mix deps.get
3. 运行测试：
   - mix test
4. 启动本地服务：
   - mix run --no-halt

默认地址：http://127.0.0.1:4000

## 4. API 概览
- GET /health
- POST /images
- GET /images/:id
- POST /uploads
- PUT /uploads/:id
- POST /uploads/:id/complete
- DELETE /uploads/:id

## 5. 测试与压测
- 功能测试：
  - mix test
- HTTP 基准测试：
  - mix run bench/http_e2e_rps.exs
- k6 压测：
  - ./scripts/run_k6_loadtest.sh

## 6. 多节点说明
- 可通过 KEYIMG_CLUSTER_NODES 配置集群节点。
- 本地多节点启动可使用 scripts/start_cluster_node.sh。
- RPC 超时与副本行为可在配置文件中调整。

## 7. 常见问题排查
- 读取图片返回 404：检查元数据是否存在、图片是否过期。
- 上传报错：检查上传状态与临时目录写权限。
- 看不到集群效果：检查节点连通性与 cookie 是否一致。

## 8. 维护建议
- 确保存储目录与临时目录可写。
- 合理设置 TTL 与清理间隔。
- 修改分布式逻辑时优先补充 HTTP 集成测试。

## 9. 典型使用场景
- 匿名图片分享：
  上传图片后返回短 ID，用户可直接按 ID 访问。
- 内容去重：
  相同内容重复上传时复用已有图片 ID，减少存储占用。
- 大文件分片上传：
  先创建上传会话，再分块追加，最后统一完成。
- 分布式读取回退：
  本地节点没有图片实体时，可回退到远程节点读取。
- 临时图片托管：
  通过 TTL 控制图片自动过期，并由清理任务回收。

## 10. Postman 测试指南
### 10.1 创建环境
1. 打开 Postman，创建环境 `keyimg-local`。
2. 添加变量：
   - `base_url` = `http://127.0.0.1:4000`

### 10.2 建议的集合结构
创建集合 `Keyimg API`，包含以下请求：
- Health
- Upload Image
- Get Image
- Create Upload Session
- Append Upload Chunk
- Complete Upload
- Abort Upload

### 10.3 请求示例
健康检查：
- 方法：`GET`
- URL：`{{base_url}}/health`
- 期望：HTTP 200，返回状态 JSON。

直接上传图片：
- 方法：`POST`
- URL：`{{base_url}}/images`
- Header：`Content-Type: image/png`
- Body：`binary`（选择文件）
- Tests 脚本（保存图片 ID）：

```javascript
const json = pm.response.json();
pm.environment.set("image_id", json.id);
```

按 ID 读取图片：
- 方法：`GET`
- URL：`{{base_url}}/images/{{image_id}}`
- 期望：HTTP 200，返回二进制内容。

创建可恢复上传会话：
- 方法：`POST`
- URL：`{{base_url}}/uploads`
- Header：`Content-Type: application/json`
- Body：

```json
{ "ttl_seconds": 300 }
```

- Tests 脚本（保存上传 ID）：

```javascript
const json = pm.response.json();
pm.environment.set("upload_id", json.upload_id);
```

追加分片：
- 方法：`PUT`
- URL：`{{base_url}}/uploads/{{upload_id}}`
- Body：可使用 `raw` 文本或 `binary`

完成上传：
- 方法：`POST`
- URL：`{{base_url}}/uploads/{{upload_id}}/complete`
- Header：`Content-Type: application/json`
- Body：

```json
{ "content_type": "image/png", "ttl_seconds": 300 }
```

- Tests 脚本（保存最终图片 ID）：

```javascript
const json = pm.response.json();
pm.environment.set("image_id", json.id);
```

中止上传：
- 方法：`DELETE`
- URL：`{{base_url}}/uploads/{{upload_id}}`
- 期望：会话有效时返回 HTTP 200。

### 10.4 建议添加的 Postman 断言
- 状态码符合预期（`200`、`404` 等）。
- 返回 JSON 包含关键字段（`id`、`upload_id`、`error`）。
- 去重验证：
  同一二进制内容上传两次，比较返回的 `id` 是否一致。

### 10.5 常见问题
- `POST /images` 未设置正确 Content-Type 导致校验失败。
- 上传图片时误用 `raw JSON`，应使用 `binary`。
- 未保存或覆盖环境变量 `image_id`、`upload_id`。
