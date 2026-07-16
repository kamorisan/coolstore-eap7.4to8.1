#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "=========================================="
echo "  EAP アプリケーション デプロイメント"
echo "  (Containerfile + BuildConfig方式)"
echo "=========================================="
echo ""

# 現在のプロジェクト確認
CURRENT_PROJECT=$(oc project -q)
echo "デプロイ先プロジェクト: $CURRENT_PROJECT"
echo ""

# PostgreSQL確認
echo "前提条件を確認中..."
if ! oc get secret coolstore-db-secret &>/dev/null; then
    echo "✗ エラー: Secret 'coolstore-db-secret' が見つかりません"
    echo "  先にPostgreSQLをデプロイしてください:"
    echo "  cd ../postgresql && ./deploy.sh"
    exit 1
fi

if ! oc get pods -l component=database | grep -q Running; then
    echo "✗ エラー: PostgreSQL Podが実行されていません"
    echo "  先にPostgreSQLをデプロイしてください:"
    echo "  cd ../postgresql && ./deploy.sh"
    exit 1
fi
echo "✓ PostgreSQLとSecretが確認できました"

echo ""
read -p "このプロジェクトにデプロイしますか？ (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "中止しました"
    exit 1
fi

# 既存リソース削除
echo ""
echo "1. 既存リソースをクリーンアップ中..."
oc delete deployment coolstore-eap74 --ignore-not-found=true
oc delete service coolstore-eap74 --ignore-not-found=true
oc delete route coolstore-eap74 --ignore-not-found=true
oc delete buildconfig coolstore-eap74 --ignore-not-found=true
oc delete imagestream coolstore-eap74 --ignore-not-found=true
sleep 2

echo ""
echo "2. ImageStreamを作成中..."
oc apply -f "$SCRIPT_DIR/imagestream.yaml"

echo ""
echo "3. BuildConfigを作成中..."
oc apply -f "$SCRIPT_DIR/buildconfig.yaml"

echo ""
echo "4. ビルドを開始中（Containerfile + Maven）..."
echo "   GitHubリポジトリからソースを取得してビルドします"
echo "   ビルド時間: 約5-10分（Mavenビルド + コンテナイメージ作成）"
echo ""

# 最新のビルドを待機
sleep 5
BUILD_NAME=$(oc get builds -l buildconfig=coolstore-eap74 --sort-by=.metadata.creationTimestamp -o name | tail -1)

if [ -z "$BUILD_NAME" ]; then
    echo "✗ エラー: ビルドが開始されませんでした"
    exit 1
fi

echo "   ビルド名: $BUILD_NAME"
echo ""
echo "   ビルドログを表示しています..."
echo ""

# ビルドログをフォロー
oc logs -f $BUILD_NAME || {
    echo "✗ エラー: ビルドログの取得に失敗しました"
    exit 1
}

# ビルド完了確認
BUILD_PHASE=$(oc get $BUILD_NAME -o jsonpath='{.status.phase}')
if [ "$BUILD_PHASE" != "Complete" ]; then
    echo ""
    echo "✗ エラー: ビルドが失敗しました (Phase: $BUILD_PHASE)"
    echo "  詳細確認: oc describe $BUILD_NAME"
    exit 1
fi

echo ""
echo "   ✓ ビルド完了"

echo ""
echo "5. Deploymentを作成中..."
oc apply -f "$SCRIPT_DIR/deployment.yaml"

echo ""
echo "6. Serviceを作成中..."
oc apply -f "$SCRIPT_DIR/service.yaml"

echo ""
echo "7. Routeを作成中..."
oc apply -f "$SCRIPT_DIR/route.yaml"

echo ""
echo "8. Pod起動を待機中..."
oc wait --for=condition=ready pod -l component=application --timeout=300s || {
    echo "✗ エラー: Pod起動がタイムアウトしました"
    echo "  ログ確認: oc logs -f deployment/coolstore-eap74"
    exit 1
}

echo ""
echo "9. デプロイメント検証中..."
ROUTE_URL=$(oc get route coolstore-eap74 -o jsonpath='{.spec.host}')
DEPLOYMENT_STATUS=$(oc get deployment coolstore-eap74 -o jsonpath='{.status.availableReplicas}')

echo "   ✓ Deployment: coolstore-eap74 (Available Replicas: $DEPLOYMENT_STATUS)"
echo "   ✓ Route: https://$ROUTE_URL"

echo ""
echo "=========================================="
echo "  デプロイ完了！"
echo "=========================================="
echo ""
echo "アプリケーション情報:"
echo "  - URL: https://$ROUTE_URL"
echo "  - Service: coolstore-eap74:8080"
echo "  - Database: postgresql:5432"
echo ""
echo "動作確認:"
echo "  curl -k https://$ROUTE_URL"
echo ""
echo "ログ確認:"
echo "  oc logs -f deployment/coolstore-eap74"
echo ""
