#!/bin/bash

# UTF-8ロケール設定（日本語OCR用）
export LANG=ja_JP.UTF-8
export LC_ALL=ja_JP.UTF-8

# pyenvのPythonを使用（Quartz対応）
PYTHON_PATH="$HOME/.pyenv/versions/3.12.1/bin/python3"

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Capture to Obsidian (New)
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📸
# @raycast.packageName Obsidian Tools

# Documentation:
# @raycast.description 新しい範囲を選択してキャプチャしてObsidianに保存
# @raycast.author naoaki

# 設定
VAULT_PATH="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Med"
ATTACHMENTS_DIR="$VAULT_PATH/attachments"
# OCR_DIR="$VAULT_PATH/OCR_input"  # 不要になったため無効化
NOTE_PATH="$VAULT_PATH/Screenshots.md"
OCR_NOTE_PATH="$VAULT_PATH/OCR_results.md"
SHORTCUT_NAME='text from image and remove\n and add <sup> 1'
REGION_FILE="$HOME/.capture_region"
# シンボリックリンクを解決してSCRIPT_DIRを取得
SCRIPT_PATH="$0"
if [[ -L "$SCRIPT_PATH" ]]; then
    SCRIPT_PATH="$(dirname "$0")/$(readlink "$0")"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# タイムスタンプ生成
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
IMAGE_NAME="screenshot_${TIMESTAMP}.png"
IMAGE_PATH="$ATTACHMENTS_DIR/$IMAGE_NAME"

# フォルダが存在しない場合は作成
mkdir -p "$ATTACHMENTS_DIR"

# Pythonで座標を記録しながらキャプチャ
"$PYTHON_PATH" "$SCRIPT_DIR/capture_with_region.py" "$IMAGE_PATH" "$REGION_FILE"

# キャプチャがキャンセルされたかチェック
if [[ ! -f "$IMAGE_PATH" ]] || [[ ! -s "$IMAGE_PATH" ]]; then
    echo "キャプチャがキャンセルされました"
    exit 1
fi

# 画像をクリップボードにコピー
osascript -e "set the clipboard to (read (POSIX file \"$IMAGE_PATH\") as «class PNGf»)"

# ショートカットを実行
shortcuts run "$SHORTCUT_NAME" 2>/dev/null

# 少し待機
sleep 0.5

# クリップボードからOCR結果を取得
OCR_TEXT=$(pbpaste 2>/dev/null)

# Screenshots.md に画像だけ追記
if [[ ! -f "$NOTE_PATH" ]]; then
    echo "# Screenshots" > "$NOTE_PATH"
fi
echo "![[attachments/$IMAGE_NAME]]" >> "$NOTE_PATH"

# OCR_results.md にOCR結果を追記
if [[ -n "$OCR_TEXT" ]]; then
    if [[ ! -f "$OCR_NOTE_PATH" ]]; then
        echo "# OCR Results" > "$OCR_NOTE_PATH"
    fi
    echo "$OCR_TEXT" >> "$OCR_NOTE_PATH"
fi

# 完了通知
osascript -e 'display notification "キャプチャ完了" with title "Obsidian Capture"'

echo "完了: $IMAGE_NAME"
