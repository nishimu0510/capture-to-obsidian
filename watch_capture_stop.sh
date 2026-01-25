#!/bin/bash

# UTF-8ロケール設定
export LANG=ja_JP.UTF-8
export LC_ALL=ja_JP.UTF-8

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Watch Capture Stop
# @raycast.mode silent

# Optional parameters:
# @raycast.icon ⏹️
# @raycast.packageName Obsidian Tools

# Documentation:
# @raycast.description 画面変化の監視を停止
# @raycast.author naoaki

PID_FILE="$HOME/.watch_capture.pid"

if [[ ! -f "$PID_FILE" ]]; then
    osascript -e 'display notification "監視は実行されていません" with title "Watch Capture"'
    exit 1
fi

PID=$(cat "$PID_FILE")

if ps -p "$PID" > /dev/null 2>&1; then
    kill "$PID"
    rm -f "$PID_FILE"
    osascript -e 'display notification "監視を停止しました" with title "Watch Capture"'
    echo "監視を停止しました (PID: $PID)"
else
    rm -f "$PID_FILE"
    osascript -e 'display notification "監視プロセスは既に終了しています" with title "Watch Capture"'
fi
