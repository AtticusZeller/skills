# bootstrap doctor：未完成事项

已完成的事务见 `log.md`。

- [ ] `install-global-skills.sh` 硬编码 skill 列表，不读 `manifests/global-skills.json`；doctor 以 manifest 为准，两者可能不一致。
- [ ] `docs/bootstrap-agent-config/plan.md` 落地时，决定 `statusLine` 并入 `claude.settings.template.json`，还是保持 `install-claude-statusline.sh` 的单键合并。
- [ ] 安装脚本输出的 `[MANUAL]` 没有进入 `bootstrap-dev-machine.sh` 的 `manual_actions` 汇总（herdr、p10k 同样如此）。
- [ ] `doctor.sh --ignore` 不校验 id，拼错也会写入。
- [ ] macOS 分支只在 Linux 上用 `--platform macos` 和打桩的 `check-dev-machine-macos.sh` 测过；需在真机上运行 `bash scripts/doctor.sh` 与 `bash scripts/test-claude-statusline.sh`，通过标准：doctor 打印 `platform: macos` 且 configs 节无误报，statusline 测试 PASS。statusline 在 bash 3.2 下的兼容性仅做了静态排查（无 Homebrew bash 时才会用到）。
