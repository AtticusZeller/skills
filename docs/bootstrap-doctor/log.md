# bootstrap doctor 与 statusline 资产：实施记录


## 把 Claude Code statusline 纳入 bootstrap 资产

背景：本机 `~/.claude/statusline-command.sh` 已重写为 Tokyo Night 真彩 + Nerd Font 两行布局（上下文/压缩余量、prompt cache 倒计时、5h/7d pace 条、按 `COLUMNS` 逐级省略且两行右对齐），设计参考 CCometixLine 的 `src/metrics/usage.rs`、`projection.rs`（只借逻辑与配色值，未复制源码）。`~/.claude/settings.json` 中对应配置为 `statusLine = {type: command, command: bash <脚本>, refreshInterval: 15}`。目前两者只存在于本机。

边界与依据：

- 仓库 `AGENTS.md` 要求固定文件放 `assets/`、由可执行 helper 部署、带保真与幂等回归检查；参照现有 `install-herdr-config.sh` / `test-herdr-config.sh` 的“仅缺失时安装、已有文件原样保留”。
- `settings.json` 含插件、权限、env 等个人内容。`docs/bootstrap-agent-config/plan.md`（待确认、未实现）计划整文件 create-if-absent 部署 `claude.settings.template.json`。statusline 不能等那份计划，因此只合并 `statusLine` 这一个键：键缺失时用 `jq` 写入并先备份；键已存在一律不动。两个计划同时落地时，需在那份计划里把 `statusLine` 并入模板或保持本键合并方式，此处记为开放项。
- 脚本运行依赖 `jq`（Linux bootstrap 中为 optional 包）和 bash ≥4.2（`$'\U…'`、`printf -v`、extglob）。macOS 自带 `/bin/bash` 3.2，`bash` 命令可能解析到它；Windows 无 bash。v1 只接入 Linux bootstrap。
- 时区固定 `Asia/Shanghai` 是有意设计（DSW/服务器多为 UTC），保留。

### Task: statusline 资产与部署脚本

**Change**

- [x] 新增 `assets/claude-statusline.sh`：本机脚本原样复制，只删去指向本机备份文件的注释行。
- [x] 新增可执行 `scripts/install-claude-statusline.sh`，参数 `--target-home`、`--dry-run`；尊重 `CLAUDE_CONFIG_DIR`。
  - 脚本目标 `<claude-dir>/statusline-command.sh`：缺失则以 0755 安装；已存在则保留并报告（与资产不一致交给 doctor）。
  - `settings.json`：缺失则创建仅含 `statusLine` 的文件；存在且无 `statusLine` 键则备份为 `settings.json.bak.<时间戳>` 后用 `jq` 合并；已有该键则不动。命令写成 `bash ~/.claude/statusline-command.sh`（不写死用户名），`CLAUDE_CONFIG_DIR` 非默认时写实际路径。
  - 缺 `jq` 时：脚本照装，settings 合并跳过并输出 `[MANUAL]`。
- [x] 在 `bootstrap-dev-machine.sh` 的 Herdr 之后、`install_agent_skills` 之前加一个 phase 调用它；更新 `SKILL.md` Resources 与 `references/bootstrap-phases.md`。

**Verification**

1. [x] 新增 `scripts/test-claude-statusline.sh`：隔离 home 中验证 dry-run 不写文件；首次安装后脚本与资产 `cmp` 一致、settings 只多出 `statusLine`；重跑幂等；修改脚本和已有 `statusLine` 后重跑不被覆盖；原有其他 settings 键保持不变；路径含空格。
2. [x] 资产与本机脚本 `cmp` 一致（本机同步改动后重新复制），mock JSON 在 `COLUMNS=200/75/50` 下渲染正常。
3. [x] `bash -n`、`git diff --check`、`bash scripts/validate-skills.sh`。

**Done**

- [x] 空 home 跑完安装后，`jq .statusLine settings.json` 得到上述对象，脚本可执行且渲染两行。
- [x] 已有个人 settings 的 home，除新增 `statusLine` 外 `jq -S` 输出不变，并留有备份。

## doctor：快速查看本机与仓库基线的差异

背景：bootstrap 只在新机器上“缺失才安装”，之后本机和仓库各自演进，目前没有手段知道哪边更新。实测（2026-11-19，本机）：

