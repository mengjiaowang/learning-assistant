# Word Buddy

一个基于 AI (Gemini 3.1) 和 Firestore 的智能单词学习与复习应用。

## 功能特点

- **单词录入与 OCR**：拍照或上传图片，自动提取单词。
- **AI 智能学习**：利用 Gemini 3.1 生成自然拼读、词源、中文意思及智能例句。
- **间隔重复复习**：基于莱特纳盒子 (Leitner Box) 系统的遗忘曲线复习。
- **AI 单元测试**：智能生成选择题，检验学习成果。
- **数据可视化**：高颜值看板展示学习进度和本周活跃度。

## 本地启动指南

### 前提条件

- 已安装 Flutter SDK。
- 已安装 Python 3.12+（推荐使用 `uv` 管理依赖）。
- 已安装 Google Cloud SDK (`gcloud`) 并完成身份验证。

### 1. 环境配置

在项目根目录下确认或创建 `.env` 文件，填入您的 GCP 项目 ID 和数据库 ID：

```env
GCP_PROJECT_ID=learning-assistant-490905
FIRESTORE_DATABASE_ID=word-buddy-db
```

确保您已在本地完成 GCP 身份验证：

```bash
gcloud auth application-default login
```

### 2. 启动后端 (FastAPI)

```bash
cd backend
# 安装依赖
export UV_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
uv pip install -r requirements.txt
# 启动服务 (注意：是 main:app 而不是 app.main:app)
uvicorn main:app --reload --port 8000
```

后端服务将运行在 `http://127.0.0.1:8000`。

### 3. 启动前端 (Flutter Web)

```bash
cd frontend
# 获取依赖
flutter pub get
# 启动 Web 端
flutter run -d chrome
```

前端将自动在 Chrome 浏览器中打开。
