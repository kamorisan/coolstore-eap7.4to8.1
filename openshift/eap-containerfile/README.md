# EAP アプリケーション Containerfile デプロイ手順

## 概要

Containerfile + podman を使用してEAPアプリケーションをコンテナイメージ化し、OpenShiftにデプロイします。

**S2I方式との違い:**
- ✅ ローカル環境の設定（standalone-full.xml）をそのまま使用可能
- ✅ 設定変更が最小限
- ✅ ローカルでビルド＆テスト可能
- ⚠️ ビルドマシンにpodmanとMavenが必要

## 前提条件

### ローカル環境
- Maven 3.x
- podman
- Red Hat Container Registryへのアクセス権限

### OpenShift環境
- PostgreSQLがデプロイ済み
- Secret `coolstore-db-secret` が作成済み

PostgreSQLのデプロイ方法は [../postgresql/README.md](../postgresql/README.md) を参照。

## デプロイ手順

### 1. イメージビルド

```bash
# リポジトリルートで実行
cd /path/to/coolstore-eap7.4to8.1

# ビルドスクリプト実行
./build-image.sh
```

このスクリプトは以下を実行します:
1. `mvn clean package` - WARファイルのビルド
2. `podman build` - コンテナイメージの作成

ビルド成功後、`coolstore-eap74:latest` イメージが作成されます。

### 2. ローカルテスト（オプション）

```bash
# .env ファイルが必要
./run-local-container.sh
```

ブラウザで確認:
- アプリケーション: http://localhost:8080
- 管理コンソール: http://localhost:9990

終了: `Ctrl+C`

### 3. OpenShiftへイメージプッシュ

```bash
# admin-dev namespaceへプッシュ
./push-to-openshift.sh admin-dev

# 別のnamespaceへプッシュする場合
./push-to-openshift.sh user01-dev
```

このスクリプトは以下を実行します:
1. OpenShiftログイン確認
2. Namespace確認
3. Internal Registry URLの取得
4. イメージのタグ付け
5. プッシュ

### 4. アプリケーションデプロイ

```bash
# OpenShiftにログイン
oc login ...

# Namespace切り替え
oc project admin-dev

# リソースをデプロイ
oc apply -f openshift/eap-containerfile/deployment.yaml
oc apply -f openshift/eap-containerfile/service.yaml
oc apply -f openshift/eap-containerfile/route.yaml
```

### 5. デプロイ確認

```bash
# Pod状態確認
oc get pods -l component=application

# ログ確認
oc logs -f deployment/coolstore-eap74

# Route URL取得
oc get route coolstore-eap74 -o jsonpath='{.spec.host}'
```

## ファイル構成

```
coolstore-eap7.4to8.1/
├── Containerfile              # コンテナイメージ定義
├── build-image.sh             # ビルドスクリプト
├── run-local-container.sh     # ローカルテストスクリプト
├── push-to-openshift.sh       # OpenShiftプッシュスクリプト
├── standalone-full.xml        # EAP設定（環境変数対応）
├── pom.xml                    # Mavenビルド設定
└── openshift/
    └── eap-containerfile/
        ├── README.md          # このファイル
        ├── deployment.yaml    # Deployment
        ├── service.yaml       # Service
        └── route.yaml         # Route
```

## Containerfile 解説

```dockerfile
FROM registry.redhat.io/jboss-eap-7/eap74-openjdk8-runtime-openshift-rhel8:latest

# EAP設定ファイルをコピー
COPY standalone-full.xml /opt/eap/standalone/configuration/

# WARファイルをコピー
COPY target/ROOT.war /opt/eap/standalone/deployments/

# ポート公開
EXPOSE 8080 8443 8778

# EAP起動
CMD ["/opt/eap/bin/standalone.sh", "-b", "0.0.0.0", "-c", "standalone-full.xml"]
```

## 環境変数

Deployment で以下の環境変数がSecretから注入されます:

| 環境変数 | 説明 | 参照先 |
|---------|------|--------|
| DB_HOST | PostgreSQLホスト名 | coolstore-db-secret |
| DB_PORT | PostgreSQLポート | coolstore-db-secret |
| DB_NAME | データベース名 | coolstore-db-secret |
| DB_USERNAME | データベースユーザー | coolstore-db-secret |
| DB_PASSWORD | データベースパスワード | coolstore-db-secret |

これらは `standalone-full.xml` で以下のように参照されます:

```xml
<connection-url>
    jdbc:postgresql://${env.DB_HOST:localhost}:${env.DB_PORT:5432}/${env.DB_NAME:postgres}
</connection-url>
<user-name>${env.DB_USERNAME:postgres}</user-name>
<password>${env.DB_PASSWORD:postgres}</password>
```

## トラブルシューティング

### イメージビルド失敗

```bash
# Mavenビルド確認
mvn clean package

# WAR確認
ls -lh target/ROOT.war

# Containerfile構文確認
podman build --no-cache -t coolstore-eap74:latest -f Containerfile .
```

### Podが起動しない

```bash
# Pod詳細確認
oc describe pod -l component=application

# ログ確認
oc logs -f deployment/coolstore-eap74

# 環境変数確認
oc set env deployment/coolstore-eap74 --list
```

### DB接続エラー

```bash
# Secret確認
oc get secret coolstore-db-secret -o yaml

# PostgreSQL接続テスト
oc exec $(oc get pods -l component=database -o name) -- psql -U coolstore -d coolstore -c "SELECT 1;"

# EAP Podから接続確認
oc exec deployment/coolstore-eap74 -- curl -v telnet://postgresql:5432
```

## イメージ更新手順

コード変更後、イメージを更新する場合:

```bash
# 1. イメージ再ビルド
./build-image.sh

# 2. OpenShiftへプッシュ
./push-to-openshift.sh admin-dev

# 3. Deployment再起動（最新イメージを使用）
oc rollout restart deployment/coolstore-eap74

# 4. ロールアウト状況確認
oc rollout status deployment/coolstore-eap74
```

## クリーンアップ

```bash
# OpenShiftリソース削除
oc delete -f openshift/eap-containerfile/

# ローカルイメージ削除
podman rmi coolstore-eap74:latest
```

## 横展開（複数環境への展開）

### 例: user01-dev namespace への展開

```bash
# 1. PostgreSQL構築（先にこちらを完了）
oc project user01-dev
cd ../postgresql
./deploy.sh

# 2. イメージプッシュ
cd ../../
./push-to-openshift.sh user01-dev

# 3. Deployment適用（namespace指定）
oc project user01-dev
oc apply -f openshift/eap-containerfile/deployment.yaml
oc apply -f openshift/eap-containerfile/service.yaml
oc apply -f openshift/eap-containerfile/route.yaml
```

**注意:** deployment.yamlのimage参照を該当namespaceに変更する必要があります。

## 参考情報

- [Red Hat JBoss EAP Container Images](https://catalog.redhat.com/software/containers/jboss-eap-7/eap74-openjdk8-runtime-openshift-rhel8/)
- [Podman Documentation](https://docs.podman.io/)
