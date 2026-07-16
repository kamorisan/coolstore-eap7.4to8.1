# PostgreSQL クイックスタート

## 最速デプロイ（1コマンド）

```bash
cd openshift/postgresql
./deploy.sh
```

これだけで以下が完了します：
- PostgreSQL 13のデプロイ（永続化）
- 初期データの投入（9商品）

## 確認

```bash
# データ確認
oc exec $(oc get pods -l component=database -o name) \
  -- psql -U coolstore -d coolstore -c "SELECT * FROM PRODUCT_CATALOG;"
```

## クリーンアップ

```bash
./cleanup.sh
```

## 詳細

詳しい手順やトラブルシューティングは [README.md](README.md) を参照してください。
