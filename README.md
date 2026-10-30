# ascend-notebook-image

基于 `quay.io/ascend/vllm-ascend:v0.18.0-a3`（arm64）按《自定义镜像规范》**notebook 自定义镜像规范**构建的镜像，用 GitHub Actions 自动构建并推送到 GHCR。

## 为什么选 notebook 规范而不是 pytorchjob 规范

- 基础镜像已内置 CANN、torch、torch_npu、vllm，notebook 规范只需补 tini/nodejs/jupyter 一套，apt + pip 固定版本即可，成功率高。
- pytorchjob 规范要求重装 CANN/torch 系列 + mlnx OFED + apex 源码编译，在 arm64 昇腾底座上失败率高，且可能破坏基础镜像内已配好的 torch_npu 版本匹配。

## 目录结构

```
ascend-notebook-image/
├── Dockerfile                          # 基于 vllm-ascend 补齐 notebook 环境
├── jupyter_notebook_config.py          # 规范 1.1 的推荐 Jupyter 配置
├── requirements.txt                    # 规范 2.6 训练任务额外依赖（按需填，空则跳过）
└── .github/workflows/build-arm64.yml   # GitHub Actions：arm64 构建 + 推送 GHCR
```

## 规范落点

| 规范条款 | 实现 |
|---|---|
| 1.1 必备软件 tini / python3 / nodejs | `apt-get install tini nodejs npm`（基础镜像自带 python3） |
| 1.1 pip 包 jupyterlab 3.6.3 / notebook 6.5.7 / ipykernel 6.15.2 / tornado 6.2 | pip 固定版本 + `--no-cache-dir` |
| 1.1 Jupyter 配置（8888 端口 / token / NB_PREFIX 等） | `jupyter_notebook_config.py` 安装到 `/etc/jupyter/` |
| 1.1 tini entrypoint | `ENTRYPOINT ["tini", "--", "bash", "-c", "jupyter lab --config=..."]` |
| 1.2 / 2.3 nfs-common | 已安装；mlnx RDMA 组件做成可选 `--build-arg INSTALL_MLNX=true`（默认关闭） |
| 2 防镜像过大 | pip 全部 `--no-cache-dir`，下载物同层 `rm` 清理 |

对规范原文的一处修正：原文 `ENTRYPOINT ["tini","--","bash","-c","jupyter","lab","jupyter_notebook_config.py"]` 的 `bash -c` 参数拼接有误（`bash -c` 只接受一个命令字符串，后面参数会变成 `$0`），按其意图改为 `bash -c "jupyter lab --config=/etc/jupyter/jupyter_notebook_config.py"`。

## 使用步骤

1. 在 GitHub 新建仓库，把本目录全部内容推上去（含 `.github/workflows/`）。
2. push 到 `main` 或打 `v*` tag 即触发构建；产物推到 `ghcr.io/<你的用户名>/<仓库名>:latest`（Actions 自动用 `GITHUB_TOKEN` 登录 GHCR，无需配置 secrets）。
3. 公共仓库可以把 workflow 里 `runs-on: ubuntu-24.04` + QEMU 换成 `runs-on: ubuntu-24.04-arm` 原生 arm runner（删掉 Set up QEMU 步骤），速度快数倍。

## 运行

```bash
docker run -d --rm \
  -p 8888:8888 \
  -e JUPYTER_TOKEN=your-token \
  ghcr.io/<owner>/<repo>:latest
```

浏览器访问 `http://<host>:8888`，token 用 `JUPYTER_TOKEN` 的值。平台侧注入 `NB_PREFIX`（路径前缀）、`ORIGIN`（前端嵌入）、`JUPYTER_PASSWORD`（密码登录）均按配置文件生效。

## 注意事项

- 基础镜像仅 arm64，QEMU 交叉构建整包 pip 安装约需 10~25 分钟，属正常；开启 GHA cache 后会显著加快。
- `tornado==6.2` 为规范建议版本；如与基础镜像内已有包冲突导致 pip 解析失败，把该固定行删掉让 pip 自行解析即可。
- mlnx（RDMA）默认不装：昇腾环境的分布式通信走 HCCL/HCCN，一般不需要 mlnx；确需时加 `--build-arg INSTALL_MLNX=true` 并核对 Dockerfile 内注释的下载地址版本。
