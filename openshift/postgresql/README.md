# PostgreSQL データベース構築手順

このディレクトリには、OpenShift上にPostgreSQLデータベースを構築し、初期データを投入するためのマニフェストファイルが含まれています。

## 概要

- **PostgreSQLバージョン**: 13
- **イメージ**: `registry.redhat.io/rhel8/postgresql-13:latest`
- **永続化**: PersistentVolumeClaim (5Gi)
- **初期データ**: Kubernetes Jobで自動投入

## ファイル構成

```
postgresql/
├── README.md                     # このファイル
├── secret-database.yaml          # データベース認証情報
├── postgresql-pvc.yaml           # 永続ボリューム要求
├── postgresql-deployment.yaml    # PostgreSQL Deployment
├── postgresql-service.yaml       # PostgreSQL Service
├── db-init-configmap.yaml        # 初期データSQLスクリプト
└── db-init-job.yaml              # 初期データ投入Job
```

## デプロイ手順

### 前提条件

- OpenShift 4.x クラスタへのアクセス
- `oc` CLIツール
- プロジェクト（namespace）が作成済み

### 手順

#### 1. プロジェクトの作成または切り替え

```bash
# 新規作成の場合
oc new-project <project-name>

# 既存プロジェクトを使用する場合
oc project <project-name>
```

例：
```bash
oc project admin-dev
```

#### 2. データベース認証情報の作成

**重要**: `secret-database.yaml` の認証情報を環境に合わせて編集してください。

```bash
# ファイルを編集（必要に応じて）
vi secret-database.yaml

# Secretを作成
oc apply -f secret-database.yaml
```

**デフォルト値**:
- ユーザー名: `coolstore`
- パスワード: `coolstore123`
- データベース名: `coolstore`

#### 3. PostgreSQLの永続ボリュームを作成

```bash
oc apply -f postgresql-pvc.yaml
```

#### 4. PostgreSQL Deploymentをデプロイ

```bash
oc apply -f postgresql-deployment.yaml
```

#### 5. PostgreSQL Serviceを作成

```bash
oc apply -f postgresql-service.yaml
```

#### 6. PostgreSQLの起動確認

```bash
# Podの状態確認
oc get pods -l component=database

# 出力例:
# NAME                          READY   STATUS    RESTARTS   AGE
# postgresql-7fb48687b6-ps9bk   1/1     Running   0          2m
```

#### 7. 初期データの投入

##### 7.1 ConfigMapの作成

```bash
oc apply -f db-init-configmap.yaml
```

##### 7.2 初期化Jobの実行

```bash
oc apply -f db-init-job.yaml
```

##### 7.3 Job完了の確認

```bash
# Job状態確認
oc get jobs

# 出力例:
# NAME      STATUS     COMPLETIONS   DURATION   AGE
# db-init   Complete   1/1           13s        21s

# Jobログ確認
oc logs job/db-init
```

#### 8. データ投入の検証

```bash
# PostgreSQL Podに接続してデータ確認
oc exec $(oc get pods -l component=database -o jsonpath='{.items[0].metadata.name}') \
  -- psql -U coolstore -d coolstore -c "SELECT * FROM PRODUCT_CATALOG;"

# 商品数の確認
oc exec $(oc get pods -l component=database -o jsonpath='{.items[0].metadata.name}') \
  -- psql -U coolstore -d coolstore -c "SELECT COUNT(*) FROM PRODUCT_CATALOG;"
```

**期待される結果**: 9商品

## 一括デプロイ

全てのリソースを一括でデプロイする場合:

```bash
# PostgreSQL関連リソースを順番にデプロイ
oc apply -f secret-database.yaml
oc apply -f postgresql-pvc.yaml
oc apply -f postgresql-deployment.yaml
oc apply -f postgresql-service.yaml

# PostgreSQLの起動を待機（30秒程度）
sleep 30

# 初期データ投入
oc apply -f db-init-configmap.yaml
oc apply -f db-init-job.yaml
```

または、ディレクトリ全体を適用（推奨順序で実行）:

```bash
# 1. Secret, PVC, Service, Deploymentを作成
oc apply -f secret-database.yaml \
          -f postgresql-pvc.yaml \
          -f postgresql-service.yaml \
          -f postgresql-deployment.yaml

# 2. PostgreSQL起動待機
oc wait --for=condition=ready pod -l component=database --timeout=120s

# 3. 初期データ投入
oc apply -f db-init-configmap.yaml \
          -f db-init-job.yaml

# 4. Job完了待機
oc wait --for=condition=complete job/db-init --timeout=60s
```

## 初期データについて

### 投入されるテーブル

