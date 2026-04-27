# Azure + Terraform + FastAPI 構築 引き継ぎドキュメント

## 目的

Azure学習の一環として、以下の構成をTerraformで構築し、FastAPIをコンテナデプロイする。

---

## 構成概要

```
Azure
└─ Resource Group
     ├─ Storage Account（アプリデータ用）
     │    └─ Blob Container（appdata）
     ├─ Storage Account（Functions専用）
     │    └─ Functionsのコード・ログ管理用
     ├─ PostgreSQL Flexible Server
     │    └─ Database（appdb）
     ├─ Container Apps Environment
     │    └─ Container App（FastAPI）
     │         ├─ 環境変数: DATABASE_URL（Secret経由）
     │         └─ 環境変数: BLOB_CONNECTION_STRING（Secret経由）
     └─ Azure Functions（Python）
          └─ GHCR経由でデプロイ
```

---

## 技術選定の背景

| 項目 | 選定 | 理由 |
|------|------|------|
| コンテナ実行環境 | Azure Container Apps | サーバーレス、シンプル、AIエージェント案件での採用増 |
| コンテナレジストリ | GHCR（GitHub Container Registry） | プライベートも無料、GitHub Actionsとネイティブ統合 |
| IaC | Terraform | インフラのコード管理 |
| DB | PostgreSQL Flexible Server | 12か月無料枠（B1ms） |
| ストレージ | Blob Storage | 12か月無料枠（5GB） |
| サーバーレス関数 | Azure Functions（Python） | Lambda相当、常時無料枠内 |

---

## コスト方針

- 目標：月$3未満
- PostgreSQL Flexible Server：`B_Standard_B1ms`（12か月無料枠）
- Container Apps：常時無料枠内（月180,000 vCPU秒）
- ACRは**使わない**（GHCRで代替してコスト$0）
- 学習終了後は必ず `terraform destroy` で全削除

---

## Terraformファイル構成

### ディレクトリ構成

```
terraform/
├─ main.tf              # モジュールを呼ぶだけ
├─ variables.tf         # 環境共通の変数定義
├─ outputs.tf           # 全体の出力値
├─ environments/
│    ├─ dev.tfvars          # dev環境パラメーター
│    ├─ stg.tfvars          # stg環境パラメーター
│    ├─ prod.tfvars         # prod環境パラメーター
│    ├─ dev.backend.hcl     # dev環境tfstate保存先
│    ├─ stg.backend.hcl     # stg環境tfstate保存先
│    └─ prod.backend.hcl    # prod環境tfstate保存先
└─ modules/
     ├─ storage/
     │    ├─ main.tf
     │    ├─ variables.tf
     │    └─ outputs.tf
     ├─ database/
     │    ├─ main.tf
     │    ├─ variables.tf
     │    └─ outputs.tf
     ├─ container_app/
     │    ├─ main.tf
     │    ├─ variables.tf
     │    └─ outputs.tf
     └─ functions/
          ├─ main.tf
          ├─ variables.tf
          └─ outputs.tf
```

### Terraform構成の方針

- **モジュール化**：同じコードをdev/stg/prodで使い回す
- **環境別Backend**：tfstateをStorage Account単位で完全分離
- **パラメーター注入**：環境差分はtfvarsで管理、コードは1セット

### 環境別Backendの操作

```bash
# dev環境
terraform init -backend-config="environments/dev.backend.hcl"
terraform apply -var-file="environments/dev.tfvars"

# prod環境
terraform init -backend-config="environments/prod.backend.hcl"
terraform apply -var-file="environments/prod.tfvars"
```

### backend.hclの構造

```hcl
# environments/dev.backend.hcl
resource_group_name  = "tfstate-dev-rg"
storage_account_name = "tfstatedev001"
container_name       = "tfstate"
key                  = "terraform.tfstate"

# environments/prod.backend.hcl
resource_group_name  = "tfstate-prod-rg"
storage_account_name = "tfstateprod001"
container_name       = "tfstate"
key                  = "terraform.tfstate"
```

### tfvarsの構造

```hcl
# environments/dev.tfvars
prefix         = "myapp-dev"
pg_sku         = "B_Standard_B1ms"
container_cpu  = 0.25
container_mem  = "0.5Gi"

# environments/prod.tfvars
prefix         = "myapp-prod"
pg_sku         = "GP_Standard_D2s_v3"
container_cpu  = 1.0
container_mem  = "2Gi"
```

### モジュール間の依存関係

```
storage
  └─ outputs: 接続文字列, account_name
       └─ container_app が参照

database
  └─ outputs: fqdn, db_name
       └─ container_app が参照

storage（functions専用）
  └─ outputs: 接続文字列
       └─ functions が参照
```

### 構築ステップ

```
Step1: tfstate用Storage AccountをPortalで手動作成（鶏と卵問題のため）
Step2: main.tf + variables.tf + backend設定
Step3: modules/storage
Step4: modules/database
Step5: modules/container_app
Step6: modules/functions
```

---

## GitHub Actions（CI/CD）

`.github/workflows/deploy.yml`

```yaml
name: Build & Deploy

on:
  push:
    branches: [main]

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build & Push
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:latest
```

> `GITHUB_TOKEN` はActions実行時に自動付与されるため追加設定不要。

---

## FastAPI最小実装

```python
import os
from fastapi import FastAPI

app = FastAPI()

DATABASE_URL = os.environ["DATABASE_URL"]
BLOB_CONNECTION_STRING = os.environ["BLOB_CONNECTION_STRING"]

@app.get("/health")
def health():
    return {"status": "ok"}
```

---

## Azureアカウント作成手順

