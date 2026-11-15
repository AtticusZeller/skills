# Agent 通用配置模板

## 为 bootstrap 提供 Codex 与 Claude Code 的公开配置基线

背景：本次 tmux 排查中，Codex 的备用屏幕导致输出没有进入 tmux 滚动历史；本机已经在 `~/.codex/config.toml` 中设置 `tui.alternate_screen = "never"`。这项可复用偏好目前只存在于本机，应当成为 bootstrap 的模板资源。

本机两个 agent 的配置同时包含账号、服务商、项目授权、插件和运行状态。模板从已核实的公开字段独立编写，不复制现有配置。第一版仅覆盖 Codex 与 Claude Code，不加入 Cursor 配置或其他 agent。

配置依据：

- [OpenAI 配置参考](https://learn.chatgpt.com/docs/config-file/config-reference)：Codex 的 `tui.alternate_screen` 支持 `never`；此前已检查本机 Codex 0.160.0 的帮助及相应版本源码，确认此设置保留终端滚动历史。
- [Claude Code settings](https://code.claude.com/docs/en/settings)：用户设置位于 `~/.claude/settings.json`，支持 `CLAUDE_CONFIG_DIR` 自定义根目录；Context7 获取的官方语言文档确认 `language` 控制响应语言。
- 仓库 `AGENTS.md` 要求固定模板放在 `assets/`，通过可执行 helper 部署，并提供保真与幂等回归检查。
- 现有机器交接安装器采用仅创建缺失文件的策略。本次延续该策略，不自动合并或重写已有账号配置。

### Task: 添加最小的公开模板

**Change**

- [ ] 增加 `skills/bootstrap-dev-machine/assets/codex.config.template.toml`，唯一有效设置为 `[tui]` 下的 `alternate_screen = "never"`。
- [ ] 增加 `skills/bootstrap-dev-machine/assets/claude.settings.template.json`，唯一有效设置为 `language = "简体中文"`。
- [ ] 模板不设模型、推理强度、服务商、审批/沙箱策略、代理、MCP、插件、hooks、账号、项目授权或机器路径；这些均使用 agent 默认值或用户自行配置。

**Verification**

1. [ ] 用 Python 标准库解析 TOML/JSON，核对上述字段及完整键集合。
2. [ ] 检查模板没有账号、环境变量、主目录绝对路径或动态运行状态。

**Done**

- [ ] 两个独立模板可以直接作为合法用户配置文件使用，并且内容仅包含上述公开偏好。

### Task: 通过 bootstrap 部署并保留已有配置

**Change**

- [ ] 增加可执行 `scripts/install-agent-configs.sh`，支持 `--target-home` 和 `--dry-run`；默认写入目标 home 的 `.codex/config.toml`、`.claude/settings.json`，尊重已设置的 `CODEX_HOME`、`CLAUDE_CONFIG_DIR`。
- [ ] 缺失配置直接从 assets 安装，文件权限为 `0600`；已有文件或符号链接原样保留，并明确报告跳过。不进行自动合并或替换。
- [ ] dry-run 不创建目录、配置或备份；重复执行不会改变既有配置或增加内容。
- [ ] 在 bootstrap 中于 developer CLIs 之后、agent skills/Context7 设置之前接入部署，避免 Context7 先生成配置文件导致新机器跳过基线。
- [ ] 更新 `SKILL.md`、bootstrap phases、机器 README 模板和检查脚本，解释模板位置、跳过行为及配置生效需要重启 agent。
- [ ] 完成后同步本机技能安装；本机已有配置保持原样。沿用此前的发布要求，在验证和独立审查后提交并推送到 `main`。

**Verification**

1. [ ] 在隔离目录运行 installer，生成配置与 assets 逐字节一致。
2. [ ] 修改生成文件后重跑，验证用户自定义内容、符号链接及现有内容均未被覆盖。
3. [ ] 验证新机器、仅缺一个配置、完整已有配置、自定义配置根目录、包含空格的路径和 dry-run。
4. [ ] shell 语法检查、`git diff --check`、bootstrap dry-run 与仓库要求的 `validate-skills.sh`、本地 skills discovery、global skills installer dry-run 通过。
5. [ ] 独立 agent 依据此计划审查最终 diff；确认有效问题后修复并补充相应验证。
6. [ ] 发布后检查 GitHub `main` SHA 与远程 skill discovery；检查本机安装的技能与仓库内容一致。

**Done**

- [ ] 空目标 home 得到上述两个公开配置；已有目标 home 的配置校验和保持不变。
- [ ] bootstrap 与单独修复入口均能重复执行，且 dry-run 不写文件。
- [ ] 所有验证通过，发布状态及任何仍需用户执行的运行时验证单独报告。

状态：待用户确认；尚未创建模板或部署实现。
