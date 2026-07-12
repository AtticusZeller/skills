# AtticusZeller Skills

Personal agent skills and bootstrap helpers for development machines.

## Install

List available personal skills:

```bash
npx skills add AtticusZeller/skills --list --full-depth
```

Install the development-machine bootstrap skill globally:

```bash
npx skills add AtticusZeller/skills --skill bootstrap-dev-machine -g -y --full-depth
```

This skill provides an idempotent one-shot installer for the full machine baseline, including public machine handoff docs, a server `.zshrc`, Oh My Zsh, Powerlevel10k, shell plugins, CUDA, uv, Miniforge/conda, NVM, proxy variables, and non-systemd sing-box helpers.

Install the personal skills maintenance skill globally:

```bash
npx skills add AtticusZeller/skills --skill manage-personal-skills -g -y --full-depth
```

Install the repository initialization skill globally:

```bash
npx skills add AtticusZeller/skills --skill init-repo-agents -g -y --full-depth
```

This skill renders repository agent rules and portable docs scaffolding through bundled idempotent scripts, then checks template fidelity and preservation of existing content.

Install the GitHub fork workflow skill globally:

```bash
npx skills add AtticusZeller/skills --skill git-fork-workflow -g -y --full-depth
```

安装阿里云 DSW 持久化 Skill：

```bash
npx skills add AtticusZeller/skills --skill aliyun-dsw-persistence -g -y --full-depth
bash "$HOME/.agents/skills/aliyun-dsw-persistence/scripts/dsw-persist" install-command
```

### 阿里云 DSW 持久化

创建或重建 PAI DSW 实例时：

1. 打开 PAI DSW 的 Create Instance 页面。
2. 在 Mount storage 中添加 OSS 挂载。
3. URI 设置为：

   ```text
   oss://qiongming.oss-cn-beijing-internal.aliyuncs.com/lingjing/
   ```

4. Mount Path 设置为 `/mnt/data/`。
5. 确认挂载具有读写权限。
6. 每次创建新实例都要重新配置相同的 URI 和挂载路径。

`$HOME` 和 `/mnt/workspace` 属于实例本地工作空间，不能作为重要大文件的唯一存储位置。`/mnt/data` 是实验室 OSS 挂载路径，用于持久化模型、数据集、checkpoint、实验结果、归档和可复用下载缓存。

实例启动后：

```bash
dsw-persist doctor
dsw-persist init
source ~/.bashrc
dsw-persist status
```

`init` 还会用 managed block 更新 `${CODEX_HOME:-$HOME/.codex}/AGENTS.md`，使 Codex 后续生成下载和训练命令时默认选择持久化目录。

验证环境与挂载：

```bash
echo "$DSW_PERSIST_ROOT"
echo "$HF_HOME"
echo "$MODELSCOPE_CACHE"
findmnt -T /mnt/data
df -hT /mnt/data
```

显式使用持久化路径：

```bash
hf download <repo-id> \
  --local-dir "$DSW_MODELS_DIR/<model-name>"

python train.py \
  --dataset-path "$DSW_DATASETS_DIR/<dataset-name>" \
  --output-dir "$DSW_CHECKPOINTS_DIR/<experiment-name>"
```

代码和虚拟环境仍放在实例本地工作空间：

```text
代码：$HOME/<project>
虚拟环境：$HOME/<project>/.venv
```

例如：

```bash
cd ~/RLinf
```

Install all personal skills:

```bash
npx skills add AtticusZeller/skills --skill '*' -g -y --full-depth
```

## Update Installed Skills

Refresh installed skills from their recorded sources:

```bash
npx skills update
```

When prompted, choose `Global` to check and update all globally installed personal and third-party skills, including skills from `AtticusZeller/skills`.

## External Global Skills

This repository does not vendor third-party skills. The usual external global skills are recorded in `manifests/global-skills.json`.

Dry-run the install commands:

```bash
bash scripts/install-global-skills.sh --dry-run
```

Install them:

```bash
bash scripts/install-global-skills.sh
```

The script runs `npx skills add <repo> --skill <skill> -g -y` for each manifest entry. For Context7, it also runs:

```bash
npx ctx7 setup --cli --claude --codex -y
```

If Context7 requires authentication, complete its login flow; no token is stored in this repository.

## Repository Maintenance

Validate before committing:

```bash
bash scripts/validate-skills.sh
npx skills add . --list --full-depth
bash scripts/install-global-skills.sh --dry-run
```

Publish updates:

```bash
git status --short
git add .
git commit -m "Update personal skills"
git push
```

## Safety

Do not commit secrets, tokens, PATs, private subscriptions, SSH keys, node credentials, API keys, or private machine config.