### 1. Microsoftアカウント作成
すでに持っている場合はスキップ。

- https://account.microsoft.com にアクセス
- 「Microsoftアカウントを作成」からメールアドレスで登録

### 2. Azure無料アカウント登録

- https://azure.microsoft.com/ja-jp/free にアクセスし「無料で始める」
- クレジットカード登録（本人確認用。無料枠内では請求なし）
- 電話番号認証
- 登録完了で以下が付与される：
  - **$200クレジット**（30日間有効）
  - **12か月無料**サービス（VM、PostgreSQL、Blob等）
  - **常時無料**サービス（Container Apps、Functions等）

### 3. Azure CLI インストール

```bash
# macOS
brew install azure-cli

# Windows（PowerShell）
winget install Microsoft.AzureCLI
```

### 4. ログイン確認

```bash
az login         # ブラウザが開いてMicrosoftアカウントでログイン
az account show  # サブスクリプション情報が表示されればOK
```

### 5. 予算アラート設定（必須）

課金超過を防ぐために最初に設定する。

```
Azure Portal → 検索バーで「予算」→「コスト管理」
→「予算を追加」→ 月$3でアラート設定 → メール通知ON
```

---

## コスト内訳と注意点

| リソース | 無料枠 | 無料種別 | 無料切れ後 |
|---------|--------|---------|-----------|
| Container Apps | 月180,000 vCPU秒 | **常時無料** | 超過分のみ従量 |
| Blob Storage | 5GB | 12か月 | 約$0.02/GB |
| PostgreSQL B1ms | 750時間 | **12か月のみ** | 約$15〜20/月 ← 注意 |
| GHCR | 無制限（パブリック） | **常時無料** | - |

**最もコストリスクが高いのはPostgreSQL**。12か月無料枠が切れると月$15〜20発生する。
学習が終わったら必ず `terraform destroy` で削除すること。

---

## デプロイ手順

```bash
# 1. Azure CLIログイン
az login

# 2. 初期化
terraform init

# 3. 確認
terraform plan

# 4. デプロイ
terraform apply

# 5. 学習終了後は必ず削除
terraform destroy
```

---

## 学習用と本番の差分（将来の改善ポイント）

| 項目 | 今回（学習用） | 本番 |
|------|--------------|------|
| PostgreSQLアクセス | パブリック | VNet + Private Endpoint |
| シークレット管理 | tfvarsに直書き | Key Vault参照 |
| コンテナレジストリ | GHCR | ACR + マネージドID認証 |
| スケール設定 | 最小構成 | min/maxレプリカ設定 |
| 認証 | なし | Entra ID + マネージドID |

---

## Azure概念メモ（AWS経験者向け）

| AWS | Azure |
|-----|-------|
| アカウント | Subscription |
| Organizations | Management Group |
| なし | Resource Group（リソースの論理コンテナ） |
| IAM | Entra ID（旧AAD） |
| IAMロール | マネージドID |
| VPC | VNet |
| S3バケット | Storage Account ＞ Blobコンテナ |
| ECR | ACR / GHCR |
| ECS Fargate | Azure Container Apps |
| RDS | PostgreSQL Flexible Server |

### Storage Accountの命名規則
- グローバル一意、3〜24文字、小英数字のみ（ハイフン不可）
- DEV/STG/PROD分離はSubscriptionレベルで行うのがベストプラクティス
- コンテナ名はStorage Account内でのみ一意でよい

### グローバル一意が必要なリソース（はまりポイント）
以下はFQDNがAzure全体でユニークになるため、名前が衝突すると`ServerNameAlreadyExists`等のエラーになる。エラーが出るまで気づきにくいため、**サブスクリプションIDのサフィックス（`sa_suffix`）を付与して一意性を担保すること**。

| リソース | FQDN例 |
|---|---|
| Storage Account | `<name>.blob.core.windows.net` |
| PostgreSQL Flexible Server | `<name>.postgres.database.azure.com` |
| Key Vault | `<name>.vault.azure.net` |
| App Configuration | `<name>.azconfig.io` |

### セキュリティ注意点
- Azure PaaSサービス（Blob, PostgreSQL等）はデフォルトでVNet外パブリック
- 本番では必ずPrivate Endpointで閉じること
- VMは停止しても課金される → `terraform destroy`で削除すること

---

## Storage Accountのアクセス制御設計

### 2層構造

Storageへのアクセスはネットワーク層と認証層の2層で制御される。

```
クライアント
  ↓
【ネットワーク層】network_rules
  - ip_rules: 許可IPのみ通過
  - bypass = ["AzureServices"]: 信頼済みAzureサービスはIPルールをバイパス
  ↓
【認証層】RBAC
  - Managed IdentityにRoleが割り当てられているか検証
  - 未割り当てのIDは 403 Forbidden
```

ネットワーク層を通過しても認証層で弾かれるため、`bypass = ["AzureServices"]` は他アカウントのAzureサービスへの穴にはならない。

### 本プロジェクトの設定

| クライアント | ネットワーク | 認証 |
|---|---|---|
| 開発PC | `ip_rules` で自IPを許可 | アクセスキー |
| Container Apps | `bypass = ["AzureServices"]` | Managed Identity + Storage Blob Data Contributor |

### なぜアクセスキーではなくManaged Identityか

- アクセスキーはIPフィルタに関わらず有効なため、漏洩リスクが高い
- Container Appsのアウトバウンドは動的IP（Consumption-onlyでは固定不可）なためIP制限が使えない
- `bypass = ["AzureServices"]` はManaged Identity認証時のみ信頼済みサービスとして扱われる

