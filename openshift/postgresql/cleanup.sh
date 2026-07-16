#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "=========================================="
echo "  PostgreSQL クリーンアップ"
echo "=========================================="
echo ""

# 現在のプロジェクト確認
CURRENT_PROJECT=$(oc project -q)
echo "対象プロジェクト: $CURRENT_PROJECT"
echo ""

echo "警告: 以下のリソースが削除されます:"
echo "  - PostgreSQL Deployment"
echo "  - PostgreSQL Service"
echo "  - PostgreSQL PVC (永続データも削除されます)"
echo "  - データベースSecret"
echo "  - 初期化Job"
echo "  - ConfigMap"
echo ""

read -p "本当に削除しますか？ (yes/No): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "中止しました"
    exit 1
fi

echo ""
echo "1. 初期化Jobを削除中..."
oc delete job/db-init --ignore-not-found=true

echo ""
echo "2. ConfigMapを削除中..."
oc delete configmap/db-init-scripts --ignore-not-found=true

echo ""
echo "3. PostgreSQL Deploymentを削除中..."
oc delete -f "$SCRIPT_DIR/postgresql-deployment.yaml" --ignore-not-found=true

echo ""
echo "4. PostgreSQL Serviceを削除中..."
oc delete -f "$SCRIPT_DIR/postgresql-service.yaml" --ignore-not-found=true

echo ""
echo "5. PVCを削除中（データも削除されます）..."
oc delete -f "$SCRIPT_DIR/postgresql-pvc.yaml" --ignore-not-found=true

echo ""
echo "6. Secretを削除中..."
oc delete -f "$SCRIPT_DIR/secret-database.yaml" --ignore-not-found=true

echo ""
echo "=========================================="
echo "  クリーンアップ完了"
echo "=========================================="
echo ""
