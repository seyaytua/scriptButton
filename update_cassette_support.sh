#!/bin/bash

echo "========================================="
echo "カセットサポート機能の更新"
echo "========================================="
echo ""

cd /Users/syuta/App_button

# バックアップ作成
echo "既存ファイルをバックアップ中..."
cp game_script_button.py game_script_button.py.backup
echo "✓ バックアップ完了: game_script_button.py.backup"
echo ""

# 新しいgame_script_button.pyを作成
cat > game_script_button.py << 'PYTHON_EOF'
import sys
import json
import subprocess
import hashlib
import ast
import shutil
from datetime import datetime
from pathlib import Path
from PySide6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                               QHBoxLayout, QPushButton, QGridLayout, QDialog,
                               QLabel, QLineEdit, QFileDialog, QMessageBox,
                               QTextEdit, QListWidget, QListWidgetItem, QFrame,
                               QScrollArea, QColorDialog, QInputDialog, QCheckBox,
                               QComboBox, QTableWidget, QTableWidgetItem, QHeaderView,
                               QProgressDialog, QTabWidget, QTreeWidget, QTreeWidgetItem)
from PySide6.QtCore import Qt, QSize, QMimeData, QPoint, Signal
from PySide6.QtGui import (QIcon, QPixmap, QFont, QColor, QPalette, QPainter,
                          QDrag, QPen, QBrush)

# 管理者パスワードのハッシュ（yamabuki）
ADMIN_PASSWORD_HASH = hashlib.sha256("yamabuki".encode()).hexdigest()

# テーマ定義
THEMES = {
    "ダークモード": {
        "background": "qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 #0f1419, stop:1 #2c3e50)",
        "button_frame": "#1a252f",
        "empty_slot": "#34495e",
        "text_color": "white"
    },
    "ネイビーモード": {
        "background": "qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 #003087, stop:1 #000033)",
        "button_frame": "#001a4d",
        "empty_slot": "#003087",
        "text_color": "white"
    },
    "レトロモード": {
        "background": "qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 #8B4513, stop:1 #654321)",
        "button_frame": "#5C4033",
        "empty_slot": "#8B7355",
        "text_color": "#FFE4B5"
    },
    "ライトモード": {
        "background": "qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 #f0f0f0, stop:1 #e0e0e0)",
        "button_frame": "#ffffff",
        "empty_slot": "#d0d0d0",
        "text_color": "#333333"
    }
}

class ExecutionLog:
    """実行ログ管理クラス"""
    def __init__(self, log_file):
        self.log_file = Path(log_file)
        self.logs = []
        self.load_logs()
    
    def load_logs(self):
        """ログを読み込み"""
        if self.log_file.exists():
            try:
                with open(self.log_file, 'r', encoding='utf-8') as f:
                    self.logs = json.load(f)
            except Exception as e:
                print(f"ログ読み込みエラー: {e}")
                self.logs = []
    
    def add_log(self, cassette_name, cassette_folder):
        """ログを追加"""
        log_entry = {
            'cassette_name': cassette_name,
            'cassette_folder': cassette_folder,
            'timestamp': datetime.now().isoformat()
        }
        self.logs.append(log_entry)
        self.save_logs()
    
    def save_logs(self):
        """ログを保存"""
        try:
            with open(self.log_file, 'w', encoding='utf-8') as f:
                json.dump(self.logs, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"ログ保存エラー: {e}")
    
    def get_recent_logs(self, limit=50):
        """最近のログを取得"""
        return self.logs[-limit:][::-1]

class DependencyChecker:
    """依存ライブラリチェッカー"""
    @staticmethod
    def check_python_script(script_path):
        """Pythonスクリプトの依存関係をチェック"""
        try:
            with open(script_path, 'r', encoding='utf-8') as f:
                tree = ast.parse(f.read())
            
            imports = set()
            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    for alias in node.names:
                        imports.add(alias.name.split('.')[0])
                elif isinstance(node, ast.ImportFrom):
                    if node.module:
                        imports.add(node.module.split('.')[0])
            
            # 標準ライブラリを除外
            stdlib_modules = set(sys.stdlib_module_names)
            third_party = imports - stdlib_modules
            
            # インストール状況をチェック
            missing = []
            installed = []
            
            for module in third_party:
                try:
                    __import__(module)
                    installed.append(module)
                except ImportError:
                    missing.append(module)
            
            return {
                'all_imports': list(imports),
                'third_party': list(third_party),
                'installed': installed,
                'missing': missing
            }
        except Exception as e:
            return {
                'error': str(e),
                'all_imports': [],
                'third_party': [],
                'installed': [],
                'missing': []
            }

class ScriptFileSelector(QDialog):
    """スクリプトファイル選択ダイアログ"""
    def __init__(self, folder_path, current_script=None, parent=None):
        super().__init__(parent)
        self.folder_path = Path(folder_path)
        self.current_script = current_script
        self.selected_script = None
        self.setWindowTitle("実行ファイルを選択")
        self.setMinimumSize(600, 500)
        self.setup_ui()
    
    def setup_ui(self):
        """UIのセットアップ"""
        layout = QVBoxLayout()
        
        # タイトル
        title = QLabel("📁 実行するスクリプトファイルを選択してください")
        title.setStyleSheet("font-size: 16px; font-weight: bold; color: white; padding: 10px;")
        title.setAlignment(Qt.AlignCenter)
        layout.addWidget(title)
        
        # フォルダパス表示
        path_label = QLabel(f"フォルダ: {self.folder_path}")
        path_label.setStyleSheet("color: #95a5a6; font-style: italic; padding: 5px;")
        layout.addWidget(path_label)
        
        # ツリービュー
        self.tree = QTreeWidget()
        self.tree.setHeaderLabels(["ファイル名", "相対パス", "種類"])
        self.tree.setColumnWidth(0, 250)
        self.tree.setColumnWidth(1, 200)
        self.tree.itemDoubleClicked.connect(self.on_item_double_clicked)
        
        # フォルダ内のスクリプトファイルを再帰的に検索
        self.populate_tree()
        
        layout.addWidget(self.tree)
        
        # 依存関係チェック結果
        layout.addWidget(QLabel("依存ライブラリ情報:"))
        self.dependency_text = QTextEdit()
        self.dependency_text.setReadOnly(True)
        self.dependency_text.setMaximumHeight(120)
        self.dependency_text.setPlaceholderText("Pythonファイルを選択すると依存ライブラリ情報が表示されます")
        layout.addWidget(self.dependency_text)
        
        # ツリーの選択変更時に依存関係をチェック
        self.tree.itemSelectionChanged.connect(self.check_dependencies)
        
        # ボタン
        button_layout = QHBoxLayout()
        
        select_btn = QPushButton("✅ 選択")
        select_btn.clicked.connect(self.select_file)
        select_btn.setStyleSheet("""
            QPushButton {
                background-color: #27ae60;
                color: white;
                font-size: 14px;
                font-weight: bold;
                padding: 10px 30px;
                border-radius: 5px;
            }
            QPushButton:hover {
                background-color: #229954;
            }
        """)
        
        cancel_btn = QPushButton("キャンセル")
        cancel_btn.clicked.connect(self.reject)
        cancel_btn.setStyleSheet("""
            QPushButton {
                background-color: #7f8c8d;
                color: white;
                font-size: 14px;
                padding: 10px 30px;
                border-radius: 5px;
            }
        """)
        
        button_layout.addStretch()
        button_layout.addWidget(select_btn)
        button_layout.addWidget(cancel_btn)
        layout.addLayout(button_layout)
        
        self.setLayout(layout)
        self.setStyleSheet("QDialog { background-color: #2c3e50; } QLabel { color: white; }")
    
    def populate_tree(self):
        """ツリーにファイルを追加"""
        script_extensions = {'.py', '.bat', '.exe', '.sh', '.command'}
        
        def add_directory(parent_item, directory, base_path):
            """ディレクトリを再帰的に追加"""
            try:
                items = sorted(directory.iterdir(), key=lambda x: (not x.is_dir(), x.name.lower()))
                
                for item in items:
                    if item.is_dir():
                        # サブディレクトリ
                        if not item.name.startswith('.'):  # 隠しフォルダは除外
                            folder_item = QTreeWidgetItem(parent_item)
                            folder_item.setText(0, f"📁 {item.name}")
                            folder_item.setText(1, str(item.relative_to(base_path)))
                            folder_item.setText(2, "フォルダ")
                            folder_item.setData(0, Qt.UserRole, None)  # フォルダは選択不可
                            add_directory(folder_item, item, base_path)
                    elif item.suffix.lower() in script_extensions:
                        # スクリプトファイル
                        file_item = QTreeWidgetItem(parent_item)
                        
                        # アイコン
                        icon = "🐍" if item.suffix == '.py' else "📜"
                        file_item.setText(0, f"{icon} {item.name}")
                        file_item.setText(1, str(item.relative_to(base_path)))
                        file_item.setText(2, item.suffix[1:].upper())
                        file_item.setData(0, Qt.UserRole, str(item))
                        
                        # 現在のスクリプトをハイライト
                        if self.current_script and item == Path(self.current_script):
                            file_item.setBackground(0, QColor("#3498db"))
                            file_item.setBackground(1, QColor("#3498db"))
                            file_item.setBackground(2, QColor("#3498db"))
                            self.tree.setCurrentItem(file_item)
            
            except PermissionError:
                pass
        
        # ルートから追加
        add_directory(self.tree.invisibleRootItem(), self.folder_path, self.folder_path)
        
        # ツリーを展開
        self.tree.expandAll()
    
    def check_dependencies(self):
        """依存関係をチェック"""
        current_item = self.tree.currentItem()
        if not current_item:
            return
        
        script_path = current_item.data(0, Qt.UserRole)
        if script_path and script_path.endswith('.py'):
            result = DependencyChecker.check_python_script(script_path)
            
            if 'error' in result:
                self.dependency_text.setPlainText(f"エラー: {result['error']}")
            else:
                text = "📦 依存ライブラリチェック結果:\n\n"
                
                if result['third_party']:
                    text += "サードパーティライブラリ:\n"
                    for lib in result['third_party']:
                        status = "✅ インストール済み" if lib in result['installed'] else "❌ 未インストール"
                        text += f"  • {lib}: {status}\n"
                    
                    if result['missing']:
                        text += f"\n⚠️ 不足しているライブラリ: {', '.join(result['missing'])}\n"
                        text += f"\nインストールコマンド:\n"
                        text += f"pip install {' '.join(result['missing'])}"
                else:
                    text += "✅ 標準ライブラリのみ使用（追加インストール不要）"
                
                self.dependency_text.setPlainText(text)
        else:
            self.dependency_text.setPlainText("Pythonスクリプト以外は依存関係チェックをスキップします。")
    
    def on_item_double_clicked(self, item, column):
        """アイテムダブルクリック時"""
        if item.data(0, Qt.UserRole):  # ファイルの場合
            self.select_file()
    
    def select_file(self):
        """ファイルを選択"""
        current_item = self.tree.currentItem()
        if not current_item:
            QMessageBox.warning(self, "警告", "ファイルを選択してください。")
            return
        
        script_path = current_item.data(0, Qt.UserRole)
        if not script_path:
            QMessageBox.warning(self, "警告", "実行可能なファイルを選択してください。")
            return
        
        self.selected_script = script_path
        self.accept()
    
    def get_selected_script(self):
        """選択されたスクリプトを取得"""
        return self.selected_script

