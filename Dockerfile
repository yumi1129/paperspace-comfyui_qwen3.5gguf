# ベースイメージをPyTorch(cu124)に合わせたバージョンに変更
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

ENV LANG=C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

# ビルドツールと必要パッケージのインストール
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git wget ffmpeg libgl1 libglib2.0-0 \
    python3.10 python3-pip python3-dev \
    aria2 git-lfs unzip curl \
    nodejs npm ninja-build \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3 /usr/bin/python

# PyTorchをインストール
RUN pip install --no-cache-dir torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu124

# 各種ライブラリをインストール
RUN pip install --no-cache-dir xformers triton transformers pillow vllm sglang huggingface_hub jupyterlab jupyter-server-proxy

# ★修正点：エラーの原因となるコンパイルを避け、CUDA 12.4 向けビルド済みバイナリをインストール
# （※こちらの配布URLは、ご提示いただいたソース外の一般的な公式配布の知識に基づいています）
RUN pip install --no-cache-dir llama-cpp-python==0.3.16 --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cu124

# llama-server を事前ビルド（メモリ不足回避のため -j 2 を指定）
RUN git clone https://github.com/ggml-org/llama.cpp.git /opt/llama.cpp && \
    cd /opt/llama.cpp && \
    cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=86 -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j 2 && \
    ln -sf /opt/llama.cpp/build/bin/llama-server /usr/local/bin/llama-server

# ComfyUIと各カスタムノードの事前準備
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /tmp/ComfyUI && \
    pip install --no-cache-dir -r /tmp/ComfyUI/requirements.txt && \
    git clone https://github.com/FranckyB/ComfyUI-Prompt-Manager.git /tmp/ComfyUI-Prompt-Manager && \
    pip install --no-cache-dir -r /tmp/ComfyUI-Prompt-Manager/requirements.txt && \
    git clone https://github.com/lihaoyun6/ComfyUI-llama-cpp.git /tmp/ComfyUI-llama-cpp && \
    pip install --no-cache-dir -r /tmp/ComfyUI-llama-cpp/requirements.txt && \
    rm -rf /tmp/ComfyUI /tmp/ComfyUI-Prompt-Manager /tmp/ComfyUI-llama-cpp

EXPOSE 8888 8188 6006 8000 
WORKDIR /notebooks