1. **INVENTORY** - 在庫情報（9レコード）
2. **PRODUCT_CATALOG** - 商品カタログ（9レコード）
3. **ORDERS** - 注文情報（初期は空）
4. **ORDER_ITEMS** - 注文明細（初期は空）

### 初期データの内容

**商品例**:
- Quarkus T-shirt ($10.00)
- Red Hat Impact T-shirt ($9.00)
- Quarkus H2Go water bottle ($14.45)
- その他6商品

### 冪等性

`db-init-job.yaml` は冪等性を持ちます：
- 既にテーブルが存在する場合、初期化をスキップ
- 誤って複数回実行してもデータが重複しない

再度初期化が必要な場合:

```bash
# 既存のJobを削除
oc delete job/db-init

# テーブルを削除（注意: 全データが消えます）
oc exec $(oc get pods -l component=database -o jsonpath='{.items[0].metadata.name}') \
  -- psql -U coolstore -d coolstore -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

# Jobを再実行
oc apply -f db-init-job.yaml
```

## トラブルシューティング

### PostgreSQL Podが起動しない

```bash
# Pod状態確認
oc get pods -l component=database

# ログ確認
oc logs $(oc get pods -l component=database -o name)

# イベント確認
oc describe pod $(oc get pods -l component=database -o name)
```

よくある原因:
- PVCがBind状態になっていない → ストレージクラスを確認
- イメージプル失敗 → Red Hatレジストリの認証確認

### 初期化Jobが失敗する

```bash
# Jobログ確認
oc logs job/db-init

# Job詳細確認
oc describe job/db-init
```

よくある原因:
- PostgreSQLが起動していない → PostgreSQL Podを確認
- Secret情報が間違っている → `secret-database.yaml` を確認

### データベース接続確認

```bash
# PostgreSQL Podに直接接続
oc exec -it $(oc get pods -l component=database -o name) -- bash

# psqlで接続
psql -U coolstore -d coolstore

# テーブル一覧表示
\dt

# 終了
\q
exit
```

## 環境変数

PostgreSQL Deploymentで使用される環境変数:

| 環境変数 | 説明 | デフォルト値 |
|---------|------|-------------|
| `POSTGRESQL_USER` | データベースユーザー名 | coolstore |
| `POSTGRESQL_PASSWORD` | データベースパスワード | coolstore123 |
| `POSTGRESQL_DATABASE` | データベース名 | coolstore |

これらは全て `secret-database.yaml` で管理されています。

## クリーンアップ

全てのPostgreSQLリソースを削除する場合:

```bash
# Jobを削除
oc delete job/db-init

# ConfigMapを削除
oc delete configmap/db-init-scripts

# PostgreSQLリソースを削除
oc delete -f postgresql-deployment.yaml
oc delete -f postgresql-service.yaml
oc delete -f postgresql-pvc.yaml
oc delete -f secret-database.yaml
```

**注意**: PVCを削除すると、永続化されたデータも削除されます。

## 横展開（複数環境への展開）

このPostgreSQLセットアップは、異なるnamespaceに展開できるように設計されています。

### 例: user01-dev namespace への展開

```bash
# namespace作成
oc new-project user01-dev

# PostgreSQL構築（上記手順と同じ）
oc apply -f secret-database.yaml
oc apply -f postgresql-pvc.yaml
oc apply -f postgresql-service.yaml
oc apply -f postgresql-deployment.yaml

# 起動待機
oc wait --for=condition=ready pod -l component=database --timeout=120s

# 初期データ投入
oc apply -f db-init-configmap.yaml
oc apply -f db-init-job.yaml
```

各namespaceは完全に独立したPostgreSQLインスタンスを持ちます。

## セキュリティに関する注意

### 本番環境での考慮事項

1. **パスワードの変更**
   - デフォルトパスワード `coolstore123` を強力なパスワードに変更
   - OpenShift Secretを暗号化

2. **リソース制限**
   - CPU/Memoryリミットを設定（本番環境に応じて調整）

3. **バックアップ**
   - 定期的なバックアップ戦略を実装
   - PVCのスナップショット機能を活用

4. **ネットワークポリシー**
   - NetworkPolicyでPostgreSQLへのアクセスを制限
   - EAPアプリケーションからのみアクセス許可

## 参考情報

- [PostgreSQL公式ドキュメント](https://www.postgresql.org/docs/13/)
- [Red Hat Container Catalog - PostgreSQL](https://catalog.redhat.com/software/containers/rhel8/postgresql-13/5ffdbdef73a65398111b8362)
- [OpenShift PersistentVolume Documentation](https://docs.openshift.com/container-platform/latest/storage/understanding-persistent-storage.html)
