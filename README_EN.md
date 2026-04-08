[English](README_EN.md) | [中文](README.md)

# Learning Assistant Platform

`Learning Assistant` is an intelligent learning support platform designed for family scenarios, featuring "high-powered AI assistance, multi-module integration, and immersive learning." The platform currently contains two core applications and supports future expansion.

---

## 📖 1. Core Functional Modules

### 📝 Mistake Mentor
Designed to solve the time-consuming and laborious problem of students organizing mistake sets:
1. **Restore Blank Questions**: Pixel-level erasure of handwritten corrections and answer traces through Google Cloud's multimodal visual large model.
2. **Precise Digitization of Formulas and Text**: Use `Gemini 3.1` to extract text and align `LaTeX` formula symbols.
3. **Heuristic AI Analysis and One-click "Draw Inferences"**: Do not give answers directly, but give step-by-step reasoning and similar variant training questions. Learn a class by doing one question.
4. **Immersive Voice Broadcast (TTS)**: Integrate Google Cloud TTS to support high-quality reading of question analysis.

### 🔤 Word Buddy
A word memorization application designed for children (aged 6-12):
1. **Intelligent OCR Extraction**: Take a photo of a textbook or test paper, intelligently identify and extract core vocabulary, and filter out meaningless function words.
2. **Child-friendly Analysis**: Use vivid language to generate natural phonics, fun roots, and example sentences for words.
3. **Smart Quiz Generation**: Generate fun multiple-choice questions for each word based on the large model to consolidate memory.
4. **Leitner Review System**: Dynamically adjust the review cycle based on the degree of mastery.

---

## 🛠️ 2. Technical Architecture

### 🖥️ Backend Architecture (`/apps`)
Based on **FastAPI (Python)** deployed on **Google Cloud Run**, adopting a multi-service architecture:
*   **Mistake Mentor** (`apps/mistake_mentor`): Provides mistake processing, OCR analysis, and TTS services.
*   **Word Buddy** (`apps/word_buddy`): Provides word management, child-friendly analysis, and quiz generation services.

### 📱 Frontend Client Architecture (`/frontend`)
Built with **Flutter**, supporting Web, tablet, and large screen devices.
*   Enter different application modules through a unified navigation page.
*   Use Firebase Hosting's Rewrites rules to achieve smart distribution to different Cloud Run backends by path.

---

## 💻 3. Local Development and Debugging

### ⚠️ Must Read Before Calling AI Interfaces in Local Environment
Calling Vertex AI has preset permission verification. Before starting to test the backend, please open your Mac terminal to pull local credentials with one click:
```bash
gcloud auth application-default login
firebase login --reauth
```

### 3.1 Step 1: Create and Activate Virtual Environment
```bash
# Ensure uv is installed
uv venv
source .venv/bin/activate
```

### 3.2 Step 2: Install Dependency Packages
```bash
# Install Mistake Mentor dependencies
uv pip install -r apps/mistake_mentor/requirements.txt
# Install Word Buddy dependencies
uv pip install -r apps/word_buddy/requirements.txt
```

### 3.3 Step 3: Start Local Backend Services
To avoid port conflicts, please start the two services on different ports:

*   **Start Mistake Mentor Backend** (using port 8000):
    ```bash
    cd apps/mistake_mentor
    uvicorn app.main:app --reload --port 8000
    ```
*   **Start Word Buddy Backend** (using port 8001):
    ```bash
    cd apps/word_buddy
    uvicorn main:app --reload --port 8001
    ```

### 3.4 Step 4: Frontend Local Development and Debugging (Flutter)
```bash
cd frontend
flutter pub get
flutter run -d chrome
```
> 💡 **Tip**: The frontend has been configured with environment smart switching. When running locally, it will automatically connect to local ports `8000` and `8001`; after deploying to Firebase, it will automatically use relative paths distributed by the cloud.

---

## 🚢 4. Cloud Full-stack One-click Deployment

The project provides a one-click compilation and release script, supporting on-demand deployment:

```bash
# Grant execution permissions
chmod +x deploy.sh

# Deploy all content (Frontend + Backend)
./deploy.sh all

# Independently deploy specific modules:
./deploy.sh mistake_mentor  # Deploy only Mistake Mentor backend
./deploy.sh word_buddy      # Deploy only Word Buddy backend
./deploy.sh frontend        # Deploy only frontend
```

The script will automatically handle the creation of Artifact Registry image repositories, Cloud Build image compilation, and Cloud Run deployment.

---

## 🔑 5. Built-in Super Test Account

*   **Username**: `admin`
*   **Password**: Please check `ADMIN_PASSWORD` in your local `.env` file.