| 项 | 结果 |
| --- | --- |
| `~/.p10k.zsh`、herdr config | 与资产一致 |
| ghostty config | 只差模板后加的注释行 |
| tmux.conf.local | 旧版 bootstrap 直接改第 390 行开启 mouse；新版改为在尾部追加 defaults 块 |
| `~/.codex/AGENTS.md` | 仓库模板的 “Response and Writing Style” 更新更长；本机多一节 “Local Machine Monitoring”，位于中间而非尾部；SSH 示例中的机构名与模板 `acme` 不同 |
| `~/.zshrc` | 笔记本自己的 zshrc，与 server 模板差 289 行；无 `~/.local/state/bootstrap-dev-machine/zshrc.sha256`，说明从未由 bootstrap 部署 |
| `~/README.md` | 不存在 |
| skills | `claude-memory-to-codex`（仓库最新提交）未安装；另有 docx/pdf/xlsx/orca-* 等既不在 manifest 也不在仓库的 skill；`install-global-skills.sh` 硬编码列表，不读 manifest |

由此，“尾部不一致即个性化”不能按字面上的文件前缀判断：AGENTS.md 的个人章节在中间，ghostty 差异只是注释。按文件类型定一致性规则（下表），规则判为不一致的才需要用户决定方向。

| 类型 | 适用项 | 判定一致 |
| --- | --- | --- |
| exact | statusline 脚本、settings 的 `statusLine` 键、herdr、p10k | 字节相同 / JSON 值相等 |
| config-prefix | ghostty、tmux.conf.local、zshrc | 去掉空行和纯注释行后，模板是本机的前缀（尾部追加允许） |
| md-sections | `~/.codex/AGENTS.md`、`~/README.md`（先用 `install-machine-handoff.sh --target-home <tmp>` 渲染） | 模板的每个 `##` 章节（含首个 `##` 之前的导言）在本机都存在且内容相同；本机多出的章节在任何位置都允许 |

仓库定位：已安装的 skill 是拷贝（`~/.agents/skills/bootstrap-dev-machine`），回写必须落到 git checkout。顺序为 `--repo` 参数 > `PERSONAL_SKILLS_DIR` > 脚本自身所在 checkout > `~/skills`。找不到 checkout 时只做只读检查，并提示无法回写。模板也从该 checkout 读取，这样比较的是仓库最新内容，而不是已安装的旧拷贝。

v1 只覆盖 Linux。包检查直接复用 `check-dev-machine.sh`，不重复维护命令列表。

### Task: 只读 doctor 报告

**Change**

- [x] 新增可执行 `scripts/doctor.sh`，默认只读，分四节输出，每行格式为 `STATUS  分类  id  说明`：
  1. **packages**：运行 `check-dev-machine.sh`，原样输出。
  2. **third-party skills**：遍历 `manifests/global-skills.json` 中的每个 skill，检查 `~/.agents/skills/<name>` 和 `~/.claude/skills/<name>` 是否存在，以及 `~/.agents/.skill-lock.json` 记录的 source 是否等于 manifest 中的 repo。结果为 `OK` / `MISSING` / `SOURCE` 之一。
  3. **personal skills**：遍历仓库 `skills/*`，检查是否已安装，以及安装拷贝与仓库是否 `diff -r` 一致。结果为 `OK` / `MISSING` / `STALE`。既不属于 manifest 也不属于仓库的已安装 skill 记为 `EXTRA`，只报告。
  4. **configs**：按上表规则逐项比较。结果为 `OK` / `MISSING` / `DRIFT` / `IGNORED`。
- [x] `--diff <id>` 输出该项的 unified diff（模板对本机），供 agent 给用户看。
- [x] 忽略清单 `~/.config/bootstrap-dev-machine/doctor-ignore`，每行一个 id，命中后状态显示 `IGNORED`。用于用户确认“本机这份就是个人版，不再提示”的项，例如笔记本的 zshrc。
- [x] 末尾输出汇总计数；有 `MISSING` / `DRIFT` / `STALE` / `SOURCE` 时退出码为 1，便于脚本判断。

**Verification**

1. [x] 新增 `scripts/test-doctor.sh`：用假 home 加临时 repo 构造各状态（一致、只差注释、尾部追加、中间多出章节、章节内容改动、缺失、忽略、STALE skill、EXTRA skill），断言状态和退出码；断言默认运行不修改任何文件（运行前后对目标 home 做 `find -newer` 检查）。
2. [x] 在本机实跑，结果与上方实测表一致：ghostty 为 OK，AGENTS.md 为 DRIFT 且只列出 “Response and Writing Style” 和 “Remote Machines” 两节，`claude-memory-to-codex` 为 MISSING。

**Done**

- [x] 本机运行 `doctor.sh` 能在一屏内看清哪些未装、哪些不一致；`--diff codex-agents` 只显示章节级差异，不把 “Local Machine Monitoring” 算成差异。

### Task: 不一致时的同步流程

**Change**

