
# 终端

ghostty

## Ghostty终端问题，SSH连接到服务器后不能删除字符
> 官方解释：https://ghostty.org/docs/help/terminfo

核心原因：远端服务器“不认识”你的终端

1. Ghostty 的默认 TERM
根据文档，Ghostty 默认使用 TERM=xterm-ghostty，这是一个为支持其高级特性而设计的新 terminfo 条目 。

2. SSH 的环境变量传递
当您通过 SSH 连接时，本地 Ghostty 的 TERM值（即 xterm-ghostty）会被发送到远端服务器。

3. 服务器的缺失能力
许多服务器系统（尤其是旧版本）的 ncurses 数据库中不包含 xterm-ghostty​ 的定义。因此，远端程序无法识别终端类型，导致键位映射（特别是 Backspace）等基础功能失效 。

总结：
远端服务器：“你这是什么 xterm-ghostty？没见过，我懵了，所以 Backspace 不动。”

作用是在 SSH 连接建立时，强行覆盖远端的环境变量，将 TERM设置为一个几乎所有服务器都支持的通用值：xterm-256color。
这样做的结果是：
✅ 优点：远端的 shell、readline、vim 等程序都能正确识别终端能力，Backspace 键自然恢复正常。
⚠️ 代价：您会失去 Ghostty 独有的一些高级特性（如彩色下划线、特定样式等），因为 xterm-256color的定义中不包含这些能力

```bash
# .ssh/config 
Host * 
SetEnv TERM=xterm-256color
```