class CassetteInfo:
    """カセット（スクリプト）情報を管理するクラス"""
    def __init__(self, folder_path):
        self.folder_path = Path(folder_path)
        self.name = self.folder_path.name
        self.script_path = None
        self.icon_path = None
        self.description = ""
        self.icon_color = "#4CAF50"
        self.tags = []
        self.is_favorite = False
        self.load_info()
    
    def load_info(self):
        """カセット情報を読み込み"""
        info_file = self.folder_path / "info.json"
        if info_file.exists():
            try:
                with open(info_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    self.name = data.get('name', self.folder_path.name)
                    self.description = data.get('description', '')
                    self.icon_color = data.get('icon_color', '#4CAF50')
                    self.tags = data.get('tags', [])
                    self.is_favorite = data.get('is_favorite', False)
                    
                    # スクリプトパス（相対パスで保存されている場合に対応）
                    script_name = data.get('script', 'main.py')
                    self.script_path = self.folder_path / script_name
                    
                    icon_name = data.get('icon', 'icon.png')
                    self.icon_path = self.folder_path / icon_name
            except Exception as e:
                print(f"カセット情報の読み込みエラー: {e}")
        
        # スクリプトが存在しない場合は再帰的に検索
        if not self.script_path or not self.script_path.exists():
            self.script_path = self.find_main_script()
        
        # デフォルトのアイコンを探す
        if not self.icon_path or not self.icon_path.exists():
            for ext in ['.png', '.jpg', '.ico']:
                icons = list(self.folder_path.glob(f'*{ext}'))
                if icons:
                    self.icon_path = icons[0]
                    break
    
    def find_main_script(self):
        """メインスクリプトを再帰的に検索"""
        script_extensions = ['.py', '.bat', '.exe', '.sh']
        
        # まずルートディレクトリを検索
        for ext in script_extensions:
            scripts = list(self.folder_path.glob(f'*{ext}'))
            if scripts:
                return scripts[0]
        
        # 次にサブディレクトリを検索
        for ext in script_extensions:
            scripts = list(self.folder_path.rglob(f'*{ext}'))
            if scripts:
                return scripts[0]
        
        return None
    
    def save_info(self):
        """カセット情報を保存"""
        info_file = self.folder_path / "info.json"
        
        # スクリプトパスを相対パスで保存
        script_relative = self.script_path.relative_to(self.folder_path) if self.script_path else Path('main.py')
        icon_relative = self.icon_path.relative_to(self.folder_path) if self.icon_path else Path('icon.png')
        
        data = {
            'name': self.name,
            'description': self.description,
            'icon_color': self.icon_color,
            'tags': self.tags,
            'is_favorite': self.is_favorite,
            'script': str(script_relative),
            'icon': str(icon_relative)
        }
        try:
            with open(info_file, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"カセット情報の保存エラー: {e}")

class NewCassetteWizard(QDialog):
    """新規カセット作成ウィザード"""
    def __init__(self, cassettes_dir, parent=None):
        super().__init__(parent)
        self.cassettes_dir = cassettes_dir
        self.source_folder = None
        self.script_file = None
        self.setWindowTitle("新規カセット作成")
        self.setMinimumSize(700, 600)
        self.setup_ui()
    
    def setup_ui(self):
        """UIのセットアップ"""
        layout = QVBoxLayout()
        
        # タイトル
        title = QLabel("🎮 新規カセット作成ウィザード")
        title.setStyleSheet("font-size: 20px; font-weight: bold; color: white; padding: 10px;")
        title.setAlignment(Qt.AlignCenter)
        layout.addWidget(title)
        
        # ステップ1: フォルダ選択
        step1_frame = QFrame()
        step1_frame.setStyleSheet("QFrame { background-color: #34495e; border-radius: 10px; padding: 15px; }")
        step1_layout = QVBoxLayout()
        
        step1_label = QLabel("ステップ 1: アプリフォルダを選択")
        step1_label.setStyleSheet("font-weight: bold; font-size: 14px; color: white;")
        step1_layout.addWidget(step1_label)
        
        folder_layout = QHBoxLayout()
        self.folder_input = QLineEdit()
        self.folder_input.setPlaceholderText("フォルダを選択してください")
        self.folder_input.setReadOnly(True)
        folder_layout.addWidget(self.folder_input)
        
        folder_btn = QPushButton("📁 参照")
        folder_btn.clicked.connect(self.select_folder)
        folder_layout.addWidget(folder_btn)
        step1_layout.addLayout(folder_layout)
        
        step1_frame.setLayout(step1_layout)
        layout.addWidget(step1_frame)
        
        # ステップ2: スクリプト選択
        step2_frame = QFrame()
        step2_frame.setStyleSheet("QFrame { background-color: #34495e; border-radius: 10px; padding: 15px; }")
        step2_layout = QVBoxLayout()
        
        step2_label = QLabel("ステップ 2: 実行ファイルを選択")
        step2_label.setStyleSheet("font-weight: bold; font-size: 14px; color: white;")
        step2_layout.addWidget(step2_label)
        
        script_select_layout = QHBoxLayout()
        self.script_input = QLineEdit()
        self.script_input.setPlaceholderText("実行ファイルを選択してください")
        self.script_input.setReadOnly(True)
        script_select_layout.addWidget(self.script_input)
        
        self.script_browse_btn = QPushButton("🔍 ファイル選択")
        self.script_browse_btn.setEnabled(False)
        self.script_browse_btn.clicked.connect(self.select_script)
        script_select_layout.addWidget(self.script_browse_btn)
        step2_layout.addLayout(script_select_layout)
        
        # 依存関係チェック結果
        self.dependency_text = QTextEdit()
        self.dependency_text.setReadOnly(True)
        self.dependency_text.setMaximumHeight(100)
        self.dependency_text.setPlaceholderText("Pythonスクリプトの場合、依存ライブラリ情報がここに表示されます")
        step2_layout.addWidget(self.dependency_text)
        
        step2_frame.setLayout(step2_layout)
        layout.addWidget(step2_frame)
        
        # ステップ3: カセット情報
        step3_frame = QFrame()
        step3_frame.setStyleSheet("QFrame { background-color: #34495e; border-radius: 10px; padding: 15px; }")
        step3_layout = QVBoxLayout()
        
        step3_label = QLabel("ステップ 3: カセット情報を入力")
        step3_label.setStyleSheet("font-weight: bold; font-size: 14px; color: white;")
        step3_layout.addWidget(step3_label)
        
        # タイトル
        title_layout = QHBoxLayout()
        title_layout.addWidget(QLabel("タイトル:"))
        self.title_input = QLineEdit()
        self.title_input.setPlaceholderText("カセット名を入力")
        title_layout.addWidget(self.title_input)
        step3_layout.addLayout(title_layout)
        
        # アイコン
        icon_layout = QHBoxLayout()
        icon_layout.addWidget(QLabel("アイコン:"))
        self.icon_input = QLineEdit()
        self.icon_input.setPlaceholderText("画像ファイル（オプション）")
        icon_layout.addWidget(self.icon_input)
        
        icon_btn = QPushButton("🖼️ 参照")
        icon_btn.clicked.connect(self.select_icon)
        icon_layout.addWidget(icon_btn)
        step3_layout.addLayout(icon_layout)
        
        # 背景色
        color_layout = QHBoxLayout()
        color_layout.addWidget(QLabel("背景色:"))
        self.color_button = QPushButton()
        self.color_button.setFixedSize(100, 30)
        self.current_color = "#4CAF50"
        self.color_button.setStyleSheet(f"background-color: {self.current_color};")
        self.color_button.clicked.connect(self.choose_color)
        color_layout.addWidget(self.color_button)
        color_layout.addStretch()
        step3_layout.addLayout(color_layout)
        
        # 説明
        step3_layout.addWidget(QLabel("説明:"))
        self.description_input = QTextEdit()
        self.description_input.setPlaceholderText("カセットの説明を入力（ヘルプに表示されます）")
        self.description_input.setMaximumHeight(80)
        step3_layout.addWidget(self.description_input)
        
        # タグ
        tag_layout = QHBoxLayout()
        tag_layout.addWidget(QLabel("タグ:"))
        self.tag_input = QLineEdit()
        self.tag_input.setPlaceholderText("カンマ区切り（例: 仕事,ツール）")
        tag_layout.addWidget(self.tag_input)
        step3_layout.addLayout(tag_layout)
        
        # お気に入り
        self.favorite_check = QCheckBox("お気に入りに追加")
        step3_layout.addWidget(self.favorite_check)
        
        step3_frame.setLayout(step3_layout)
        layout.addWidget(step3_frame)
        
        # ボタン
        button_layout = QHBoxLayout()
        create_btn = QPushButton("✨ カセット作成")
        create_btn.clicked.connect(self.create_cassette)
        create_btn.setStyleSheet("""
            QPushButton {
                background-color: #27ae60;
                color: white;
                font-size: 14px;
                font-weight: bold;
                padding: 10px 30px;
                border-radius: 5px;
            }
            QPushButton:hover {
                background-color: #229954;
            }
        """)
        
        cancel_btn = QPushButton("キャンセル")
        cancel_btn.clicked.connect(self.reject)
        cancel_btn.setStyleSheet("""
            QPushButton {
                background-color: #7f8c8d;
                color: white;
                font-size: 14px;
                padding: 10px 30px;
                border-radius: 5px;
            }
        """)
        
        button_layout.addStretch()
        button_layout.addWidget(create_btn)
        button_layout.addWidget(cancel_btn)
        layout.addLayout(button_layout)
        
        self.setLayout(layout)
        self.setStyleSheet("QDialog { background-color: #2c3e50; } QLabel { color: white; }")
    
    def select_folder(self):
        """フォルダを選択"""
        folder = QFileDialog.getExistingDirectory(self, "アプリフォルダを選択")
        if folder:
            self.source_folder = Path(folder)
            self.folder_input.setText(str(self.source_folder))
            
            # フォルダ名をデフォルトタイトルに設定
            self.title_input.setText(self.source_folder.name)
            
            # スクリプト選択ボタンを有効化
            self.script_browse_btn.setEnabled(True)
            self.script_input.clear()
            self.script_file = None
    
    def select_script(self):
        """スクリプトファイルを選択"""
        if not self.source_folder:
            QMessageBox.warning(self, "警告", "先にフォルダを選択してください。")
            return
        
        dialog = ScriptFileSelector(self.source_folder, self.script_file, self)
        if dialog.exec_() == QDialog.Accepted:
            self.script_file = dialog.get_selected_script()
            if self.script_file:
                relative_path = Path(self.script_file).relative_to(self.source_folder)
                self.script_input.setText(str(relative_path))
                self.check_dependencies()
    
    def check_dependencies(self):
        """依存関係をチェック"""
        if self.script_file and self.script_file.endswith('.py'):
            result = DependencyChecker.check_python_script(self.script_file)
            
            if 'error' in result:
                self.dependency_text.setPlainText(f"エラー: {result['error']}")
            else:
                text = "📦 依存ライブラリチェック結果:\n\n"
                
                if result['third_party']:
                    text += "サードパーティライブラリ:\n"
                    for lib in result['third_party']:
                        status = "✅ インストール済み" if lib in result['installed'] else "❌ 未インストール"
                        text += f"  • {lib}: {status}\n"
                    
                    if result['missing']:
                        text += f"\n⚠️ 不足しているライブラリ: {', '.join(result['missing'])}\n"
                        text += f"\nインストールコマンド:\n"
                        text += f"pip install {' '.join(result['missing'])}"
                else:
                    text += "✅ 標準ライブラリのみ使用（追加インストール不要）"
                
                self.dependency_text.setPlainText(text)
        else:
            self.dependency_text.setPlainText("Pythonスクリプト以外は依存関係チェックをスキップします。")
    
    def select_icon(self):
        """アイコンを選択"""
        file_path, _ = QFileDialog.getOpenFileName(
            self,
            "アイコン画像を選択",
            "",
            "Image Files (*.png *.jpg *.ico)"
        )
        if file_path:
            self.icon_input.setText(file_path)
    
    def choose_color(self):
        """背景色を選択"""
        color = QColorDialog.getColor(QColor(self.current_color), self)
        if color.isValid():
            self.current_color = color.name()
            self.color_button.setStyleSheet(f"background-color: {self.current_color};")
    
    def create_cassette(self):
        """カセットを作成"""
        if not self.source_folder:
            QMessageBox.warning(self, "エラー", "フォルダを選択してください。")
            return
        
        if not self.script_file:
            QMessageBox.warning(self, "エラー", "実行ファイルを選択してください。")
            return
        
        title = self.title_input.text().strip()
        if not title:
            QMessageBox.warning(self, "エラー", "タイトルを入力してください。")
            return
        
        # カセットフォルダ名を生成（安全な名前に変換）
        safe_name = "".join(c if c.isalnum() or c in ('-', '_') else '_' for c in title)
        cassette_folder = self.cassettes_dir / safe_name
        
        # 既存チェック
        if cassette_folder.exists():
            reply = QMessageBox.question(
                self,
                "確認",
                f"'{safe_name}' は既に存在します。上書きしますか？",
                QMessageBox.Yes | QMessageBox.No
            )
            if reply == QMessageBox.No:
                return
            shutil.rmtree(cassette_folder)
        
        # プログレスダイアログ
        progress = QProgressDialog("カセットを作成中...", None, 0, 100, self)
        progress.setWindowModality(Qt.WindowModal)
        progress.setValue(10)
        
        try:
            # フォルダをコピー
            progress.setLabelText("フォルダをコピー中...")
            shutil.copytree(self.source_folder, cassette_folder)
            progress.setValue(50)
            
            # アイコンをコピー
            icon_path = None
            if self.icon_input.text():
                progress.setLabelText("アイコンをコピー中...")
                icon_source = Path(self.icon_input.text())
                icon_dest = cassette_folder / f"icon{icon_source.suffix}"
                shutil.copy2(icon_source, icon_dest)
                icon_path = icon_dest.relative_to(cassette_folder)
            progress.setValue(70)
            
            # info.jsonを作成
            progress.setLabelText("設定ファイルを作成中...")
            script_relative = Path(self.script_file).relative_to(self.source_folder)
            tags = [tag.strip() for tag in self.tag_input.text().split(',') if tag.strip()]
            
            info_data = {
                'name': title,
                'description': self.description_input.toPlainText(),
                'icon_color': self.current_color,
                'tags': tags,
                'is_favorite': self.favorite_check.isChecked(),
                'script': str(script_relative),
                'icon': str(icon_path) if icon_path else 'icon.png'
            }
            
            info_file = cassette_folder / "info.json"
            with open(info_file, 'w', encoding='utf-8') as f:
                json.dump(info_data, f, indent=2, ensure_ascii=False)
            
            progress.setValue(100)
            
            QMessageBox.information(
                self,
                "完成",
                f"カセット '{title}' を作成しました！\n\n保存先: {cassette_folder}\n実行ファイル: {script_relative}"
            )
            self.accept()
            
        except Exception as e:
            progress.close()
            QMessageBox.critical(self, "エラー", f"カセットの作成に失敗しました:\n{str(e)}")

class CassetteCard(QFrame):
    """カセットカード（Switch風）"""
    clicked = Signal()
    
    def __init__(self, cassette, parent=None):
        super().__init__(parent)
        self.cassette = cassette
        self.setMinimumSize(200, 280)
        self.setMaximumSize(200, 280)
        self.setup_ui()
    
    def setup_ui(self):
        """UIのセットアップ"""
        layout = QVBoxLayout()
        layout.setContentsMargins(10, 10, 10, 10)
        
        # お気に入りバッジ
        if self.cassette.is_favorite:
            fav_label = QLabel("⭐")
            fav_label.setAlignment(Qt.AlignRight)
            fav_label.setStyleSheet("font-size: 20px;")
            layout.addWidget(fav_label)
        
        # アイコン表示
        icon_label = QLabel()
        icon_label.setAlignment(Qt.AlignCenter)
        icon_label.setFixedSize(180, 180)
        
        if self.cassette.icon_path and self.cassette.icon_path.exists():
            pixmap = QPixmap(str(self.cassette.icon_path))
            pixmap = pixmap.scaled(180, 180, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            icon_label.setPixmap(pixmap)
        else:
            icon_label.setStyleSheet(f"""
                QLabel {{
                    background-color: {self.cassette.icon_color};
                    border-radius: 10px;
                    color: white;
                    font-size: 48px;
                    font-weight: bold;
                }}
            """)
            icon_label.setText(self.cassette.name[0].upper() if self.cassette.name else "?")
        
        layout.addWidget(icon_label)
        
        # タイトル
        title_label = QLabel(self.cassette.name)
        title_label.setAlignment(Qt.AlignCenter)
        title_label.setWordWrap(True)
        title_label.setStyleSheet("""
            QLabel {
                color: white;
                font-size: 14px;
                font-weight: bold;
                padding: 5px;
            }
        """)
        layout.addWidget(title_label)
        
        # タグ表示
        if self.cassette.tags:
            tags_label = QLabel(" ".join([f"#{tag}" for tag in self.cassette.tags[:3]]))
            tags_label.setAlignment(Qt.AlignCenter)
            tags_label.setStyleSheet("""
                QLabel {
                    color: #95a5a6;
                    font-size: 10px;
                }
            """)
            layout.addWidget(tags_label)
        
        self.setLayout(layout)
        self.setStyleSheet("""
            CassetteCard {
                background-color: #2c3e50;
                border-radius: 15px;
                border: 2px solid #34495e;
            }
            CassetteCard:hover {
                border: 2px solid #3498db;
                background-color: #34495e;
            }
        """)
    
    def mousePressEvent(self, event):
        """マウスクリックイベント"""
        if event.button() == Qt.LeftButton:
            self.clicked.emit()

class CarouselWidget(QWidget):
    """カルーセル表示ウィジェット"""
    cassette_selected = Signal(object)
    
    def __init__(self, cassettes, parent=None):
        super().__init__(parent)
        self.all_cassettes = cassettes
        self.filtered_cassettes = cassettes.copy()
        self.current_index = 0
        self.cards = []
        self.setup_ui()
    
    def setup_ui(self):
        """UIのセットアップ"""
        layout = QVBoxLayout()
        
        # フィルター
        filter_layout = QHBoxLayout()
        filter_layout.addWidget(QLabel("フィルター:"))
        
        self.favorite_filter = QCheckBox("⭐ お気に入りのみ")
        self.favorite_filter.stateChanged.connect(self.apply_filters)
        filter_layout.addWidget(self.favorite_filter)
        
        filter_layout.addWidget(QLabel("タグ:"))
        self.tag_combo = QComboBox()
        self.tag_combo.addItem("すべて")
        
        # すべてのタグを収集
        all_tags = set()
        for cassette in self.all_cassettes:
            all_tags.update(cassette.tags)
        for tag in sorted(all_tags):
            self.tag_combo.addItem(tag)
        
        self.tag_combo.currentTextChanged.connect(self.apply_filters)
        filter_layout.addWidget(self.tag_combo)
        filter_layout.addStretch()
        
        layout.addLayout(filter_layout)
        
        # カード表示エリア
        card_container = QWidget()
        card_container.setMinimumHeight(320)
        self.card_layout = QHBoxLayout()
        self.card_layout.setSpacing(20)
        self.card_layout.setAlignment(Qt.AlignCenter)
        card_container.setLayout(self.card_layout)
        
        scroll_area = QScrollArea()
        scroll_area.setWidget(card_container)
        scroll_area.setWidgetResizable(True)
        scroll_area.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll_area.setStyleSheet("""
            QScrollArea {
                background-color: transparent;
                border: none;
            }
        """)
        
        layout.addWidget(scroll_area)
        
        # ナビゲーションボタン
        nav_layout = QHBoxLayout()
        
        prev_btn = QPushButton("◀ 前へ")
        prev_btn.clicked.connect(self.previous_cassette)
        prev_btn.setStyleSheet(self.get_nav_button_style())
        
        select_btn = QPushButton("選択")
        select_btn.clicked.connect(self.select_current)
        select_btn.setStyleSheet("""
            QPushButton {
                background-color: #e74c3c;
                color: white;
                font-size: 16px;
                font-weight: bold;
                padding: 15px 40px;
                border-radius: 10px;
            }
            QPushButton:hover {
                background-color: #c0392b;
            }
        """)
        
        next_btn = QPushButton("次へ ▶")
        next_btn.clicked.connect(self.next_cassette)
        next_btn.setStyleSheet(self.get_nav_button_style())
        
        nav_layout.addStretch()
        nav_layout.addWidget(prev_btn)
        nav_layout.addWidget(select_btn)
        nav_layout.addWidget(next_btn)
        nav_layout.addStretch()
        
        layout.addLayout(nav_layout)
        
        self.setLayout(layout)
        self.update_cards()
    
    def get_nav_button_style(self):
        """ナビゲーションボタンのスタイル"""
        return """
            QPushButton {
                background-color: #3498db;
                color: white;
                font-size: 14px;
                font-weight: bold;
                padding: 15px 30px;
                border-radius: 10px;
            }
            QPushButton:hover {
                background-color: #2980b9;
            }
        """
    
    def apply_filters(self):
        """フィルターを適用"""
        self.filtered_cassettes = []
        
        for cassette in self.all_cassettes:
            # お気に入りフィルター
            if self.favorite_filter.isChecked() and not cassette.is_favorite:
                continue
            
            # タグフィルター
            selected_tag = self.tag_combo.currentText()
            if selected_tag != "すべて" and selected_tag not in cassette.tags:
                continue
            
            self.filtered_cassettes.append(cassette)
        
        self.current_index = 0
        self.update_cards()
    
    def update_cards(self):
        """カード表示を更新"""
        for card in self.cards:
            card.deleteLater()
        self.cards.clear()
        
        if not self.filtered_cassettes:
            no_result = QLabel("該当するカセットがありません")
            no_result.setStyleSheet("color: #95a5a6; font-size: 16px;")
            no_result.setAlignment(Qt.AlignCenter)
            self.card_layout.addWidget(no_result)
            self.cards.append(no_result)
            return
        
        visible_indices = []
        for i in range(-1, 2):
            index = (self.current_index + i) % len(self.filtered_cassettes)
            visible_indices.append(index)
        
        for idx in visible_indices:
            cassette = self.filtered_cassettes[idx]
            card = CassetteCard(cassette)
            
            if idx == self.current_index:
                card.setStyleSheet("""
                    CassetteCard {
                        background-color: #34495e;
                        border-radius: 15px;
                        border: 3px solid #e74c3c;
                    }
                """)
            
            card.clicked.connect(lambda c=cassette: self.cassette_selected.emit(c))
            self.card_layout.addWidget(card)
            self.cards.append(card)
    
    def next_cassette(self):
        """次のカセットへ"""
        if self.filtered_cassettes:
            self.current_index = (self.current_index + 1) % len(self.filtered_cassettes)
            self.update_cards()
    
    def previous_cassette(self):
        """前のカセットへ"""
        if self.filtered_cassettes:
            self.current_index = (self.current_index - 1) % len(self.filtered_cassettes)
            self.update_cards()
    
    def select_current(self):
        """現在のカセットを選択"""
        if self.filtered_cassettes:
            self.cassette_selected.emit(self.filtered_cassettes[self.current_index])

class CassetteEditDialog(QDialog):
    """カセット編集ダイアログ"""
    def __init__(self, cassette, parent=None):
        super().__init__(parent)
        self.cassette = cassette
        self.setWindowTitle(f"カセット編集 - {cassette.name}")
        self.setMinimumSize(500, 700)
        self.setup_ui()
    
    def setup_ui(self):
        """UIのセットアップ"""
        layout = QVBoxLayout()
        
        # 名前
        name_layout = QHBoxLayout()
        name_layout.addWidget(QLabel("カセット名:"))
        self.name_input = QLineEdit(self.cassette.name)
        name_layout.addWidget(self.name_input)
        layout.addLayout(name_layout)
        
        # スクリプト選択
        script_layout = QHBoxLayout()
        script_layout.addWidget(QLabel("実行ファイル:"))
        self.script_input = QLineEdit()
        if self.cassette.script_path:
            relative_path = self.cassette.script_path.relative_to(self.cassette.folder_path)
            self.script_input.setText(str(relative_path))
        self.script_input.setReadOnly(True)
        script_layout.addWidget(self.script_input)
        
        script_browse = QPushButton("🔍 変更")
        script_browse.clicked.connect(self.browse_script)
        script_layout.addWidget(script_browse)
        layout.addLayout(script_layout)
        
        # アイコン選択
        icon_layout = QHBoxLayout()
        icon_layout.addWidget(QLabel("アイコン:"))
        self.icon_input = QLineEdit(str(self.cassette.icon_path) if self.cassette.icon_path else "")
        icon_layout.addWidget(self.icon_input)
        icon_browse = QPushButton("参照")
        icon_browse.clicked.connect(self.browse_icon)
        icon_layout.addWidget(icon_browse)
        layout.addLayout(icon_layout)
        
        # アイコン色選択
        color_layout = QHBoxLayout()
        color_layout.addWidget(QLabel("アイコン色:"))
        self.color_button = QPushButton()
        self.color_button.setFixedSize(100, 30)
        self.color_button.setStyleSheet(f"background-color: {self.cassette.icon_color};")
        self.color_button.clicked.connect(self.choose_color)
        color_layout.addWidget(self.color_button)
        color_layout.addStretch()
        layout.addLayout(color_layout)
        
        # タグ
        tag_layout = QHBoxLayout()
        tag_layout.addWidget(QLabel("タグ:"))
        self.tag_input = QLineEdit(",".join(self.cassette.tags))
        self.tag_input.setPlaceholderText("カンマ区切り（例: 仕事,ツール）")
        tag_layout.addWidget(self.tag_input)
        layout.addLayout(tag_layout)
        
        # お気に入り
        self.favorite_check = QCheckBox("⭐ お気に入り")
        self.favorite_check.setChecked(self.cassette.is_favorite)
        layout.addWidget(self.favorite_check)
        
        # 説明
        layout.addWidget(QLabel("説明:"))
        self.description_text = QTextEdit()
        self.description_text.setPlainText(self.cassette.description)
        self.description_text.setMinimumHeight(200)
        layout.addWidget(self.description_text)
        
        # ボタン
        button_layout = QHBoxLayout()
        save_btn = QPushButton("保存")
        save_btn.clicked.connect(self.save_changes)
        cancel_btn = QPushButton("キャンセル")
        cancel_btn.clicked.connect(self.reject)
        button_layout.addWidget(save_btn)
        button_layout.addWidget(cancel_btn)
        layout.addLayout(button_layout)
        
        self.setLayout(layout)
    
    def browse_script(self):
        """スクリプトファイルを変更"""
        dialog = ScriptFileSelector(self.cassette.folder_path, str(self.cassette.script_path), self)
        if dialog.exec_() == QDialog.Accepted:
            selected_script = dialog.get_selected_script()
            if selected_script:
                self.cassette.script_path = Path(selected_script)
                relative_path = self.cassette.script_path.relative_to(self.cassette.folder_path)
                self.script_input.setText(str(relative_path))
    
    def browse_icon(self):
        """アイコンファイルを選択"""
        file_path, _ = QFileDialog.getOpenFileName(
            self,
            "アイコンを選択",
            "",
            "Image Files (*.png *.jpg *.ico)"
        )
        if file_path:
            self.icon_input.setText(file_path)
    
    def choose_color(self):
        """色を選択"""
        color = QColorDialog.getColor(QColor(self.cassette.icon_color), self)
        if color.isValid():
            self.cassette.icon_color = color.name()
            self.color_button.setStyleSheet(f"background-color: {color.name()};")
    
    def save_changes(self):
        """変更を保存"""
        self.cassette.name = self.name_input.text()
        self.cassette.description = self.description_text.toPlainText()
        self.cassette.tags = [tag.strip() for tag in self.tag_input.text().split(',') if tag.strip()]
        self.cassette.is_favorite = self.favorite_check.isChecked()
        
        icon_path_str = self.icon_input.text()
        if icon_path_str:
            self.cassette.icon_path = Path(icon_path_str)
        
        self.cassette.save_info()
        self.accept()

class SlotAssignDialog(QDialog):
    """スロット割り当てダイアログ"""
    def __init__(self, slot_number, cassettes, parent=None):
        super().__init__(parent)
        self.slot_number = slot_number
        self.cassettes = cassettes
        self.selected_cassette = None
        self.setWindowTitle(f"スロット {slot_number} にカセットを割り当て")
        self.setMinimumSize(800, 600)
        self.setup_ui()
    
    def setup_ui(self):
        """UIのセットアップ"""
        layout = QVBoxLayout()
        
        # タイトル
        title = QLabel(f"スロット {self.slot_number} に割り当てるカセットを選択")
        title.setStyleSheet("font-size: 18px; font-weight: bold; color: white;")
        title.setAlignment(Qt.AlignCenter)
        layout.addWidget(title)
        
        # カルーセル
        self.carousel = CarouselWidget(self.cassettes)
        self.carousel.cassette_selected.connect(self.on_cassette_selected)
        layout.addWidget(self.carousel)
        
        # 説明表示
        layout.addWidget(QLabel("説明:"))
        self.description_text = QTextEdit()
        self.description_text.setReadOnly(True)
        self.description_text.setMaximumHeight(100)
        layout.addWidget(self.description_text)
        
        # ボタン
        button_layout = QHBoxLayout()
        
        edit_btn = QPushButton("📝 カセット編集")
        edit_btn.clicked.connect(self.edit_cassette)
        edit_btn.setStyleSheet(self.get_button_style("#f39c12"))
        
        clear_btn = QPushButton("🗑️ クリア")
        clear_btn.clicked.connect(self.clear_slot)
        clear_btn.setStyleSheet(self.get_button_style("#95a5a6"))
        
        cancel_btn = QPushButton("キャンセル")
        cancel_btn.clicked.connect(self.reject)
        cancel_btn.setStyleSheet(self.get_button_style("#7f8c8d"))
        
        button_layout.addWidget(edit_btn)
        button_layout.addWidget(clear_btn)
        button_layout.addStretch()
        button_layout.addWidget(cancel_btn)
        
        layout.addLayout(button_layout)
        
        self.setLayout(layout)
        self.setStyleSheet("QDialog { background-color: #2c3e50; }")
    
    def get_button_style(self, color):
        """ボタンスタイルを取得"""
        return f"""
            QPushButton {{
                background-color: {color};
                color: white;
                font-size: 14px;
                font-weight: bold;
                padding: 10px 20px;
                border-radius: 5px;
            }}
            QPushButton:hover {{
                background-color: {QColor(color).darker(120).name()};
            }}
        """
    
    def on_cassette_selected(self, cassette):
        """カセット選択時"""
        self.selected_cassette = cassette
        self.description_text.setPlainText(cassette.description)
        self.accept()
    
    def edit_cassette(self):
        """カセットを編集"""
        if self.carousel.filtered_cassettes:
            current_cassette = self.carousel.filtered_cassettes[self.carousel.current_index]
            dialog = CassetteEditDialog(current_cassette, self)
            if dialog.exec_() == QDialog.Accepted:
                self.carousel.update_cards()
    
    def clear_slot(self):
        """スロットをクリア"""
        self.selected_cassette = None
        self.accept()
    
    def get_selected_cassette(self):
        """選択されたカセットを取得"""
        return self.selected_cassette

class GameButton(QPushButton):
    """ゲームボタンウィジェット（ドラッグ&ドロップ対応）"""
    def __init__(self, slot_number, parent=None):
        super().__init__(parent)
        self.slot_number = slot_number
        self.cassette = None
        self.setMinimumSize(150, 150)
        self.setMaximumSize(150, 150)
        self.setAcceptDrops(True)
        self.drag_start_position = None
        self.update_display()
    
    def set_cassette(self, cassette):
        """カセットを設定"""
        self.cassette = cassette
        self.update_display()
    
    def clear_cassette(self):
        """カセットをクリア"""
        self.cassette = None
        self.update_display()
    
    def update_display(self):
        """表示を更新"""
        if self.cassette:
            self.setText(self.cassette.name)
            if self.cassette.icon_path and self.cassette.icon_path.exists():
                self.setIcon(QIcon(str(self.cassette.icon_path)))
                self.setIconSize(QSize(64, 64))
            else:
                self.setIcon(QIcon())
            
            self.setStyleSheet(f"""
                QPushButton {{
                    background-color: {self.cassette.icon_color};
                    color: white;
                    border: 3px solid {QColor(self.cassette.icon_color).darker(120).name()};
                    border-radius: 10px;
                    font-size: 12px;
                    font-weight: bold;
                    padding: 5px;
                }}
                QPushButton:hover {{
                    background-color: {QColor(self.cassette.icon_color).lighter(110).name()};
                }}
                QPushButton:pressed {{
                    background-color: {QColor(self.cassette.icon_color).darker(120).name()};
                }}
            """)
        else:
            self.setText(f"スロット {self.slot_number}")
            self.setIcon(QIcon())
            self.setStyleSheet("""
                QPushButton {
                    background-color: #34495e;
                    color: #95a5a6;
                    border: 3px dashed #7f8c8d;
                    border-radius: 10px;
                    font-size: 12px;
                    padding: 5px;
                }
            """)
    
    def mousePressEvent(self, event):
        """マウス押下イベント"""
        if event.button() == Qt.LeftButton:
            self.drag_start_position = event.pos()
        super().mousePressEvent(event)
    
    def mouseMoveEvent(self, event):
        """マウス移動イベント（ドラッグ開始）"""
        if not (event.buttons() & Qt.LeftButton):
            return
        
        if not self.drag_start_position:
            return
        
        # 管理者モードかつカセットがある場合のみドラッグ可能
        main_window = self.window()
        if not hasattr(main_window, 'is_admin_mode') or not main_window.is_admin_mode:
            return
        
        if not self.cassette:
            return
        
        if (event.pos() - self.drag_start_position).manhattanLength() < QApplication.startDragDistance():
            return
        
        # ドラッグ開始
        drag = QDrag(self)
        mime_data = QMimeData()
        mime_data.setText(str(self.slot_number))
        drag.setMimeData(mime_data)
        
        # ドラッグ中の見た目（半透明）
        pixmap = self.grab()
        painter = QPainter(pixmap)
        painter.setCompositionMode(QPainter.CompositionMode_DestinationIn)
        painter.fillRect(pixmap.rect(), QColor(0, 0, 0, 127))
        painter.end()
        
        drag.setPixmap(pixmap)
        drag.setHotSpot(event.pos())
        
        drag.exec_(Qt.MoveAction)
    
    def dragEnterEvent(self, event):
        """ドラッグエンター"""
        if event.mimeData().hasText():
            event.acceptProposedAction()
            # ドロップ可能な視覚的フィードバック
            self.setStyleSheet(self.styleSheet() + "border: 3px solid #3498db;")
    
    def dragLeaveEvent(self, event):
        """ドラッグリーブ"""
        self.update_display()
    
    def dropEvent(self, event):
        """ドロップイベント"""
        source_slot = int(event.mimeData().text())
        target_slot = self.slot_number
        
        if source_slot != target_slot:
            # 親ウィンドウのボタン交換メソッドを呼び出し
            main_window = self.window()
            if hasattr(main_window, 'swap_buttons'):
                main_window.swap_buttons(source_slot, target_slot)
        
        self.update_display()
        event.acceptProposedAction()

class ExecutionLogDialog(QDialog):
    """実行ログダイアログ"""
    def __init__(self, execution_log, parent=None):
        super().__init__(parent)
        self.execution_log = execution_log
        self.setWindowTitle("実行ログ")
        self.setMinimumSize(700, 500)
        self.setup_ui()
    
    def setup_ui(self):
        """UIのセットアップ"""
        layout = QVBoxLayout()
        
        # タイトル
        title = QLabel("📊 実行ログ")
        title.setStyleSheet("font-size: 18px; font-weight: bold; color: white;")
        title.setAlignment(Qt.AlignCenter)
        layout.addWidget(title)
        
        # テーブル
        self.table = QTableWidget()
        self.table.setColumnCount(3)
        self.table.setHorizontalHeaderLabels(["カセット名", "実行日時", "フォルダ"])
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        
        logs = self.execution_log.get_recent_logs()
        self.table.setRowCount(len(logs))
        
        for row, log in enumerate(logs):
            self.table.setItem(row, 0, QTableWidgetItem(log['cassette_name']))
            
            timestamp = datetime.fromisoformat(log['timestamp'])
            self.table.setItem(row, 1, QTableWidgetItem(timestamp.strftime("%Y-%m-%d %H:%M:%S")))
            
            self.table.setItem(row, 2, QTableWidgetItem(log['cassette_folder']))
        
        layout.addWidget(self.table)
        
        # ボタン
        button_layout = QHBoxLayout()
        
        clear_btn = QPushButton("🗑️ ログクリア")
        clear_btn.clicked.connect(self.clear_logs)
        clear_btn.setStyleSheet("""
            QPushButton {
                background-color: #e74c3c;
                color: white;
                padding: 10px 20px;
                border-radius: 5px;
            }
        """)
        
        close_btn = QPushButton("閉じる")
        close_btn.clicked.connect(self.accept)
        close_btn.setStyleSheet("""
            QPushButton {
                background-color: #7f8c8d;
                color: white;
                padding: 10px 20px;
                border-radius: 5px;
            }
        """)
        
        button_layout.addWidget(clear_btn)
        button_layout.addStretch()
        button_layout.addWidget(close_btn)
        
        layout.addLayout(button_layout)
        
        self.setLayout(layout)
        self.setStyleSheet("QDialog { background-color: #2c3e50; } QLabel { color: white; }")
    
    def clear_logs(self):
        """ログをクリア"""
        reply = QMessageBox.question(
            self,
            "確認",
            "すべての実行ログを削除しますか？",
            QMessageBox.Yes | QMessageBox.No
        )
        
        if reply == QMessageBox.Yes:
            self.execution_log.logs = []
            self.execution_log.save_logs()
            self.table.setRowCount(0)
            QMessageBox.information(self, "完了", "ログをクリアしました。")

class HelpDialog(QDialog):
    """ヘルプダイアログ"""
    def __init__(self, buttons, parent=None):
        super().__init__(parent)
        self.setWindowTitle("ヘルプ - ボタンの説明")
        self.setMinimumSize(600, 400)
        self.buttons = buttons
        self.setup_ui()
    
    def setup_ui(self):
        """UIのセットアップ"""
        layout = QVBoxLayout()
        
        help_text = QTextEdit()
        help_text.setReadOnly(True)
        
        content = "<h2>スクリプトボタン ヘルプ</h2>"
        content += "<h3>各ボタンの説明:</h3>"
        
        for i, button in enumerate(self.buttons, 1):
            if button.cassette:
                fav = "⭐ " if button.cassette.is_favorite else ""
                content += f"<h4>スロット {i}: {fav}{button.cassette.name}</h4>"
                content += f"<p>{button.cassette.description if button.cassette.description else '説明なし'}</p>"
                if button.cassette.tags:
                    content += f"<p><i>タグ: {', '.join(button.cassette.tags)}</i></p>"
                if button.cassette.script_path:
                    relative_path = button.cassette.script_path.relative_to(button.cassette.folder_path)
                    content += f"<p><i>スクリプト: {relative_path}</i></p>"
                content += "<hr>"
            else:
                content += f"<h4>スロット {i}: 空き</h4>"
                content += "<p>カセットが割り当てられていません</p>"
                content += "<hr>"
        
        help_text.setHtml(content)
        layout.addWidget(help_text)
        
        close_button = QPushButton("閉じる")
        close_button.clicked.connect(self.accept)
        layout.addWidget(close_button)
        
        self.setLayout(layout)

class SaveLoadDialog(QDialog):
    """セーブ/ロードダイアログ"""
    def __init__(self, mode, saves_dir, parent=None):
        super().__init__(parent)
        self.mode = mode
        self.saves_dir = saves_dir
        self.selected_file = None
        self.setWindowTitle("セーブデータの保存" if mode == 'save' else "セーブデータの読み込み")
        self.setMinimumSize(400, 300)
        self.setup_ui()
    
    def setup_ui(self):
        """UIのセットアップ"""
        layout = QVBoxLayout()
        
        if self.mode == 'save':
            name_layout = QHBoxLayout()
            name_layout.addWidget(QLabel("セーブ名:"))
            self.save_name_input = QLineEdit()
            name_layout.addWidget(self.save_name_input)
            layout.addLayout(name_layout)
        else:
            layout.addWidget(QLabel("セーブデータを選択:"))
            self.save_list = QListWidget()
            
            for save_file in self.saves_dir.glob("*.json"):
                if save_file.name != "last_save.json":
                    self.save_list.addItem(save_file.stem)
            
            self.save_list.itemDoubleClicked.connect(self.accept)
            layout.addWidget(self.save_list)
        
        button_layout = QHBoxLayout()
        ok_button = QPushButton("OK")
        ok_button.clicked.connect(self.on_ok)
        cancel_button = QPushButton("キャンセル")
        cancel_button.clicked.connect(self.reject)
        
        button_layout.addWidget(ok_button)
        button_layout.addWidget(cancel_button)
        layout.addLayout(button_layout)
        
        self.setLayout(layout)
    
    def on_ok(self):
        """OK押下時の処理"""
        if self.mode == 'save':
            save_name = self.save_name_input.text().strip()
            if not save_name:
                QMessageBox.warning(self, "エラー", "セーブ名を入力してください")
                return
            self.selected_file = self.saves_dir / f"{save_name}.json"
        else:
            current_item = self.save_list.currentItem()
            if not current_item:
                QMessageBox.warning(self, "エラー", "セーブデータを選択してください")
                return
            self.selected_file = self.saves_dir / f"{current_item.text()}.json"
        
        self.accept()
    
    def get_selected_file(self):
        """選択されたファイルを取得"""
        return self.selected_file

class MainWindow(QMainWindow):
    """メインウィンドウ"""
    def __init__(self):
        super().__init__()
        self.setWindowTitle("スクリプトボタン")
        self.setMinimumSize(900, 750)
        
        self.base_dir = Path("/Users/syuta/App_button")
        self.cassettes_dir = self.base_dir / "cassettes"
        self.saves_dir = self.base_dir / "saves"
        self.config_file = self.base_dir / "config.json"
        self.log_file = self.base_dir / "execution_log.json"
        
        self.cassettes_dir.mkdir(exist_ok=True)
        self.saves_dir.mkdir(exist_ok=True)
        
        self.buttons = []
        self.cassettes = []
        self.is_admin_mode = False
        self.current_theme = "ダークモード"
        self.execution_log = ExecutionLog(self.log_file)
        
        self.load_config()
        self.load_cassettes()
        self.setup_ui()
        self.apply_theme()
        self.load_last_save()
    
    def load_config(self):
        """設定を読み込み"""
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    config = json.load(f)
                    self.current_theme = config.get('theme', 'ダークモード')
            except Exception as e:
                print(f"設定読み込みエラー: {e}")
    
    def save_config(self):
        """設定を保存"""
        config = {
            'theme': self.current_theme
        }
        try:
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(config, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"設定保存エラー: {e}")
    
    def load_cassettes(self):
        """カセットを読み込み"""
        self.cassettes = []
        for folder in self.cassettes_dir.iterdir():
            if folder.is_dir():
                cassette = CassetteInfo(folder)
                if cassette.script_path and cassette.script_path.exists():
                    self.cassettes.append(cassette)
        
        # お気に入りを優先してソート
        self.cassettes.sort(key=lambda c: (not c.is_favorite, c.name))
    
    def setup_ui(self):
        """UIのセットアップ"""
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        main_layout = QVBoxLayout()
        main_layout.setSpacing(20)
        main_layout.setContentsMargins(20, 20, 20, 20)
        
        # タイトル
        title_label = QLabel("スクリプトボタン")
        title_font = QFont()
        title_font.setPointSize(24)
        title_font.setBold(True)
        title_label.setFont(title_font)
        title_label.setAlignment(Qt.AlignCenter)
        title_label.setStyleSheet("color: white; padding: 10px;")
        main_layout.addWidget(title_label)
        
        # ボタングリッド
        self.button_frame = QFrame()
        grid_layout = QGridLayout()
        grid_layout.setSpacing(15)
        
        for i in range(10):
            button = GameButton(i + 1)
            button.clicked.connect(lambda checked, b=button: self.on_button_clicked(b))
            self.buttons.append(button)
            row = i // 5
            col = i % 5
            grid_layout.addWidget(button, row, col)
        
        self.button_frame.setLayout(grid_layout)
        main_layout.addWidget(self.button_frame)
        
        # コントロールボタン
        control_layout = QHBoxLayout()
        
        self.mode_button = QPushButton("🔒 管理者モード")
        self.mode_button.clicked.connect(self.toggle_mode)
        self.mode_button.setStyleSheet(self.get_control_button_style("#e74c3c"))
        control_layout.addWidget(self.mode_button)
        
        new_cassette_btn = QPushButton("➕ 新規カセット")
        new_cassette_btn.clicked.connect(self.create_new_cassette)
        new_cassette_btn.setStyleSheet(self.get_control_button_style("#27ae60"))
        control_layout.addWidget(new_cassette_btn)
        
        save_button = QPushButton("💾 セーブ")
        save_button.clicked.connect(self.save_configuration)
        save_button.setStyleSheet(self.get_control_button_style("#3498db"))
        control_layout.addWidget(save_button)
        
        load_button = QPushButton("📂 ロード")
        load_button.clicked.connect(self.load_configuration)
        load_button.setStyleSheet(self.get_control_button_style("#9b59b6"))
        control_layout.addWidget(load_button)
        
        log_button = QPushButton("📊 実行ログ")
        log_button.clicked.connect(self.show_execution_log)
        log_button.setStyleSheet(self.get_control_button_style("#16a085"))
        control_layout.addWidget(log_button)
        
        theme_button = QPushButton("🎨 テーマ")
        theme_button.clicked.connect(self.change_theme)
        theme_button.setStyleSheet(self.get_control_button_style("#e67e22"))
        control_layout.addWidget(theme_button)
        
        help_button = QPushButton("❓ ヘルプ")
        help_button.clicked.connect(self.show_help)
        help_button.setStyleSheet(self.get_control_button_style("#f39c12"))
        control_layout.addWidget(help_button)
        
        control_layout.addStretch()
        main_layout.addLayout(control_layout)
        
        central_widget.setLayout(main_layout)
    
    def get_control_button_style(self, color):
        """コントロールボタンのスタイル"""
        hover_color = QColor(color).darker(120).name()
        return f"""
            QPushButton {{
                background-color: {color};
                color: white;
                font-size: 13px;
                font-weight: bold;
                padding: 10px 20px;
                border-radius: 8px;
                border: none;
            }}
            QPushButton:hover {{
                background-color: {hover_color};
            }}
        """
    
    def apply_theme(self):
        """テーマを適用"""
        theme = THEMES.get(self.current_theme, THEMES["ダークモード"])
        
        self.setStyleSheet(f"""
            QMainWindow {{
                background: {theme['background']};
            }}
            QWidget {{
                color: {theme['text_color']};
            }}
        """)
        
        self.button_frame.setStyleSheet(f"""
            QFrame {{
                background-color: {theme['button_frame']};
                border-radius: 20px;
                padding: 20px;
            }}
        """)
        
        # ボタンの表示を更新
        for button in self.buttons:
            button.update_display()
    
    def change_theme(self):
        """テーマを変更"""
        theme_names = list(THEMES.keys())
        current_index = theme_names.index(self.current_theme) if self.current_theme in theme_names else 0
        
        theme, ok = QInputDialog.getItem(
            self,
            "テーマ選択",
            "テーマを選択してください:",
            theme_names,
            current_index,
            False
        )
        
        if ok and theme:
            self.current_theme = theme
            self.apply_theme()
            self.save_config()
            QMessageBox.information(self, "テーマ変更", f"テーマを「{theme}」に変更しました。")
    
    def create_new_cassette(self):
        """新規カセットを作成"""
        dialog = NewCassetteWizard(self.cassettes_dir, self)
        if dialog.exec_() == QDialog.Accepted:
            self.load_cassettes()
            QMessageBox.information(self, "成功", "カセットを作成しました！\n管理者モードでボタンに割り当ててください。")
    
    def toggle_mode(self):
        """モード切り替え"""
        if not self.is_admin_mode:
            password, ok = QInputDialog.getText(
                self,
                "管理者認証",
                "パスワードを入力してください:",
                QLineEdit.Password
            )
            
            if ok and hashlib.sha256(password.encode()).hexdigest() == ADMIN_PASSWORD_HASH:
                self.is_admin_mode = True
                self.mode_button.setText("🔓 ユーザーモード")
                self.mode_button.setStyleSheet(self.get_control_button_style("#27ae60"))
                QMessageBox.information(self, "モード変更", "管理者モードに切り替えました。\n\n機能:\n• ボタンをクリックしてカセット割り当て\n• ボタンをドラッグして位置交換")
            elif ok:
                QMessageBox.warning(self, "エラー", "パスワードが正しくありません。")
        else:
            self.is_admin_mode = False
            self.mode_button.setText("🔒 管理者モード")
            self.mode_button.setStyleSheet(self.get_control_button_style("#e74c3c"))
            QMessageBox.information(self, "モード変更", "ユーザーモードに切り替えました。")
    
    def swap_buttons(self, slot1, slot2):
        """ボタンの位置を交換"""
        button1 = self.buttons[slot1 - 1]
        button2 = self.buttons[slot2 - 1]
        
        # カセットを交換
        temp_cassette = button1.cassette
        button1.set_cassette(button2.cassette)
        button2.set_cassette(temp_cassette)
        
        QMessageBox.information(self, "交換完了", f"スロット {slot1} と スロット {slot2} を交換しました。")
    
    def on_button_clicked(self, button):
        """ボタンクリック時の処理"""
        if self.is_admin_mode:
            if not self.cassettes:
                reply = QMessageBox.question(
                    self,
                    "カセットがありません",
                    "カセットが見つかりません。\n新規カセットを作成しますか？",
                    QMessageBox.Yes | QMessageBox.No
                )
                if reply == QMessageBox.Yes:
                    self.create_new_cassette()
                return
            
            dialog = SlotAssignDialog(button.slot_number, self.cassettes, self)
            if dialog.exec_() == QDialog.Accepted:
                cassette = dialog.get_selected_cassette()
                if cassette:
                    button.set_cassette(cassette)
                else:
                    button.clear_cassette()
                self.load_cassettes()
        else:
            if button.cassette:
                self.execute_script(button.cassette)
            else:
                QMessageBox.information(self, "情報", f"スロット {button.slot_number} にはカセットが割り当てられていません。")
    
    def execute_script(self, cassette):
        """スクリプトを実行"""
        if not cassette.script_path.exists():
            QMessageBox.critical(self, "エラー", f"スクリプトが見つかりません: {cassette.script_path}")
            return
        
        try:
            if cassette.script_path.suffix == '.py':
                subprocess.Popen([sys.executable, str(cassette.script_path)], cwd=str(cassette.folder_path))
            else:
                subprocess.Popen([str(cassette.script_path)], shell=True, cwd=str(cassette.folder_path))
            
            # 実行ログに記録
            self.execution_log.add_log(cassette.name, cassette.folder_path.name)
            
            QMessageBox.information(self, "実行", f"「{cassette.name}」を起動しました！")
        except Exception as e:
            QMessageBox.critical(self, "エラー", f"スクリプトの実行に失敗しました: {str(e)}")
    
    def show_execution_log(self):
        """実行ログを表示"""
        dialog = ExecutionLogDialog(self.execution_log, self)
        dialog.exec_()
    
    def save_configuration(self):
        """設定を保存"""
        dialog = SaveLoadDialog('save', self.saves_dir, self)
        if dialog.exec_() == QDialog.Accepted:
            save_file = dialog.get_selected_file()
            config = []
            for button in self.buttons:
                if button.cassette:
                    config.append({
                        'slot': button.slot_number,
                        'cassette_folder': button.cassette.folder_path.name
                    })
                else:
                    config.append({
                        'slot': button.slot_number,
                        'cassette_folder': None
                    })
            
            try:
                with open(save_file, 'w', encoding='utf-8') as f:
                    json.dump(config, f, indent=2, ensure_ascii=False)
                QMessageBox.information(self, "保存完了", f"設定を保存しました: {save_file.name}")
            except Exception as e:
                QMessageBox.critical(self, "エラー", f"保存に失敗しました: {str(e)}")
    
    def load_configuration(self):
        """設定を読み込み"""
        dialog = SaveLoadDialog('load', self.saves_dir, self)
        if dialog.exec_() == QDialog.Accepted:
            save_file = dialog.get_selected_file()
            self.load_from_file(save_file)
    
    def load_from_file(self, save_file):
        """ファイルから設定を読み込み"""
        try:
            with open(save_file, 'r', encoding='utf-8') as f:
                config = json.load(f)
            
            for button in self.buttons:
                button.clear_cassette()
            
            for item in config:
                slot = item['slot']
                cassette_folder = item.get('cassette_folder')
                
                if cassette_folder and 0 < slot <= 10:
                    cassette = next((c for c in self.cassettes if c.folder_path.name == cassette_folder), None)
                    if cassette:
                        self.buttons[slot - 1].set_cassette(cassette)
            
            QMessageBox.information(self, "読み込み完了", f"設定を読み込みました: {save_file.name}")
        except Exception as e:
            QMessageBox.critical(self, "エラー", f"読み込みに失敗しました: {str(e)}")
    
    def load_last_save(self):
        """最後のセーブを読み込み"""
        last_save = self.saves_dir / "last_save.json"
        if last_save.exists():
            self.load_from_file(last_save)
    
    def show_help(self):
        """ヘルプを表示"""
        dialog = HelpDialog(self.buttons, self)
        dialog.exec_()
    
    def closeEvent(self, event):
        """終了時に自動保存"""
        last_save = self.saves_dir / "last_save.json"
        config = []
        for button in self.buttons:
            if button.cassette:
                config.append({
                    'slot': button.slot_number,
                    'cassette_folder': button.cassette.folder_path.name
                })
            else:
                config.append({
                    'slot': button.slot_number,
                    'cassette_folder': None
                })
        
        try:
            with open(last_save, 'w', encoding='utf-8') as f:
                json.dump(config, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"自動保存エラー: {e}")
        
        event.accept()

def main():
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
PYTHON_EOF

echo "✓ game_script_button.py を更新しました"
echo ""

echo "========================================="
echo "✓ 更新完了！"
echo "========================================="
echo ""
echo "変更内容:"
echo "  • サブフォルダ内のスクリプトファイルに対応"
echo "  • 新規カセット作成時にツリービューでファイル選択"
echo "  • カセット編集時にスクリプトファイルを変更可能"
echo "  • 依存ライブラリチェック機能を強化"
echo ""
echo "アプリケーションを起動:"
echo "  ./run.sh"
echo ""

