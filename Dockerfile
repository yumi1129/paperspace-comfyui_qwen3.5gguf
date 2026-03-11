# 改善点1: PyTorch (cu124) とバージョンを合わせるため、CUDA 12.4系のdevelイメージに変更
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

ENV LANG=C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

# llama-cpp-python のビルド用環境変数
ENV CMAKE_ARGS="-DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=86"
ENV FORCE_CMAKE=1
# 改善点2: GitHub Actionsのメモリ不足（OOM）を防ぐため、並列ビルド数を制限
ENV MAX_JOBS=2

# 改善点3: ビルドを安定させるため ninja-build を追加
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git wget ffmpeg libgl1 libglib2.0-0 \
    python3.10 python3-pip python3-dev \
    aria2 git-lfs unzip curl \
    nodejs npm ninja-build \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# pythonコマンドでpython3が動くようにする
RUN ln -s /usr/bin/python3 /usr/bin/python

# PyTorchをインストール (安定のcu124を指定)
RUN pip install --no-cache-dir torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu124

# 高速化ライブラリ、LLM/VLM用ライブラリ、Jupyter用ツールを追加
RUN pip install --no-cache-dir xformers triton transformers pillow vllm sglang huggingface_hub jupyterlab jupyter-server-proxy

# llama-cpp-python を事前ビルドしてインストール
# ※ MAX_JOBS=2 が効くため、メモリ不足で落ちにくくなります
RUN pip install --upgrade --no-cache-dir "llama-cpp-python==0.3.16"

# llama-server をコンテナのシステム領域（/opt）に事前ビルドして配置
# 改善点4: cmakeのビルドオプション -j を -j 2 に変更してメモリを節約
RUN git clone https://github.com/ggml-org/llama.cpp.git /opt/llama.cpp && \
    cd /opt/llama.cpp && \
    cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=86 -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j 2 && \
    ln -sf /opt/llama.cpp/build/bin/llama-server /usr/local/bin/llama-server

# ComfyUIと各カスタムノードの依存パッケージを一時的にクローンして事前インストール
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /tmp/ComfyUI && \
    pip install --no-cache-dir -r /tmp/ComfyUI/requirements.txt && \
    git clone https://github.com/FranckyB/ComfyUI-Prompt-Manager.git /tmp/ComfyUI-Prompt-Manager && \
    pip install --no-cache-dir -r /tmp/ComfyUI-Prompt-Manager/requirements.txt && \
    git clone https://github.com/lihaoyun6/ComfyUI-llama-cpp.git /tmp/ComfyUI-llama-cpp && \
    pip install --no-cache-dir -r /tmp/ComfyUI-llama-cpp/requirements.txt && \
    rm -rf /tmp/ComfyUI /tmp/ComfyUI-Prompt-Manager /tmp/ComfyUI-llama-cpp

# ポートを開放して作業ディレクトリを設定
EXPOSE 8888 8188 6006 8000 
WORKDIR /notebooks
