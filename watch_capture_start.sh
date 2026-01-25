#!/bin/bash

# UTF-8ロケール設定
export LANG=ja_JP.UTF-8
export LC_ALL=ja_JP.UTF-8

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Watch Capture Start
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 👁️
# @raycast.packageName Obsidian Tools

# Documentation:
# @raycast.description 画面変化を監視して自動キャプチャ開始
# @raycast.author naoaki

# pyenvのPythonを使用（フルパス）
PYTHON_PATH="/Users/naoaki/.pyenv/versions/3.12.1/bin/python3"
# シンボリックリンクを解決してSCRIPT_DIRを取得
SCRIPT_PATH="$0"
if [[ -L "$SCRIPT_PATH" ]]; then
    SCRIPT_PATH="$(dirname "$0")/$(readlink "$0")"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REGION_FILE="$HOME/.capture_region"
PID_FILE="$HOME/.watch_capture.pid"
LOG_FILE="$HOME/.watch_capture.log"

# 既に実行中かチェック
if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        osascript -e 'display notification "既に監視中です" with title "Watch Capture"'
        exit 1
    fi
fi

# 範囲が設定されているかチェック
if [[ ! -f "$REGION_FILE" ]]; then
    osascript -e 'display notification "先にキャプチャ範囲を設定してください" with title "Watch Capture"'
    exit 1
fi

# バックグラウンドで監視を開始（ログ出力あり）
nohup "$PYTHON_PATH" "$SCRIPT_DIR/watch_and_capture.py" --interval 1.0 --threshold 3.0 >> "$LOG_FILE" 2>&1 &

osascript -e 'display notification "監視を開始しました" with title "Watch Capture"'
echo "監視を開始しました (ログ: $LOG_FILE)"
