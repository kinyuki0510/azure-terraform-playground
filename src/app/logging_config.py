import logging
import logging.handlers
import os

import structlog


def configure_logging(log_file: str = "logs/app.log", level: int = logging.INFO) -> None:
    os.makedirs(os.path.dirname(log_file), exist_ok=True)

    # structlog のログを stdlib logging に渡す際の変換ルール。
    # structlog 経由のログと、uvicorn・SQLAlchemy 等のサードパーティログの
    # 両方を同じ JSON 形式に統一するために使う。
    formatter = structlog.stdlib.ProcessorFormatter(
        # foreign_pre_chain: uvicorn 等、structlog を使っていないライブラリの
        # ログに対して適用する前処理。level・logger 名・タイムスタンプを付与する。
        foreign_pre_chain=[
            structlog.stdlib.add_log_level,
            structlog.stdlib.add_logger_name,
            structlog.processors.TimeStamper(fmt="iso", utc=True),
        ],
        # processors: 最終出力への変換。
        # remove_processors_meta は structlog の内部メタデータを除去し、
        # JSONRenderer がログ辞書を JSON 文字列に変換する。
        processors=[
            structlog.stdlib.ProcessorFormatter.remove_processors_meta,
            structlog.processors.JSONRenderer(),
        ],
    )

    # RotatingFileHandler: 100KB ごとにファイルをローテートし、最大 5 世代保持する。
    # formatter をセットすることで、出力が JSON 形式になる。
    file_handler = logging.handlers.RotatingFileHandler(
        log_file, maxBytes=100 * 1024, backupCount=5, encoding="utf-8"
    )
    file_handler.setFormatter(formatter)

    # ルートロガーにハンドラを登録する。
    # ルートロガーへの登録により、uvicorn・SQLAlchemy 等すべてのログが
    # 同じファイルに集約される。
    root = logging.getLogger()
    root.addHandler(file_handler)
    root.setLevel(level)

    # structlog のグローバル設定。
    # logger.info(...) を呼んだ際に上から順に適用されるプロセッサチェーンを定義する。
    structlog.configure(
        processors=[
            # ミドルウェアで bind_contextvars した値（request_id 等）を
            # 各ログに自動でマージする。
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.add_log_level,
            structlog.stdlib.add_logger_name,
            structlog.processors.TimeStamper(fmt="iso", utc=True),
            # 上記で組み立てたログ辞書を stdlib logging 経由で
            # ProcessorFormatter に渡せる形に変換する。
            structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
        ],
        # stdlib logging と統合するための設定。
        # LoggerFactory により getLogger(__name__) と同じ名前空間で動作する。
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        # 初回呼び出し後にロガーをキャッシュしてパフォーマンスを最適化する。
        cache_logger_on_first_use=True,
    )
