# この部分は既存のコードの一部として挿入されます
# NewCassetteWizardクラスのsetup_uiメソッドを修正

class NewCassetteWizard(QDialog):
    """新規カセット作成ウィザード"""
    def __init__(self, cassettes_dir, parent=None):
        super().__init__(parent)
        self.cassettes_dir = cassettes_dir
        self.source_folder = None
        self.script_file = None
        self.setWindowTitle("新規カセット作成")
        self.setMinimumSize(750, 700)
        self.resize(750, 700)
        self.setup_ui()
    
    def setup_ui(self):
        """UIのセットアップ"""
        main_layout = QVBoxLayout()
        main_layout.setSpacing(10)
        main_layout.setContentsMargins(15, 15, 15, 15)
        
        # タイトル
        title = QLabel("🎮 新規カセット作成ウィザード")
        title.setStyleSheet("font-size: 18px; font-weight: bold; color: white; padding: 8px;")
        title.setAlignment(Qt.AlignCenter)
        main_layout.addWidget(title)
        
        # スクロールエリア
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        scroll.setStyleSheet("""
            QScrollArea {
                background-color: transparent;
                border: none;
            }
        """)
        
        # スクロール内のコンテンツウィジェット
        content_widget = QWidget()
        layout = QVBoxLayout()
        layout.setSpacing(12)
        
        # ステップ1: フォルダ選択
        step1_frame = QFrame()
        step1_frame.setStyleSheet("QFrame { background-color: #34495e; border-radius: 8px; padding: 12px; }")
        step1_layout = QVBoxLayout()
        
        step1_label = QLabel("ステップ 1: アプリフォルダを選択")
        step1_label.setStyleSheet("font-weight: bold; font-size: 13px; color: white;")
        step1_layout.addWidget(step1_label)
        
        folder_layout = QHBoxLayout()
        self.folder_input = QLineEdit()
        self.folder_input.setPlaceholderText("フォルダを選択してください")
        self.folder_input.setReadOnly(True)
        self.folder_input.setMinimumHeight(30)
        folder_layout.addWidget(self.folder_input)
        
        folder_btn = QPushButton("📁 参照")
        folder_btn.setMinimumHeight(30)
        folder_btn.setMaximumWidth(100)
        folder_btn.clicked.connect(self.select_folder)
        folder_layout.addWidget(folder_btn)
        step1_layout.addLayout(folder_layout)
        
        step1_frame.setLayout(step1_layout)
        layout.addWidget(step1_frame)
        
        # ステップ2: スクリプト選択
        step2_frame = QFrame()
        step2_frame.setStyleSheet("QFrame { background-color: #34495e; border-radius: 8px; padding: 12px; }")
        step2_layout = QVBoxLayout()
        
        step2_label = QLabel("ステップ 2: 実行ファイルを選択")
        step2_label.setStyleSheet("font-weight: bold; font-size: 13px; color: white;")
        step2_layout.addWidget(step2_label)
        
        script_select_layout = QHBoxLayout()
        self.script_input = QLineEdit()
        self.script_input.setPlaceholderText("実行ファイルを選択してください")
        self.script_input.setReadOnly(True)
        self.script_input.setMinimumHeight(30)
        script_select_layout.addWidget(self.script_input)
        
        self.script_browse_btn = QPushButton("🔍 選択")
        self.script_browse_btn.setEnabled(False)
        self.script_browse_btn.setMinimumHeight(30)
        self.script_browse_btn.setMaximumWidth(100)
        self.script_browse_btn.clicked.connect(self.select_script)
        script_select_layout.addWidget(self.script_browse_btn)
        step2_layout.addLayout(script_select_layout)
        
        # 依存関係チェック結果
        self.dependency_text = QTextEdit()
        self.dependency_text.setReadOnly(True)
        self.dependency_text.setMaximumHeight(90)
        self.dependency_text.setPlaceholderText("Pythonスクリプトの依存ライブラリ情報")
        step2_layout.addWidget(self.dependency_text)
        
        step2_frame.setLayout(step2_layout)
        layout.addWidget(step2_frame)
        
        # ステップ3: カセット情報
        step3_frame = QFrame()
        step3_frame.setStyleSheet("QFrame { background-color: #34495e; border-radius: 8px; padding: 12px; }")
        step3_layout = QVBoxLayout()
        
        step3_label = QLabel("ステップ 3: カセット情報を入力")
        step3_label.setStyleSheet("font-weight: bold; font-size: 13px; color: white;")
        step3_layout.addWidget(step3_label)
        
        # タイトル
        title_layout = QHBoxLayout()
        title_lbl = QLabel("タイトル:")
        title_lbl.setMinimumWidth(70)
        title_layout.addWidget(title_lbl)
        self.title_input = QLineEdit()
        self.title_input.setPlaceholderText("カセット名を入力")
        self.title_input.setMinimumHeight(30)
        title_layout.addWidget(self.title_input)
        step3_layout.addLayout(title_layout)
        
        # アイコン
        icon_layout = QHBoxLayout()
        icon_lbl = QLabel("アイコン:")
        icon_lbl.setMinimumWidth(70)
        icon_layout.addWidget(icon_lbl)
        self.icon_input = QLineEdit()
        self.icon_input.setPlaceholderText("画像ファイル（オプション）")
        self.icon_input.setMinimumHeight(30)
        icon_layout.addWidget(self.icon_input)
        
        icon_btn = QPushButton("🖼️")
        icon_btn.setMaximumWidth(50)
        icon_btn.setMinimumHeight(30)
        icon_btn.clicked.connect(self.select_icon)
        icon_layout.addWidget(icon_btn)
        step3_layout.addLayout(icon_layout)
        
        # 背景色
        color_layout = QHBoxLayout()
        color_lbl = QLabel("背景色:")
        color_lbl.setMinimumWidth(70)
        color_layout.addWidget(color_lbl)
        self.color_button = QPushButton()
        self.color_button.setFixedSize(80, 30)
        self.current_color = "#4CAF50"
        self.color_button.setStyleSheet(f"background-color: {self.current_color};")
        self.color_button.clicked.connect(self.choose_color)
        color_layout.addWidget(self.color_button)
        color_layout.addStretch()
        step3_layout.addLayout(color_layout)
        
        # 説明
        desc_lbl = QLabel("説明:")
        step3_layout.addWidget(desc_lbl)
        self.description_input = QTextEdit()
        self.description_input.setPlaceholderText("カセットの説明を入力")
        self.description_input.setMaximumHeight(70)
        step3_layout.addWidget(self.description_input)
        
        # タグ
        tag_layout = QHBoxLayout()
        tag_lbl = QLabel("タグ:")
        tag_lbl.setMinimumWidth(70)
        tag_layout.addWidget(tag_lbl)
        self.tag_input = QLineEdit()
        self.tag_input.setPlaceholderText("カンマ区切り（例: 仕事,ツール）")
        self.tag_input.setMinimumHeight(30)
        tag_layout.addWidget(self.tag_input)
        step3_layout.addLayout(tag_layout)
        
        # お気に入り
        self.favorite_check = QCheckBox("⭐ お気に入りに追加")
        step3_layout.addWidget(self.favorite_check)
        
        step3_frame.setLayout(step3_layout)
        layout.addWidget(step3_frame)
        
        content_widget.setLayout(layout)
        scroll.setWidget(content_widget)
        main_layout.addWidget(scroll)
        
        # ボタン
        button_layout = QHBoxLayout()
        create_btn = QPushButton("✨ カセット作成")
        create_btn.clicked.connect(self.create_cassette)
        create_btn.setMinimumHeight(40)
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
        cancel_btn.setMinimumHeight(40)
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
        main_layout.addLayout(button_layout)
        
        self.setLayout(main_layout)
        self.setStyleSheet("QDialog { background-color: #2c3e50; } QLabel { color: white; }")
