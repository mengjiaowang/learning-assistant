# 技术需求文档 (TRD) - Word Buddy

## 1. 系统架构概述
本系统采用前后端分离的架构，完全基于 Google Cloud 生态构建。
*   **前端**: 使用 **Flutter (Web)** 构建响应式网页应用，专注于平板和桌面端体验。
*   **后端**: 使用 **Python (FastAPI)** 构建服务，部署在 **Google Cloud Run** 上。
*   **数据库**: 使用 **Google Cloud Firestore** 作为 NoSQL 数据库。
*   **AI 服务**: 统一使用 **Google Gemini API** 实现 OCR、内容生成等所有 AI 功能。

## 2. 前端需求 (Flutter Web)
*   **平台目标**: 网页端 (Web)，重点优化 **平板 (Tablet)** 和 **桌面 (Desktop)** 的大屏体验。
*   **技术栈**:
    *   Flutter SDK (最新稳定版)
    *   状态管理: Riverpod 或 Provider
    *   图表库: fl_chart (用于数据视觉化)
*   **核心页面与交互**:
    *   **单词录入页**: 支持文件上传（图片）以进行 OCR 识别，以及文本批量输入。
    *   **学习详情页**: 展示单词的详细背景知识（音标、自然拼读、词源、词根词缀、AI例句）。
    *   **复习卡片页**: 实现卡片翻转动画，支持快捷键或手势标记记忆程度。
    *   **单词墙**: 响应式网格布局，展示海量单词。
    *   **统计打卡页**: 包含热力图（类似 GitHub contribution）和进度图表。

## 3. 后端需求 (Python / Cloud Run)
*   **框架**: FastAPI (异步高性能，方便集成 Gemini SDK)。
*   **部署**: Google Cloud Run (无服务器容器托管，支持按需缩放，降低初期成本)。
*   **核心模块**:
    *   **OCR 模块**: 接收前端上传的图片，调用 Gemini 3.1 Multimodal 模型提取单词。
    *   **内容生成模块**: 调用 Gemini 模型生成单词的词源、词根、自然拼读规则及智能例句。
    *   **复习算法模块**: 实现基于艾宾浩斯遗忘曲线的间隔重复（SRS）算法，计算每日复习任务。
    *   **统计模块**: 聚合用户学习数据，供前端展示。

## 4. AI 与 Gemini 集成
系统**所有** AI 功能均使用 Gemini 3.1 模型，通过 Google Gen AI SDK 或 Vertex AI 接入。
*   **拍照识词 (OCR)**:
    *   **模型**: Gemini 3.1 (具备强大的多模态能力和极高的性价比)。
    *   **实现**: 将用户上传的图片（Base64 或 GCS 链接）发送给 Gemini，配合 Prompt（例如："请提取图中所有的英文单词，以 JSON 列表格式返回"）。
*   **单词背景知识生成**:
    *   **模型**: Gemini 3.1。
    *   **实现**: 针对录入的单词，提示词要求返回结构化的 JSON 数据，包含 `phonics`, `etymology`, `roots_affixes` 等字段。
*   **智能例句生成**:
    *   **模型**: Gemini 3.1。
    *   **实现**: 根据单词生成语境自然的例句，并提供中文翻译。

## 5. 数据存储 (Firestore)
使用 Firestore 存储非结构化数据，设计如下集合（Collections）：
*   **Users**: 用户基础信息及学习配置。
*   **Words**: 单词字典缓存（避免重复调用 Gemini 生成相同单词的背景知识，节省成本）。
    *   字段包括: 单词、音标、自然拼读、词源、词根词缀、默认释义等。
*   **UserWords**: 用户单词关联表（核心复习数据）。
    *   字段包括: `user_id`, `word_id`, 掌握熟练度, 上次复习时间, 下次复习时间, 错误次数等。
*   **ErrorBook**: 用户错题记录。

## 6. 部署与运维 (Google Cloud)
*   **前端部署**: 编译为 Web 静态文件，部署在 **Firebase Hosting** 或 **Cloud Storage Bucket** 上，配合 Cloud CDN 加速。
*   **后端部署**: 编写 Dockerfile，通过 Cloud Build 构建镜像并推送到 Artifact Registry，最终部署在 **Cloud Run**。
*   **安全**:
    *   使用 API Gateway 或直接在 Cloud Run 上配置 IAM 鉴权。
    *   Gemini API Key 存储在 **Secret Manager** 中，后端服务通过环境变量安全读取。
