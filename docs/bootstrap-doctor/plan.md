# bootstrap doctor：未完成事项

已完成的事务见 `log.md`。

- [ ] `install-global-skills.sh` 硬编码 skill 列表，不读 `manifests/global-skills.json`；doctor 以 manifest 为准，两者可能不一致。
- [ ] `docs/bootstrap-agent-config/plan.md` 落地时，决定 `statusLine` 并入 `claude.settings.template.json`，还是保持 `install-claude-statusline.sh` 的单键合并。
- [ ] 安装脚本输出的 `[MANUAL]` 没有进入 `bootstrap-dev-machine.sh` 的 `manual_actions` 汇总（herdr、p10k 同样如此）。
- [ ] `doctor.sh --ignore` 不校验 id，拼错也会写入。
- [ ] doctor 和 statusline 部署只覆盖 Linux；macOS 需 bash ≥4 才能运行 statusline。
