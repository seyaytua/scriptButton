#!/bin/bash

echo "========================================="
echo "スクリプトボタン - セットアップ"
echo "========================================="
echo ""

# ディレクトリに移動
cd /Users/syuta/App_button

# Pythonバージョンの確認
echo "Pythonバージョンを確認中..."
PYTHON_CMD=""

# Python 3.11.5を探す
if command -v python3.11 &> /dev/null; then
    PYTHON_VERSION=$(python3.11 --version 2>&1 | awk '{print $2}')
    if [[ $PYTHON_VERSION == 3.11.* ]]; then
        PYTHON_CMD="python3.11"
        echo "✓ Python 3.11を検出: $PYTHON_VERSION"
    fi
elif command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    if [[ $PYTHON_VERSION == 3.11.* ]]; then
        PYTHON_CMD="python3"
        echo "✓ Python 3.11を検出: $PYTHON_VERSION"
    else
        echo "⚠ 警告: Python $PYTHON_VERSION が検出されました"
        echo "   Python 3.11.5の使用を推奨します"
        PYTHON_CMD="python3"
    fi
fi

if [ -z "$PYTHON_CMD" ]; then
    echo "✗ エラー: Python 3.11が見つかりません"
    exit 1
fi

# 既存の仮想環境を削除
if [ -d "venv" ]; then
    echo ""
    echo "既存の仮想環境を削除中..."
    rm -rf venv
    echo "✓ 削除しました"
fi

# 仮想環境の作成
echo ""
echo "仮想環境を作成中..."
$PYTHON_CMD -m venv venv
echo "✓ 仮想環境を作成しました"

# 仮想環境の有効化
echo ""
echo "仮想環境を有効化中..."
source venv/bin/activate

# 作成された仮想環境のPythonバージョンを確認
VENV_PYTHON_VERSION=$(python --version 2>&1 | awk '{print $2}')
echo "✓ 仮想環境のPythonバージョン: $VENV_PYTHON_VERSION"

# pipのアップグレード
echo ""
echo "pipをアップグレード中..."
pip install --upgrade pip

# 依存パッケージのインストール
echo ""
echo "依存パッケージをインストール中..."
pip install -r requirements.txt

echo ""
echo "========================================="
echo "✓ セットアップが完了しました！"
echo "========================================="
echo ""
echo "アプリケーションを起動するには:"
echo "  ./run.sh"
echo ""
echo "または:"
echo "  source venv/bin/activate"
echo "  python game_script_button.py"
echo ""

deactivate
