# git commit 提交规范

## 提交格式

~~~text
<type类型>(<scope 可选作用域>): <subject 描述>
<BLANK LINE>
<body 可选的正文>
<BLANK LINE>
<footer 可选的脚注>
~~~

第一行(必须存在)：`<type类型>(<scope 可选作用域>): <subject 描述>`

- feat: 新功能、新特性
- fix: 修改 bug
- perf: 更改代码，性能优化
- refactor: 代码重构（重构，在不影响代码内部行为、功能下的代码修改）
- docs: 文档修改
- style: 代码格式修改, 注意不是 css 修改（例如分号修改）
- test: 测试用例新增、修改
- build: 影响项目构建或依赖项修改
- revert: 恢复上一次提交
- ci: 持续集成相关文件修改
- chore: 其他修改（不在上述类型中的修改）
- release: 发布新版本
- workflow: 工作流相关文件修改

## 示例

```js
// 示例1 
fix(global):修复checkbox不能复选的问题 
// 示例2 
fix(common): 修复头部区域logo问题


// 示例1 
feat: 添加资产管理模块
增加资产列表、搜索。
需求No.181 http://xxx.xxx.com/181。
```

## 参考：

- [git commit 代码提交规范 - zetaiota - 博客园 (cnblogs.com)](https://www.cnblogs.com/anly95/p/13163384.html)
- [git commit 代码提交规范 - 掘金 (juejin.cn)](https://juejin.cn/post/7023927717292671012)

