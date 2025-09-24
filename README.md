# PayNow 業務邏輯規則庫

## 專案概述
此 repository 收集並整理 PayNow 系統中的業務邏輯規則與資料流程分析。

## 資料夾結構
```
business-logic/
├── logistics/              # 物流系統相關
│   ├── grant-management/    # 撥款管理
│   │   └── Grant_History_account_name_規則.md
│   └── README.md
└── README.md
```

## 系統模組

### 物流系統 (Logistics)
- **路徑**: `logistics/`
- **內容**: 物流相關的業務邏輯規則
- **子模組**: 撥款管理、訂單管理、物流服務商整合等

#### 撥款管理
- **Grant_History account_name 規則**: 撥款歷史紀錄中帳戶名稱的來源與處理邏輯

## 維護說明
本庫持續更新中，按系統模組分類記錄業務邏輯的分析結果。每個模組都有獨立的 README 文件說明其內容結構。