#!/usr/bin/env python3
"""
画面キャプチャを実行し、選択範囲の座標を記録するスクリプト
"""
import subprocess
import sys
import os
import tempfile
import time
import threading

def capture_with_region(output_path, region_file):
    """screencaptureを実行し、座標を記録"""

    try:
        import Quartz
        from Quartz import CGEventSourceCreate, kCGEventSourceStateHIDSystemState
    except ImportError:
        # Quartzがない場合は通常のキャプチャのみ
        subprocess.run(['screencapture', '-i', '-x', output_path])
        return os.path.exists(output_path) and os.path.getsize(output_path) > 0

    # マウス座標を記録するための変数
    positions = []
    capturing = True

    def monitor_mouse():
        """マウス位置を監視するスレッド"""
        nonlocal positions, capturing
        screen_height = Quartz.CGDisplayPixelsHigh(Quartz.CGMainDisplayID())

        while capturing:
            try:
                loc = Quartz.NSEvent.mouseLocation()
                x = int(loc.x)
                y = int(screen_height - loc.y)

                # マウスボタンが押されているか確認
                buttons = Quartz.NSEvent.pressedMouseButtons()
                if buttons & 1:  # 左ボタン
                    positions.append((x, y))

                time.sleep(0.02)
            except:
                pass

    # 監視スレッドを開始
    monitor_thread = threading.Thread(target=monitor_mouse, daemon=True)
    monitor_thread.start()

    # screencaptureを実行
    subprocess.run(['screencapture', '-i', '-x', output_path])

    # 監視を停止
    capturing = False
    monitor_thread.join(timeout=0.5)

    # 座標を計算して保存
    if len(positions) >= 2:
        start_x, start_y = positions[0]
        end_x, end_y = positions[-1]

        # 座標を正規化（左上と右下に変換）
        x = min(start_x, end_x)
        y = min(start_y, end_y)
        w = abs(end_x - start_x)
        h = abs(end_y - start_y)

        if w > 10 and h > 10:  # 最小サイズチェック
            with open(region_file, 'w') as f:
                f.write(f"{x},{y},{w},{h}")
            print(f"Region saved: {x},{y},{w},{h}")

    return os.path.exists(output_path) and os.path.getsize(output_path) > 0

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: capture_with_region.py <output_path> <region_file>")
        sys.exit(1)

    output_path = sys.argv[1]
    region_file = sys.argv[2]

    # 出力ディレクトリを作成
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    if capture_with_region(output_path, region_file):
        print(f"Captured: {output_path}")
    else:
        print("Capture cancelled or failed")
        sys.exit(1)
