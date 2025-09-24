# Grant_History account_name 業務邏輯規則

## 概述
本文件說明 PayNow 物流系統中 Grant_History 資料表 account_name 欄位的來源與業務邏輯。

## 資料流程

### 1. 資料來源
- **來源資料表**: `Branch_Member`
- **來源欄位**: `account_name`
- **用途**: 分店會員的銀行帳戶戶名

### 2. 處理流程

#### Step 1: 資料查詢
```csharp
// OrderController.cs 第120行
IOrderedEnumerable<Branch_Member> Branch_Memberlist = db.Branch_Member.ToList()
    .OrderBy(c => c.user_account)
    .ThenBy(c => c.bank_code)
    .ThenBy(c => c.bank_branch_code)
    .ThenBy(c => c.bank_account);
```

#### Step 2: 變數賦值
```csharp
// OrderController.cs 第251行
account_name = brenchmember.account_name;
```

#### Step 3: 物件建立
```csharp
// OrderController.cs 第211行
obj_grant_result.account_name = account_name;
```

#### Step 4: 資料庫寫入
```csharp
// Cls_Order.cs Add_Grant_History方法
string sqlstr = "insert into Grant_History([account_name], ...) Values(@account_name, ...)";
```

## 業務規則

### 核心規則
1. `Grant_History.account_name` **直接對應** `Branch_Member.account_name`
2. 代表該筆撥款紀錄的銀行帳戶戶名
3. 用於撥款報表與對帳作業

### 資料完整性
- account_name 必須與 Branch_Member 中的資料保持同步
- 撥款時會複製當下的 account_name 值作為歷史紀錄
- 確保撥款紀錄的完整性與可追蹤性

## 相關程式碼位置

### 主要檔案
- **OrderController.cs**: `Grant_AndB2CReport` 方法 (第46行開始)
- **Cls_Order.cs**: `Add_Grant_History` 方法 (第6458行開始)
- **Branch_Member.cs**: 實體定義 (第33行)

### 關鍵程式碼段
```csharp
// 1. 從Branch_Member取得account_name
account_name = brenchmember.account_name;  // 第251行

// 2. 設定到Grant結果物件
obj_grant_result.account_name = account_name;  // 第211行

// 3. 寫入Grant_History資料表
sqlstr = "insert into Grant_History([account_name], ...) Values(@account_name, ...)";
```

## 注意事項

### 資料一致性
- Branch_Member 的 account_name 異動不會影響已存在的 Grant_History 紀錄
- 每次撥款作業會產生當時的帳戶名稱快照

### 業務影響
- 用於撥款憑證產生
- 銀行對帳作業的重要依據
- 財務稽核追蹤的關鍵資料

## 更新紀錄
- **建立日期**: 2025-09-24
- **分析來源**: PayNowLogistics OrderController.cs Grant_AndB2CReport 方法