#!/usr/bin/env python3
"""
画面の指定範囲を監視し、変化があったら自動キャプチャするスクリプト
Usage: watch_and_capture.py [--interval 1.0] [--threshold 5.0]
"""
import subprocess
import sys
import os
import time
import signal
import argparse
from datetime import datetime
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageStat
except ImportError:
    print("PILが必要です: pip install Pillow")
    sys.exit(1)

# 設定
VAULT_PATH = os.path.expanduser("~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Med")
ATTACHMENTS_DIR = os.path.join(VAULT_PATH, "attachments")
NOTE_PATH = os.path.join(VAULT_PATH, "Screenshots.md")
OCR_NOTE_PATH = os.path.join(VAULT_PATH, "OCR_results.md")
SHORTCUT_NAME = "text from image and remove\\n and add <sup> 1"
REGION_FILE = os.path.expanduser("~/.capture_region")
PID_FILE = os.path.expanduser("~/.watch_capture.pid")

running = True

def signal_handler(sig, frame):
    global running
    print("\n監視を停止します...")
    running = False

def get_region():
    """保存された範囲を読み込む"""
    if not os.path.exists(REGION_FILE):
        return None
    with open(REGION_FILE, 'r') as f:
        return f.read().strip()

def capture_region(region, output_path):
    """指定範囲をキャプチャ"""
    subprocess.run(['screencapture', '-R', region, '-x', output_path],
                   capture_output=True)
    return os.path.exists(output_path) and os.path.getsize(output_path) > 0

def compare_images(img1_path, img2_path, threshold):
    """2つの画像を比較し、変化率を返す"""
    try:
        img1 = Image.open(img1_path).convert('RGB')
        img2 = Image.open(img2_path).convert('RGB')

        # サイズが違う場合は変化ありと判定
        if img1.size != img2.size:
            return 100.0

        # 差分画像を計算
        diff = ImageChops.difference(img1, img2)
        stat = ImageStat.Stat(diff)

        # RGBチャンネルの平均差分を計算（0-255のスケール）
        diff_ratio = sum(stat.mean) / 3 / 255 * 100

        return diff_ratio
    except Exception as e:
        print(f"画像比較エラー: {e}")
        return 100.0

def run_ocr(image_path):
    """OCRを実行してテキストを取得"""
    # 画像をクリップボードにコピー
    subprocess.run([
        'osascript', '-e',
        f'set the clipboard to (read (POSIX file "{image_path}") as «class PNGf»)'
    ], capture_output=True)

    # ショートカットを実行
    subprocess.run(['shortcuts', 'run', SHORTCUT_NAME],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    time.sleep(0.5)

    # クリップボードからテキストを取得
    result = subprocess.run(['pbpaste'], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else ""

def save_to_obsidian(image_name, ocr_text):
    """Obsidianに保存"""
    # Screenshots.md に画像を追記
    if not os.path.exists(NOTE_PATH):
        with open(NOTE_PATH, 'w') as f:
            f.write("# Screenshots\n")
    with open(NOTE_PATH, 'a') as f:
        f.write(f"![[attachments/{image_name}]]\n")

    # OCR結果を追記
    if ocr_text:
        if not os.path.exists(OCR_NOTE_PATH):
            with open(OCR_NOTE_PATH, 'w') as f:
                f.write("# OCR Results\n")
        with open(OCR_NOTE_PATH, 'a') as f:
            f.write(f"{ocr_text}\n")

def notify(message):
    """macOS通知を表示"""
    subprocess.run([
        'osascript', '-e',
        f'display notification "{message}" with title "Watch Capture"'
    ], capture_output=True)

def main():
    global running

    parser = argparse.ArgumentParser(description='画面変化を監視して自動キャプチャ')
    parser.add_argument('--interval', type=float, default=1.0,
                        help='チェック間隔（秒）デフォルト: 1.0')
    parser.add_argument('--threshold', type=float, default=5.0,
                        help='変化検出の閾値（%%）デフォルト: 5.0')
    parser.add_argument('--no-ocr', action='store_true',
                        help='OCRを無効化')
    args = parser.parse_args()

    # シグナルハンドラを設定
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # 範囲を取得
    region = get_region()
    if not region:
        print("エラー: キャプチャ範囲が設定されていません")
        print("先に capture_to_obsidian.sh を実行して範囲を設定してください")
        sys.exit(1)

    # ディレクトリを作成
    os.makedirs(ATTACHMENTS_DIR, exist_ok=True)

    # PIDを保存
    with open(PID_FILE, 'w') as f:
        f.write(str(os.getpid()))

    print(f"監視開始: 範囲={region}, 間隔={args.interval}秒, 閾値={args.threshold}%", flush=True)
    notify(f"監視開始: 間隔{args.interval}秒, 閾値{args.threshold}%")

    # 一時ファイル用ディレクトリ
    import tempfile
    temp_dir = tempfile.mkdtemp()
    prev_image = os.path.join(temp_dir, "prev.png")
    curr_image = os.path.join(temp_dir, "curr.png")

    # 初回キャプチャ
    capture_region(region, prev_image)
    capture_count = 0

    try:
        while running:
            time.sleep(args.interval)

            if not running:
                break

            # 現在の画面をキャプチャ
            if not capture_region(region, curr_image):
                continue

            # 比較
            diff = compare_images(prev_image, curr_image, args.threshold)

            # デバッグ: 差分を表示（5回に1回）
            if int(time.time()) % 5 == 0:
                print(f"[DEBUG] 差分: {diff:.2f}%", flush=True)

            if diff >= args.threshold:
                capture_count += 1
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                image_name = f"watch_{timestamp}.png"
                final_path = os.path.join(ATTACHMENTS_DIR, image_name)

                # 画像を保存
                subprocess.run(['cp', curr_image, final_path])

                print(f"[{capture_count}] 変化検出 ({diff:.1f}%): {image_name}", flush=True)

                # OCR実行
                ocr_text = ""
                if not args.no_ocr:
                    ocr_text = run_ocr(final_path)

                # Obsidianに保存
                save_to_obsidian(image_name, ocr_text)

                # 現在の画像を前回の画像として保存
                subprocess.run(['cp', curr_image, prev_image])

    finally:
        # クリーンアップ
        import shutil
        shutil.rmtree(temp_dir, ignore_errors=True)
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)

        print(f"\n監視終了: {capture_count}枚キャプチャしました", flush=True)
        notify(f"監視終了: {capture_count}枚キャプチャ")

if __name__ == "__main__":
    main()
