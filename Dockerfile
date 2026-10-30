# syntax=docker/dockerfile:1
# ============================================================
# 昇腾 vLLM Notebook 自定义镜像（arm64）
# 基础镜像已内置：CANN、torch、torch_npu、vllm（规范 2.4/2.5 华为生态部分无需重装）
# 本镜像按《自定义镜像规范》补齐 notebook 运行环境
# ============================================================
FROM quay.io/ascend/vllm-ascend:v0.18.0-a3

ARG DEBIAN_FRONTEND=noninteractive
# 仅当容器需要使用 RDMA 网卡时置 true（规范 2.3，mlnx 用户态组件）
ARG INSTALL_MLNX=false

USER root

# ---------- 规范 1.1 必备软件：tini / python3 / nodejs ----------
# ---------- 规范 1.2 扩展依赖：nfs-common（挂载文件存储/AI原生存储需要） ----------
RUN apt-get update && \
    apt-get -yq install --no-install-recommends \
        tini \
        nodejs \
        npm \
        nfs-common && \
    rm -rf /var/lib/apt/lists/*

# ---------- 规范 2.3（可选）mlnx 用户态组件：需要 RDMA 时再加 ----------
# 构建时加 --build-arg INSTALL_MLNX=true 启用；版本/系统按实际替换
# RUN if [ "$INSTALL_MLNX" = "true" ]; then \
#         cd /tmp && \
#         wget -q https://content.mellanox.com/ofed/MLNX_OFED-24.10-0.7.0.0/MLNX_OFED_LINUX-24.10-0.7.0.0-ubuntu22.04-aarch64.tgz && \
#         tar xzf MLNX_OFED_LINUX-*.tgz && \
#         ./MLNX_OFED_LINUX-*/mlnxofedinstall --user-space-only --force --without-fw-update && \
#         rm -rf /tmp/MLNX_OFED_LINUX-* ; \
#     fi

# ---------- 规范 1.1 Python 依赖包（建议版本）----------
# 规范 2：pip 必须加 --no-cache-dir 防止镜像过大
RUN pip install --no-cache-dir \
        "jupyterlab==3.6.3" \
        "notebook==6.5.7" \
        "ipykernel==6.15.2" \
        "tornado==6.2"

# ---------- 规范 2.6 训练任务额外依赖（按需修改 requirements.txt，空文件自动跳过）----------
COPY requirements.txt /tmp/requirements.txt
RUN if [ -s /tmp/requirements.txt ]; then pip install --no-cache-dir -r /tmp/requirements.txt; fi && \
    rm -f /tmp/requirements.txt

# ---------- 规范 1.1 Jupyter 配置 ----------
COPY jupyter_notebook_config.py /etc/jupyter/jupyter_notebook_config.py

ENV HOME=/root \
    SHELL=/bin/bash \
    JUPYTER_TOKEN=""

# 规范 1.1：notebook 监听端口必须是 8888
EXPOSE 8888

WORKDIR /root

# 规范 1.1：tini 作为 1 号进程启动 jupyter，防止僵尸进程
# （规范原文 bash -c 参数拼接有误，这里按其意图改为显式 --config 指向配置文件）
ENTRYPOINT ["tini", "--", "bash", "-c", "jupyter lab --config=/etc/jupyter/jupyter_notebook_config.py"]
