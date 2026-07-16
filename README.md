# Coolstore EAP Application

JBoss EAP 7.4で動作するCoolstoreアプリケーション

## ローカル開発環境

### 前提条件

- JBoss EAP 7.4
- Podman または Docker
- Maven 3.x
- Java 8+

### セットアップ

1. 環境変数ファイルをコピー
```bash
cp .env.example .env
```

2. 必要に応じて`.env`ファイルを編集
```bash
# データベース接続情報
DB_HOST=localhost
DB_PORT=5432
DB_NAME=postgres
DB_USERNAME=postgres
DB_PASSWORD=postgres
```

3. アプリケーションを起動
```bash
./scripts/start-all.sh
```

4. アプリケーションにアクセス
- アプリケーション: http://localhost:8080/
- 管理コンソール: http://localhost:9990/

5. 停止
```bash
./scripts/stop-all.sh
```

## OpenShift デプロイ

### PostgreSQLデータベースの構築

**クイックスタート（推奨）**:

```bash
cd openshift/postgresql
./deploy.sh
```

**詳細な手順**: [openshift/postgresql/README.md](openshift/postgresql/README.md)

### EAP Operatorを使用したアプリケーションデプロイ

1. OpenShiftにログイン
```bash
oc login <your-openshift-cluster>
```

2. プロジェクトを作成
```bash
oc new-project coolstore-dev
```

3. PostgreSQLをデプロイ（上記クイックスタート参照）

4. EAP アプリケーションをデプロイ
```bash
oc apply -f openshift/base/wildflyserver-eap74.yaml
```

### 環境変数の設定

OpenShift上では、以下の環境変数が自動的に設定されます：

- `DB_HOST`: PostgreSQLサービス名
- `DB_PORT`: PostgreSQLポート（デフォルト: 5432）
- `DB_NAME`: データベース名
- `DB_USERNAME`: データベースユーザー名（Secretから）
- `DB_PASSWORD`: データベースパスワード（Secretから）

## ディレクトリ構造

```
.
├── .env.example          # 環境変数のサンプル
├── .env                  # ローカル開発用環境変数（git管理外）
├── .s2i/                 # OpenShift S2I設定
│   └── environment       # S2I環境変数
├── openshift/            # OpenShift/Kubernetesマニフェスト
│   ├── secret-database.yaml
│   └── configmap-database.yaml
├── scripts/              # デプロイメントスクリプト
│   ├── start-all.sh      # ローカル起動スクリプト
│   └── stop-all.sh       # 停止スクリプト
├── src/                  # ソースコード
├── standalone-full.xml   # JBoss EAP設定（環境変数対応）
└── pom.xml               # Maven設定
```

## 設定ファイル

### standalone-full.xml

データベース接続は環境変数を使用：

```xml
<datasource jndi-name="java:jboss/datasources/CoolstoreDS" ...>
    <connection-url>
        jdbc:postgresql://${env.DB_HOST:localhost}:${env.DB_PORT:5432}/${env.DB_NAME:postgres}
    </connection-url>
    <security>
        <user-name>${env.DB_USERNAME:postgres}</user-name>
        <password>${env.DB_PASSWORD:postgres}</password>
    </security>
</datasource>
```

デフォルト値が設定されているため、環境変数が設定されていない場合でも動作します。

## CI/CDパイプライン

将来的には、以下のようなパイプラインを構築予定：

1. GitにPush
2. OpenShift Pipelineが自動的にトリガー
3. S2Iビルド（Source-to-Image）
4. イメージをビルドしてレジストリにプッシュ
5. EAP Operatorが新しいイメージをデプロイ
6. ローリングアップデート

## トラブルシューティング

### ローカル環境

- ログ確認: `tail -f /tmp/eap-startup.log`
- PostgreSQL確認: `podman ps | grep postgres`
- EAPプロセス確認: `ps aux | grep jboss-eap`

### OpenShift環境

- Pod確認: `oc get pods`
- ログ確認: `oc logs -f <pod-name>`
- 環境変数確認: `oc set env deployment/coolstore --list`
