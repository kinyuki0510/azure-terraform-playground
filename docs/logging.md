# ロギング設計

## ライブラリ

| 用途 | ライブラリ |
|---|---|
| 構造化ログ | [structlog](https://www.structlog.org/) |
| ファイル出力・ローテート | Python 標準 `logging.handlers` |

structlog は Python 標準 `logging` と統合して使う。uvicorn・SQLAlchemy 等のサードパーティログも同じパイプラインで処理される。

## 出力形式

JSON 形式で出力する。

```json
{
  "timestamp": "2026-04-28T12:00:00.123456Z",
  "level": "info",
  "logger": "app.routers.user_router",
  "request_id": "a1b2c3d4-...",
  "event": "request",
  "method": "POST",
  "path": "/api/auth/login",
  "status_code": 200,
  "duration_ms": 45.2
}
```

## ログレベル

| レベル | 使う場面 |
|---|---|
| `debug` | 開発時の詳細情報（DB クエリ、変数値）|
| `info` | 正常系の操作（リクエスト完了、ユーザー作成）|
| `warning` | 問題ではないが注意が必要な状態（リトライ発生等）|
| `error` | 処理が失敗した（例外キャッチ、外部 API エラー）|
| `critical` | アプリ継続不能（DB 接続不能、設定ミス）|

本番環境では `info` 以上を出力する。

## ファイルローテート

| 設定 | 値 |
|---|---|
| 出力先 | `logs/app.log` |
| ローテート | 100 KB ごと |
| 保持世代数 | 5 ファイル |
| 最大合計 | 約 500 KB |

## リクエストコンテキスト

ミドルウェアでリクエストごとに `request_id`（UUID4）を生成し、`structlog.contextvars` にバインドする。同一リクエスト内のすべてのログに自動付与されるため、ログ検索時にリクエスト単位でトレースできる。

```python
# ミドルウェアでセット
structlog.contextvars.bind_contextvars(request_id=str(uuid.uuid4()))

# サービス層でも自動付与される
logger.info("user created", user_id=user.id)
# → {"request_id": "a1b2...", "event": "user created", "user_id": 42}
```

## コードでの使い方

```python
import structlog

logger = structlog.get_logger(__name__)

# キーワード引数で構造化
logger.info("user registered", email=email)
logger.error("db connection failed", error=str(e))
```

## 設定ファイル

`src/app/logging_config.py` で structlog と stdlib logging を初期化する。`main.py` の lifespan で呼び出す。
