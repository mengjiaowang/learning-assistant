#!/bin/bash

# ==========================================
# 学习助手 (Learning Assistant) - 部署脚本
# ==========================================

USAGE="
用法: ./deploy.sh [target]

目标 (target):
  all             部署所有后端和前端 (默认)
  mistake_mentor  仅部署错题本后端
  word_buddy      仅部署单词助手后端
  frontend        仅部署前端 Web 到 Firebase Hosting
  help            显示此帮助信息
"

TARGET=${1:-all}

if [ "$TARGET" == "help" ]; then
    echo "$USAGE"
    exit 0
fi

VALID_TARGETS=("all" "mistake_mentor" "word_buddy" "frontend")
if [[ ! " ${VALID_TARGETS[@]} " =~ " ${TARGET} " ]]; then
    echo "❌ 错误: 无效的目标参数 '$TARGET'"
    echo "$USAGE"
    exit 1
fi

# ==========================================
# 授权检查
# ==========================================
echo "🔍 检查 Google Cloud 授权状态..."
if ! gcloud auth application-default print-access-token >/dev/null 2>&1 && ! gcloud auth print-access-token >/dev/null 2>&1; then
    echo "❌ 错误: Google Cloud 凭证已过期或未获取。"
    echo "💡 请先执行: gcloud auth application-default login"
    exit 1
fi

if [[ "$TARGET" == "all" || "$TARGET" == "frontend" ]]; then
    echo "🔍 检查 Firebase 授权状态..."
    if ! firebase projects:list >/dev/null 2>&1; then
        echo "❌ 错误: Firebase 凭证已过期或未获取。"
        echo "💡 请先执行: firebase login --reauth"
        exit 1
    fi
fi

# ==========================================
# 加载配置文件 (.env)
# ==========================================
if [ -f .env ]; then
    echo "📜 加载 .env 配置文件..."
    export $(grep -v '^#' .env | xargs)
fi

if [ -z "$PROJECT_ID" ]; then
    echo "❌ 错误: 未设置 PROJECT_ID 环境变量！"
    echo "💡 请在 .env 文件中配置 PROJECT_ID"
    exit 1
fi

REGION="asia-northeast1"
REPO_NAME="learning-assistant-docker"

echo "========================================"
echo "🚀 开始部署 [ $PROJECT_ID ] | 模式: $TARGET"
echo "========================================"

gcloud config set project $PROJECT_ID

# 创建 Artifact Registry 仓库 (如果不存在)
if [[ "$TARGET" == "all" || "$TARGET" == "mistake_mentor" || "$TARGET" == "word_buddy" ]]; then
    echo "📦 正在检查并创建 Artifact Registry 镜像仓库..."
    if ! gcloud artifacts repositories describe $REPO_NAME --location=$REGION > /dev/null 2>&1; then
        gcloud artifacts repositories create $REPO_NAME \
            --repository-format=docker \
            --location=$REGION \
            --description="Learning Assistant Docker Repo"
        echo "✅ 镜像仓库 $REPO_NAME 创建成功！"
    else
        echo "ℹ️ 镜像仓库 $REPO_NAME 已存在。"
    fi
fi

# 1. 部署 Mistake Mentor 后端
if [[ "$TARGET" == "all" || "$TARGET" == "mistake_mentor" ]]; then
    echo ""
    echo "----------------------------------------"
    echo "📦 正在部署 Mistake Mentor 后端 (Cloud Run)..."
    echo "----------------------------------------"
    cd apps/mistake_mentor
    
    SERVICE_NAME="mistakementor-backend"
    IMAGE_TAG="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/$SERVICE_NAME"
    
    echo "🛠️ 正在使用 Cloud Build 提交构建..."
    gcloud builds submit --tag $IMAGE_TAG .
    
    echo "🚢 正在发布到 Cloud Run..."
    gcloud run deploy $SERVICE_NAME \
      --image $IMAGE_TAG \
      --platform managed \
      --region $REGION \
      --allow-unauthenticated \
      --cpu 1 \
      --memory 4Gi \
      --port 8080 \
      --set-env-vars "PROJECT_ID=$PROJECT_ID,MISTAKE_MENTOR_FIRESTORE_DB=$MISTAKE_MENTOR_FIRESTORE_DB,SECRET_KEY=$SECRET_KEY,ADMIN_PASSWORD=$ADMIN_PASSWORD,ADMIN_USERNAME=$ADMIN_USERNAME,ACCESS_TOKEN_EXPIRE_MINUTES=$ACCESS_TOKEN_EXPIRE_MINUTES,ERASURE_MODEL=$ERASURE_MODEL,GEMINI_MODEL_NAME=$GEMINI_MODEL_NAME"
      
    cd ../..
fi

# 2. 部署 Word Buddy 后端
if [[ "$TARGET" == "all" || "$TARGET" == "word_buddy" ]]; then
    echo ""
    echo "----------------------------------------"
    echo "📦 正在部署 Word Buddy 后端 (Cloud Run)..."
    echo "----------------------------------------"
    cd apps/word_buddy
    
    SERVICE_NAME="wordbuddy-backend"
    IMAGE_TAG="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/$SERVICE_NAME"
    
    echo "🛠️ 正在使用 Cloud Build 提交构建..."
    gcloud builds submit --tag $IMAGE_TAG .
    
    echo "🚢 正在发布到 Cloud Run..."
    gcloud run deploy $SERVICE_NAME \
      --image $IMAGE_TAG \
      --platform managed \
      --region $REGION \
      --allow-unauthenticated \
      --cpu 1 \
      --memory 2Gi \
      --port 8080 \
      --set-env-vars "PROJECT_ID=$PROJECT_ID,WORD_BUDDY_FIRESTORE_DB=$WORD_BUDDY_FIRESTORE_DB,SECRET_KEY=$SECRET_KEY,GEMINI_MODEL_NAME=$GEMINI_MODEL_NAME"
      
    cd ../..
fi

# 3. 部署前端
if [[ "$TARGET" == "all" || "$TARGET" == "frontend" ]]; then
    echo ""
    echo "----------------------------------------"
    echo "🌐 正在部署前端 (Firebase Hosting)..."
    echo "----------------------------------------"
    cd frontend
    echo "🛠️ 正在清理并打包 Flutter Web (Release 模式)..."
    flutter clean
    flutter pub get
    flutter build web --release
    
    echo "🚀 正在推送到 Firebase Hosting..."
    firebase deploy --only hosting --project $PROJECT_ID
    cd ..
fi

echo "========================================"
echo "🎉 部署流程结束！"
echo "========================================"
