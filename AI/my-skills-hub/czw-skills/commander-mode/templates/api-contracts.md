# API Contracts（接口约定）
# 前后端共享，指挥官先更新这里，再告诉双方 Session
# 这样前后端可以并行开发，不需要互相读取代码

## 端点列表
| 方法 | 路径 | 说明 | 请求参数 | 响应 |
|------|------|------|----------|------|
| GET | /api/files | 列目录 | path: string | JSON { files: [...] } |
| GET | /api/file/content | 读文件 | path: string | JSON { content: string } |

## 认证
- Header: `Authorization: Bearer <token>`
- 静态文件 `/` 不需要认证