- [x] `doctor.sh --sync <id> --to local|repo`，只支持 exact 类型的项（statusline 脚本、`statusLine` 键、herdr、p10k）：
  - `--to local`：备份后用仓库资产覆盖本机。
  - `--to repo`：把本机内容写回 checkout 的 `assets/`。
  - 两个方向都会再跑一次该项检查，确认变为 OK。
- [x] config-prefix 和 md-sections 类型不做自动同步。这两类文件里共享内容和个人内容混在一起，哪部分该回写仓库需要人判断，由 agent 按 `SKILL.md` 流程手工合并。
- [x] `SKILL.md` 新增 Doctor 小节，规定 agent 的做法：
  1. 运行 doctor。
  2. 对每个 DRIFT / STALE 项先展示 `--diff`，再用 AskUserQuestion 问方向，选项为“仓库覆盖本机”“本机回写仓库”“保持现状并加入忽略清单”。
  3. 选了回写仓库的项，交给 `manage-personal-skills` 完成验证、提交和推送，提交前需要用户确认。
  4. MISSING skill 只给出安装命令，不自动安装。
- [x] `README.md` 根文档增加一行 doctor 入口说明。

**Verification**

1. [x] `test-doctor.sh` 覆盖两个 `--sync` 方向：生成备份、目标与源 `cmp` 一致、其后检查为 OK；对非 exact 项调用 `--sync` 时拒绝并以非零退出。
2. [x] `bash scripts/validate-skills.sh`、`npx skills add . --list --full-depth`、`bash scripts/install-global-skills.sh --dry-run` 通过。
3. [x] 独立 agent 依据本计划审查 diff；确认有效的问题补进本计划后再修复。审查确认并已修复：
   - [x] git worktree 的 `.git` 是文件，`is_checkout` 只认目录，导致 worktree 内运行时回落到 lock 记录的主 checkout，`--sync --to repo` 写错仓库。改为 `-e`；`test-doctor.sh` 加 worktree 用例。
   - [x] `--print-setting` 失败（如 HOME 不可写）时期望值为空文件，报告误判 DRIFT，`--sync statusline-setting --to local` 写入 `null`。`--print-setting` 不再要求可写；doctor 对空/非对象结果按“模板缺失”处理；sync 前检查模板非空。
   - [x] `--sync --to local` 用 `install` 会把符号链接换成普通文件。改为遇到符号链接拒绝，与两个安装脚本一致；测试覆盖。
   - [x] 次要：packages 通过数把汇总行算入（只在全通过时出现）；非 command/path 的 WARN 改报 `WARN` 而非 `MISSING`；skill 安装提示补上 `-a codex -a claude-code -a cursor`；`--to` 不带 `--sync` 报错；`--diff` 后也做只读快照比对。
   - 未处理（沿用现状）：`[MANUAL]` 不进 bootstrap 的 `manual_actions`，herdr/p10k 同样如此；`--ignore` 不校验 id。

**Done**

- [x] 在临时 checkout 中执行 `--sync statusline-script --to repo` 后，`git -C <checkout> diff --stat` 只显示 `assets/claude-statusline.sh` 一个文件。

## 执行中的偏差（已实现，待用户知悉）

- 本机脚本第 7 行“Previous version”注释同时从本机删掉，保证资产与本机一致，doctor 不会一上来就报 DRIFT。
- statusline 第二行为空时脚本以 1 退出（最后一行 `[ … ] && render_line`）。改成 `if … fi`，本机和资产同步修改。
- 用户中途要求 5h/7d 显示剩余额度：百分比改为 `100 - used`；pace 条 fg 为剩余额度、bg 为剩余时间；差值改为 `+N%`（额度富余，绿）/ `-N%`（消耗快于窗口，琥珀）；剩余 ≤30% 琥珀、≤10% 红。本机和资产同步。
- tmux 改用 `contains` 规则而非 config-prefix：仓库只拥有追加的 `tmux-defaults.conf` 块，前面是上游 Oh my tmux 的 `.tmux.conf.local`，不在仓库里，无法做前缀比较。
- packages 一节默认只列 WARN 行（标为 MISSING）和通过数，`--verbose` 原样输出，保证一屏可读。
- 仓库定位多加一步：读取 `~/.agents/.skill-lock.json` 中 `bootstrap-dev-machine` 的 local source（本机为 `~/DevSpace/skills`），已安装拷贝运行也能找到 checkout。
- `statusline-setting` 的期望值来自 `install-claude-statusline.sh --print-setting`（新增），只支持 `--to local`；`--to repo` 拒绝并提示去改安装脚本。比较时把 `~/` 展开为 `$HOME`，所以本机的绝对路径写法算一致。
- 新增 `--ignore <id>` 写入忽略清单，供 agent 在用户选“保持现状”时调用。

