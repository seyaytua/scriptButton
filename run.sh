#!/bin/bash
cd /Users/syuta/App_button

# 仮想環境が存在するか確認
if [ ! -d "venv" ]; then
    echo "仮想環境が見つかりません。setup.shを実行してください。"
    echo ""
    echo "実行方法:"
    echo "  ./setup.sh"
    exit 1
fi

source venv/bin/activate
python game_script_button.py
deactivate
