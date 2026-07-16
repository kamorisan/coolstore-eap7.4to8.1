#!/bin/bash

set -e

# デフォルト値
NAMESPACE=${1:-admin-dev}
IMAGE_NAME="coolstore-eap74"

echo "=========================================="
echo "  OpenShift Internal Registryへプッシュ"
echo "=========================================="
echo ""
echo "対象Namespace: $NAMESPACE"
echo "イメージ名: $IMAGE_NAME"
echo ""

# OpenShiftログイン確認
echo "1. OpenShiftログイン状態確認..."
if ! oc whoami &> /dev/null; then
    echo "エラー: OpenShiftにログインしていません"
    echo "  実行: oc login ..."
    exit 1
fi
echo "   ✓ ログイン済み: $(oc whoami)"

# Namespace確認
echo ""
echo "2. Namespace確認..."
if ! oc get project $NAMESPACE &> /dev/null; then
    echo "エラー: Namespace '$NAMESPACE' が見つかりません"
    exit 1
fi
echo "   ✓ Namespace存在確認"

# Internal Registry URLを取得
echo ""
echo "3. Internal Registry URL取得..."
REGISTRY=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [ -z "$REGISTRY" ]; then
    # Routeがない場合はServiceを使用
    REGISTRY="image-registry.openshift-image-registry.svc:5000"
    echo "   ℹ Internal Registry: $REGISTRY (Service)"
else
    echo "   ✓ Internal Registry: $REGISTRY (Route)"
fi

TARGET_IMAGE="$REGISTRY/$NAMESPACE/$IMAGE_NAME:latest"
echo "   Target: $TARGET_IMAGE"

# podmanログイン（Routeがある場合）
if [[ $REGISTRY != *"svc:5000"* ]]; then
    echo ""
    echo "4. Registry認証..."
    TOKEN=$(oc whoami -t)
    echo $TOKEN | podman login -u $(oc whoami) --password-stdin $REGISTRY
fi

# タグ付け
echo ""
echo "5. イメージにタグ付け..."
podman tag localhost/$IMAGE_NAME:latest $TARGET_IMAGE

# プッシュ
echo ""
echo "6. イメージをプッシュ中..."
if [[ $REGISTRY == *"svc:5000"* ]]; then
    # Internal Service経由の場合はoc image mirror使用
    echo "   ℹ oc コマンドでpush..."
    podman save $IMAGE_NAME:latest | oc image append --from-file=- --to=$TARGET_IMAGE
else
    # External Route経由
    podman push $TARGET_IMAGE
fi

echo ""
echo "=========================================="
echo "  プッシュ完了！"
echo "=========================================="
echo ""
echo "イメージ: $TARGET_IMAGE"
echo ""
echo "次のステップ:"
echo "  Deployment作成:"
echo "    oc apply -f openshift/eap-containerfile/"
echo ""
