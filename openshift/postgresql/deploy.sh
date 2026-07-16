#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "=========================================="
echo "  PostgreSQL デプロイメント"
echo "=========================================="
echo ""

# 現在のプロジェクト確認
CURRENT_PROJECT=$(oc project -q)
echo "デプロイ先プロジェクト: $CURRENT_PROJECT"
echo ""

read -p "このプロジェクトにデプロイしますか？ (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "中止しました"
    exit 1
fi

echo ""
echo "1. データベース認証情報を作成中..."
oc apply -f "$SCRIPT_DIR/secret-database.yaml"

echo ""
echo "2. 永続ボリュームを作成中..."
oc apply -f "$SCRIPT_DIR/postgresql-pvc.yaml"

echo ""
echo "3. PostgreSQL Serviceを作成中..."
oc apply -f "$SCRIPT_DIR/postgresql-service.yaml"

echo ""
echo "4. PostgreSQL Deploymentをデプロイ中..."
oc apply -f "$SCRIPT_DIR/postgresql-deployment.yaml"

echo ""
echo "5. PostgreSQLの起動を待機中..."
oc wait --for=condition=ready pod -l component=database --timeout=120s || {
    echo "エラー: PostgreSQLの起動がタイムアウトしました"
    echo "以下のコマンドでログを確認してください:"
    echo "  oc logs \$(oc get pods -l component=database -o name)"
    exit 1
}

echo ""
echo "6. 初期データ用ConfigMapを作成中..."
oc apply -f "$SCRIPT_DIR/db-init-configmap.yaml"

echo ""
echo "7. 初期データ投入Jobを実行中..."
oc apply -f "$SCRIPT_DIR/db-init-job.yaml"

echo ""
echo "8. 初期データ投入の完了を待機中..."
oc wait --for=condition=complete job/db-init --timeout=60s || {
    echo "エラー: 初期データ投入がタイムアウトしました"
    echo "以下のコマンドでログを確認してください:"
    echo "  oc logs job/db-init"
    exit 1
}

echo ""
echo "9. データ投入の検証中..."
PRODUCT_COUNT=$(oc exec $(oc get pods -l component=database -o jsonpath='{.items[0].metadata.name}') -- psql -U coolstore -d coolstore -t -c "SELECT COUNT(*) FROM PRODUCT_CATALOG;" 2>/dev/null | tr -d ' ')

if [ "$PRODUCT_COUNT" -eq 9 ]; then
    echo "   ✓ 商品データ: $PRODUCT_COUNT 件"
else
    echo "   ✗ 警告: 商品データが期待値(9件)と異なります: $PRODUCT_COUNT 件"
fi

echo ""
echo "=========================================="
echo "  デプロイ完了！"
echo "=========================================="
echo ""
echo "PostgreSQL情報:"
echo "  - Service名: postgresql"
echo "  - ポート: 5432"
echo "  - データベース名: coolstore"
echo "  - ユーザー名: coolstore"
echo ""
echo "接続確認:"
echo "  oc exec \$(oc get pods -l component=database -o name) -- psql -U coolstore -d coolstore -c '\\dt'"
echo ""
