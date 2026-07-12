<!-- >>> aliyun-dsw-persistence >>> -->
## Aliyun DSW Persistent Storage

- Before downloading large models or datasets, or starting training, run `dsw-persist doctor`. If it fails, do not write important data under `/mnt/data`.
- Use `/mnt/data/atticux` for persistent large files. Prefer `$DSW_MODELS_DIR`, `$DSW_DATASETS_DIR`, `$DSW_CHECKPOINTS_DIR`, and `$DSW_OUTPUTS_DIR` in generated commands.
- For Hugging Face model downloads, prefer `hf download <repo-id> --local-dir "$DSW_MODELS_DIR/<model-name>"`. The configured Hugging Face cache also persists under `$HF_HOME`.
- Keep source code in `$HOME/<project>` and virtual environments in `$HOME/<project>/.venv`; do not move Git repositories or virtual environments to `/mnt/data`.
- `/mnt/data` is a shared OSS mount. Do not modify other users' directories, and do not assume local mount checks validate the complete OSS URI.
<!-- <<< aliyun-dsw-persistence <<< -->
