---
name: aliyun-dsw-persistence
description: 初始化和检查阿里云 PAI DSW 实例的 OSS 持久化环境，管理 /mnt/data/atticux 目录及 Hugging Face、ModelScope、Torch、pip、uv 缓存。用于新建或重建 DSW 实例、下载大型模型或数据集前、开始训练前，以及排查模型或 checkpoint 在实例重建后消失的问题。
---

# 阿里云 DSW 持久化

## 适用场景

- 新建或重建阿里云 PAI Data Science Workshop（DSW）实例。
- 检查 `/mnt/data` OSS 是否正确挂载。
- 初始化 `/mnt/data/atticux`。
- 配置 Hugging Face、ModelScope、Torch、pip 和 uv 缓存。
- 下载大型模型、数据集或开始训练前检查持久化路径。
- 排查模型或 checkpoint 为什么在重建实例后消失。

## 固定约定

- DSW 控制台 OSS URI：`oss://qiongming.oss-cn-beijing-internal.aliyuncs.com/lingjing/`
- 挂载路径：`/mnt/data/`
- 当前用户持久化根目录：`/mnt/data/atticux`
- 代码：`$HOME/<project>`，例如 `~/RLinf`
- Python 虚拟环境：`$HOME/<project>/.venv`
- Codex 全局规则：`${CODEX_HOME:-$HOME/.codex}/AGENTS.md` 中的 managed block

不要迁移代码，不要在持久化目录下创建 `code`、`envs` 或 Conda 目录。不要设置 `HOME`、`PYTHONPATH`、`CUDA_HOME`、`LD_LIBRARY_PATH`、`CONDA_PKGS_DIRS` 或 `XDG_CACHE_HOME`。

## 工作流

1. 若命令尚未安装，执行：

   ```bash
   bash scripts/dsw-persist install-command
   ```

2. 下载大型模型、数据集或开始训练前，先执行：

   ```bash
   dsw-persist doctor
   ```

3. 尚未初始化时执行：

   ```bash
   dsw-persist init
   source ~/.bashrc
   dsw-persist status
   ```

   `init` 同时更新 Codex 全局 `AGENTS.md`，让后续 Agent 默认使用正确的持久化路径。

4. 生成下载或训练命令时，优先使用：

   - `$DSW_MODELS_DIR`
   - `$DSW_DATASETS_DIR`
   - `$DSW_CHECKPOINTS_DIR`
   - `$DSW_OUTPUTS_DIR`

不要默认把大模型或数据集下载到 `$HOME/.cache`、`/root/.cache`、`/tmp` 或项目代码目录。

## 安全边界

- `/mnt/data` 未确认为独立且可写的挂载点时，不得初始化或下载大文件。
- 本地命令不能可靠验证完整 OSS URI；只确认独立挂载，并提示用户与 DSW 控制台人工核对。
- 不使用 `sudo`，不修改 `/etc`、其他用户目录或 `/mnt/data` 下其他用户目录。
- 不删除、迁移已有缓存，也不移动 `$HOME/.cache`。
- 不保存 OSS AccessKey、Token 或其他凭据。
- 不对 `/mnt/data` 执行递归 `chmod` 或 `chown`。
- 让 `scripts/dsw-persist` 从 `assets/env.sh.template` 和 `assets/codex-agents-block.md` 部署固定内容；不要从 Markdown 代码块重建。

## 验证

修改脚本或模板后运行：

```bash
bash scripts/test-dsw-persist.sh
```
