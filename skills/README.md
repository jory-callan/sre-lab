# Skills 技能库

本目录包含 czw-sre 项目的自定义技能（Skills）集合。

## 什么是 Skill？

Skill 是可复用的工作流程、最佳实践和专业知识的封装。它们为 AI Agent 提供了完成特定任务的标准化方法。

## 目录结构

```
skills/
├── README.md                    # 本文件 - 总览介绍
├── SKILL_WRITING_SOP.md         # 编写 Skill 的标准操作流程
├── references.md                # 相关资源链接
├── sre/                         # SRE 运维相关技能
│   └── ...
├── devops/                      # DevOps 相关技能
│   └── ...
└── templates/                   # Skill 模板
    └── ...
```

## Skill 分类

- **sre/** - 站点可靠性工程相关技能
- **devops/** - DevOps 流程相关技能
- **templates/** - Skill 模板文件

## 相关文档

- [SKILL_WRITING_SOP.md](./SKILL_WRITING_SOP.md) - 如何编写一个合格的 Skill
- [references.md](./references.md) - 参考资源和链接

## Skill 命名规范

- 使用小写字母和连字符（kebab-case）
- 名称应清晰描述技能用途
- 例如：`docker-compose-deployment`, `k8s-troubleshooting`

## 如何使用

1. 查看 [SKILL_WRITING_SOP.md](./SKILL_WRITING_SOP.md) 了解如何编写 Skill
2. 在对应分类目录下创建新 Skill
3. 提交到 Git 进行版本控制
