[English](README_EN.md) | [中文](README.md)

# 学习助手平台 (Learning Assistant Platform)

`Learning Assistant` 是一款专为家庭场景设计的智能学习辅助平台，主打“高能 AI 辅助、多模块整合、沉浸式学习”。目前平台包含两个核心应用，并支持未来扩展。

---

## 📖 1. 核心功能模块

### 📝 智能错题本 (Mistake Mentor)
专为解决学生整理错题集耗时费力的问题：
1. **还原空白题目**：通过谷歌云多模态视觉大模型像素级擦除手写批改和答案痕迹。
2. **公式及文字精准数字化**：利用 `Gemini 3.1` 提取文本、对齐 `LaTeX` 公式符号。
3. **启发式 AI 解析及一键“举一反三”**：不直接给答案，而是给出分步推理和相似的变式训练题，做一题学一类。
4. **沉浸式语音播报 (TTS)**：集成 Google Cloud TTS，支持高质量的题目解析朗读。

### 🔤 单词助手 (Word Buddy)
专为儿童（6-12岁）设计的背单词应用：
1. **智能 OCR 提取**：拍下课本或试卷，智能识别并提取核心词汇，过滤无意义的虚词。
2. **儿童友好型解析**：使用生动的语言生成单词的自然拼读、趣味字根及例句。
3. **智能生成测验**：基于大模型为每个单词生成趣味选择题，巩固记忆。
4. **莱特纳（Leitner）复习系统**：根据掌握程度动态调整复习周期。

---

## 🛠️ 2. 技术架构

### 🖥️ 后端架构 (`/apps`)
基于 **FastAPI (Python)** 部署于 **Google Cloud Run**，采用多服务架构：
*   **Mistake Mentor** (`apps/mistake_mentor`)：提供错题处理、OCR 解析和 TTS 服务。
*   **Word Buddy** (`apps/word_buddy`)：提供单词管理、儿童友好解析和测验生成服务。

### 📱 前端客户端架构 (`/frontend`)
使用 **Flutter** 构建，支持 Web、平板和大屏设备。
*   通过统一的导航页进入不同的应用模块。
*   利用 Firebase Hosting 的 Rewrites 规则，实现按路径智能分流到不同的 Cloud Run 后端。

---

## 💻 3. 本地开发与调试

### ⚠️ 本地环境调用 AI 接口前必读
调用 Vertex AI 预置了权限校验。开始测试后端前，请打开您的 Mac 终端一键拉取本地凭证：
```bash
gcloud auth application-default login
firebase login --reauth
```

### 3.1 步骤一：创建并激活虚拟环境
```bash
# 确保已安装 uv
uv venv
source .venv/bin/activate
```

### 3.2 步骤二：安装依赖包
```bash
# 更换pip源
export UV_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
# 安装错题本依赖
uv pip install -r apps/mistake_mentor/requirements.txt
# 安装单词助手依赖
uv pip install -r apps/word_buddy/requirements.txt
```

### 3.3 步骤三：启动本地后端服务
为了避免端口冲突，请在不同端口启动两个服务：

*   **启动错题本后端**（使用 8000 端口）：
    ```bash
    cd apps/mistake_mentor
    uvicorn app.main:app --reload --port 8000
    ```
*   **启动单词助手后端**（使用 8001 端口）：
    ```bash
    cd apps/word_buddy
    uvicorn main:app --reload --port 8001
    ```

### 3.4 步骤四：前端本地开发调试 (Flutter)
```bash
cd frontend
flutter pub get
flutter run -d chrome
```
> 💡 **小贴士**：前端已配置环境智能切换。本地运行时会自动连接本地的 `8000` 和 `8001` 端口；部署到 Firebase 后会自动使用相对路径由云端分流。

---

## 🚢 4. 云端全栈一键部署

项目提供了一键编译发布脚本，支持按需部署：

```bash
# 赋予执行权限
chmod +x deploy.sh

# 部署所有内容 (前后端)
./deploy.sh all

# 独立部署特定模块:
./deploy.sh mistake_mentor  # 仅部署错题本后端
./deploy.sh word_buddy      # 仅部署单词助手后端
./deploy.sh frontend        # 仅部署前端
```

脚本会自动处理 Artifact Registry 镜像仓库的创建、Cloud Build 镜像编译以及 Cloud Run 部署。

---

## 🔑 5. 内置超级测试账号

*   **用户名**：`admin`
*   **密码**：请查看您本地 `.env` 文件中的 `ADMIN_PASSWORD`。
