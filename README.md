# スクリプトボタン - ゲーム機モード

## 概要
ゲーム機のようなインターフェースでスクリプトを管理・実行できるアプリケーションです。

## ディレクトリ構造
App_button/ ├── game_script_button.py # メインアプリケーション ├── cassettes/ # カセット（スクリプト）フォルダ │ ├── hello_world/ │ │ ├── main.py │ │ ├── info.json │ │ └── icon.png (オプション) │ ├── calculator/ │ └── notepad/ └── saves/ # セーブデータ └── last_save.json


## 使い方

### 1. アプリケーションの起動
```bash
cd /Users/syuta/App_button
python game_script_button.py
2. カセット（スクリプト）の作成
cassettesフォルダ内に新しいフォルダを作成し、以下のファイルを配置：

main.py (または .bat, .exe): 実行するスクリプト
info.json: カセット情報
icon.png (オプション): アイコン画像
info.jsonの例:

Copy{
  "name": "カセット名",
  "description": "カセットの説明",
  "script": "main.py",
  "icon": "icon.png"
}
3. ボタンの割り当て（管理者モード）
「管理者モード」ボタンをクリック
割り当てたいスロットをクリック
カセットを選択して「割り当て」
4. スクリプトの実行（ユーザーモード）
「ユーザーモード」に切り替え
実行したいボタンをクリック
5. 設定の保存・読み込み
セーブ: 現在のボタン配置を保存
ロード: 保存した配置を読み込み
アプリ終了時に自動的にlast_save.jsonに保存されます
6. ヘルプ
「ヘルプ」ボタンで各ボタンの説明を確認できます

特徴
最大10個のボタンを配置可能
ゲーム機風の直感的なUI
管理者モードとユーザーモードの切り替え
セーブデータによる複数の配置パターン管理
カセットごとのアイコンと説明表示
必要なパッケージ
Python 3.11.5
PySide6
インストール:

Copypip install PySide6
