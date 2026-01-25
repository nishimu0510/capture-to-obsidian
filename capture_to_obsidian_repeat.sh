#!/bin/bash

# UTF-8ロケール設定（日本語OCR用）
export LANG=ja_JP.UTF-8
export LC_ALL=ja_JP.UTF-8

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Capture to Obsidian (Repeat)
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🔄
# @raycast.packageName Obsidian Tools

# Documentation:
# @raycast.description 前回と同じ範囲でキャプチャしてObsidianに保存
# @raycast.author naoaki

# 設定
VAULT_PATH="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Med"
ATTACHMENTS_DIR="$VAULT_PATH/attachments"
OCR_DIR="$VAULT_PATH/OCR_input"
NOTE_PATH="$VAULT_PATH/Screenshots.md"
OCR_NOTE_PATH="$VAULT_PATH/OCR_results.md"
SHORTCUT_NAME='text from image and remove\n and add <sup> 1'
REGION_FILE="$HOME/.capture_region"

# 前回の範囲があるかチェック
if [[ ! -f "$REGION_FILE" ]]; then
    osascript -e 'display notification "前回の範囲がありません" with title "Obsidian Capture"'
    exit 1
fi

REGION=$(cat "$REGION_FILE")

# タイムスタンプ生成
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
IMAGE_NAME="screenshot_${TIMESTAMP}.png"
IMAGE_PATH="$ATTACHMENTS_DIR/$IMAGE_NAME"

# フォルダが存在しない場合は作成
mkdir -p "$ATTACHMENTS_DIR"
mkdir -p "$OCR_DIR"

# 前回の範囲でキャプチャ
screencapture -R "$REGION" -x "$IMAGE_PATH"

# キャプチャが成功したかチェック
if [[ ! -f "$IMAGE_PATH" ]] || [[ ! -s "$IMAGE_PATH" ]]; then
    echo "キャプチャに失敗しました"
    exit 1
fi

# OCR用フォルダにもコピー
cp "$IMAGE_PATH" "$OCR_DIR/$IMAGE_NAME"

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
osascript -e 'display notification "キャプチャ完了（前回範囲）" with title "Obsidian Capture"'

echo "完了: $IMAGE_NAME"