## 开放问题（已确认：全部按建议）

1. 一致性规则：是否接受上面的三类规则？其中 AGENTS.md / README 按章节比较，个人章节放在任何位置都允许，而不是只允许追加在尾部。
2. 是否需要忽略清单？没有的话，笔记本的 zshrc 会在每次运行 doctor 时都提示 DRIFT。
3. statusline 对已有 `settings.json` 只合并 `statusLine` 这一个键。这与 `bootstrap-agent-config` 计划中“已有配置一律不改”的原则不同。是否接受？
4. v1 只做 Linux（macOS 的 bash 3.2 和 Windows 都排除在外），是否可以？
5. `install-global-skills.sh` 硬编码 skill 列表而不读 manifest。本次 doctor 以 manifest 为准，脚本本身不改，记为后续事项。

## 首次 doctor 结果的处理（2026-11-19 用户决定）

用户补充：bootstrap-dev-machine 面向用户自己的工作站，以后 Linux 服务器上不再安装，直接由 agent 操作。

- [x] `codex-agents`：本机 SSH 一节改用仓库版（示例保留 `acme`），本机 “Response Style” 换成仓库的 “Response and Writing Style”；先备份。个人的 “Local Machine Monitoring” 保留。
- [x] `tmux-local`：本机尾部补 `set -ga update-environment " COLORTERM"`。
- [x] `~/README.md` 用户从不看：删除三个平台的 `README.machine*.template.md`，`install-machine-handoff.sh` 只生成 `~/.codex/AGENTS.md`；同步修改 handoff/macOS 测试、`check-dev-machine.{sh,ps1}`、doctor 配置项和文档。`--proxy-url/--python-version/--node-version` 仍接受，避免破坏调用方，但 AGENTS 模板没有占位符，已不起作用。
- [x] `claude-memory-to-codex` 暂不安装（以后可能并入统一的 memory 管理 skill），本机加入 doctor 忽略清单。
- [x] sing-box `~/.config/sing-box/config.json` 是 `sbc` CLI 的配置；仓库没有 sing-box 配置模板（订阅属私有内容）。本机用桌面版，本机忽略 `path:config.json`。
- [x] 卸载 find-skills、frontend-design、docx、pdf、xlsx，并清掉 `~/.codex/skills` 里的悬空链接。orca-* 与 Orca 应用绑定，不由本仓库管理。
- [x] 全局 skill 安装的 agent 列表把 Cursor 换成 Pi（`-a pi`，skills CLI 支持）：`install-global-skills.sh`、macOS bootstrap、doctor 提示、根 README。
- [x] zshrc：用户要求把模板换成本机版本。本机 `~/.zshrc` 含 3 个明文凭据和多处写死的 `/home/<user>` 路径，不能原样进入公开仓库。用户确认方案：以本机为基础重写成可移植模板 `assets/zshrc.linux`（取代 `zshrc.server`），不设代理，凭据移到本机 `~/.zshrc.local`（600，模板最后加载）。
  - 保留本机实际在用的 Linuxbrew（含 curl）、pnpm、bun、Go、TensorRT（取 `~/.local/opt/TensorRT-*` 最新）、JetBrains vmoptions、`.zfunc` 与 `site-functions` 补全，均“存在才加载”；CUDA 优先 `/usr/local/cuda`，否则取最新 `cuda-*`（glob 需 `-/` 才跟随符号链接，首版用 `/` 误选了 `cuda-12.1`）。
  - 去掉本机的 `. /etc/environment`：该文件只设 PATH，在 zshrc 中 source 会重置 PATH。
  - 插件列表随本机去掉 `zsh-bat`，Linux bootstrap 不再克隆它、checker 不再检查；macOS 模板不变。
  - 修复 venv 自动激活：本机版本的 `source` 被 conda init 注释掉，实际从不激活。新版在启动和每次 `cd`（`chpwd` hook）时激活最近的 `.venv`，离开项目时只停用由该 hook 激活的 venv；放在 conda 初始化之后，保证 venv 的 bin 在 PATH 最前。隔离 ZDOTDIR 实测：进入项目激活、离开停用、再进入重新激活。
  - 实测发现 conda 26 把 `auto_activate_base` 改名为 `auto_activate`，bootstrap 仍写旧键，本机两个键并存，导致 conda shell hook 每次启动报 `MultipleKeysError`（旧 zshrc 用 `2>/dev/null` 掩盖）。Linux/macOS bootstrap 改写新键；本机备份 `~/.condarc` 后删除旧键。
  - 本机部署：备份 `~/.zshrc`，装入模板并写入 `zshrc.sha256` 状态，doctor 显示 zshrc OK。

状态：全部完成，已提交推送。
