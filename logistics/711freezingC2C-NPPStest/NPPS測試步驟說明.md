# 7-11 冷凍C2C NPPS 測試步驟說明

## 測試目的
建立完整的 7-11 冷凍 C2C 訂單測試資料，用於 NPPS 貨態檔案處理功能測試。

## 測試資料概述
- **測試訂單數量**: 46 筆
- **LogisticNumber 範圍**: TEST001 ~ TEST046
- **測試帳號**: 28229955
- **訂單日期**: 2025-10-08 ~ 2025-10-09
- **物流服務**: 21 (7-11 冷凍 C2C)

## 資料庫準備步驟

### 步驟 1: 插入主訂單資料 (Order_Info)
**檔案**: `batch_insert.sql`

**執行內容**:
- 插入 46 筆主訂單到 `Order_Info` 資料表
- 每筆訂單包含完整必要欄位，避免程式執行時發生錯誤

**關鍵欄位說明**:
```sql
LogisticNumber  -- 測試用物流單號 (TEST001~TEST046)
paymentno       -- 付款單號 (對應實際訂單編號)
Logistic_service -- 21 (7-11冷凍C2C)
user_account    -- 28229955 (測試帳號)
sonid           -- 001 (子帳號)
Status          -- 1 (訂單狀態)
DeliverMode     -- 1 (配送模式)
TotalAmount     -- 0 (測試用金額)
Deadline        -- 7 (期限天數)
IsPrinted       -- 1 (已列印)
IsShipping      -- 1 (配送中)
```

**重要提醒**:
> ⚠️ `Deadline`, `IsPrinted`, `IsShipping`, `sonid`, `TotalAmount` 必須設值，否則程式會掛掉

**驗證方式**:
```sql
SELECT COUNT(*) as inserted_count
FROM Order_Info
WHERE LogisticNumber LIKE 'TEST%';
-- 應該返回 46 筆
```

---

### 步驟 2: 插入對帳資料 (Order_Accounting)
**檔案**: `insert_accounting_data.sql`

**執行內容**:
- 從 `Order_Info` 讀取已插入的測試訂單
- 批次插入 46 筆對帳資料到 `Order_Accounting`

**關鍵欄位說明**:
```sql
Checkoutable  -- 0 (預設未對帳)
Service_fee   -- 0 (預設服務費為0)
```

**SQL 邏輯**:
```sql
INSERT INTO Order_Accounting (...)
SELECT
    LogisticNumber, sno, paymentno, user_account, sonid,
    Logistic_service, DeliverMode, TotalAmount,
    0 AS Checkoutable,  -- 預設未對帳
    0 AS Service_fee     -- 預設服務費為0
FROM Order_Info
WHERE LogisticNumber LIKE 'TEST%'
ORDER BY LogisticNumber;
```

**驗證方式**:
```sql
-- 驗證插入筆數
SELECT COUNT(*) as inserted_count
FROM Order_Accounting
WHERE LogisticNumber LIKE 'TEST%';

-- 顯示前5筆確認資料正確
SELECT TOP 5
    LogisticNumber, sno, paymentno, user_account,
    Logistic_service, Checkoutable, Service_fee
FROM Order_Accounting
WHERE LogisticNumber LIKE 'TEST%'
ORDER BY LogisticNumber;
```

---

### 步驟 3: 插入子訂單資料 (711FreezingC2COrder)
**檔案**: `insert_child_orders.sql`

**執行內容**:
- 從 `Order_Info` 讀取測試訂單
- 建立對應的 7-11 冷凍 C2C 子訂單

**關鍵欄位說明**:
```sql
service_type        -- 1 (服務類型)
showtype            -- 0 (顯示類型)
receiver_storestatus -- 0 (收件門市狀態)
return_storestatus  -- 0 (退貨門市狀態)
Id                  -- ROW_NUMBER() 自動編號
```

**SQL 邏輯**:
```sql
INSERT INTO [711FreezingC2COrder] (...)
SELECT
    LogisticNumber, '', user_account, '', sonid,
    '1', 0, 0, '', CAST(Deadline AS NCHAR(10)),
    0, '', '', '', '', receiver_storeid, receiver_storeid,
    '0', 0, paymentno, '', '0', '0', '', '',
    OrderDate, ROW_NUMBER() OVER (ORDER BY LogisticNumber)
FROM Order_Info
WHERE LogisticNumber LIKE 'TEST%';
```

**驗證方式**:
```sql
SELECT COUNT(*) as child_order_count
FROM [711FreezingC2COrder]
WHERE LogisticNumber LIKE 'TEST%';
-- 應該返回 46 筆
```

---

## NPPS 貨態檔案說明

### 檔案資訊
**檔案名稱**: `72E202510090606.NPPS`

**檔案格式**: NPPS 標準貨態格式
- 第1行: Header (記錄類型, 日期, 筆數)
- 第2行起: 貨態明細記錄

### Header 格式說明
```
1,20251009,0000051
```
- `1`: 記錄類型 (Header)
- `20251009`: 檔案日期 (YYYYMMDD)
- `0000051`: 總筆數 (含Header共51筆，明細50筆)

### 貨態明細格式說明
```
2,3,31,72E,001,H9898126,1,72G,001,72G4475873L,255767,布蘭其,20251008,052146,PPS202,交貨便收件,
```

**欄位對應**:
1. `2`: 記錄類型 (Detail)
2. `3`: 資料類型
3. `31/32`: 貨態代碼
   - `31`: 交貨便收件 (PPS202)
   - `32`: 門市配達 (PPS101)
4. `72E/72F`: 寄件門市代碼
   - `72E`: 一般訂單
   - `72F`: 特定類型訂單
5. `001`: 門市子編號
6. `H9898126`: **paymentno (付款單號)** - 用於對應測試資料
7. `1/3`: 服務類型
8. `72G`: 收件門市代碼
9. `001`: 收件門市子編號
10. `72G4475873L`: 物流追蹤號碼
11. `255767`: 收件門市ID (receiver_storeid)
12. `布蘭其`: 收件門市名稱
13. `20251008`: 處理日期
14. `052146`: 處理時間
15. `PPS202/PPS101`: 貨態狀態碼
    - `PPS202`: 交貨便收件
    - `PPS101`: 門市配達
16. `交貨便收件/門市配達`: 貨態描述

### 貨態類型統計
根據 `72E202510090606.NPPS` 內容：

**72E 訂單** (service_type = 1):
- PPS202 (交貨便收件): 25 筆
- PPS101 (門市配達): 4 筆

**72F 訂單** (service_type = 3):
- PPS202 (交貨便收件): 19 筆
- PPS101 (門市配達): 2 筆

**特殊情況**:
- `H9872364`: 無物流追蹤號碼 (測試異常處理)

### 測試資料對應關係
NPPS 檔案中的 `paymentno` 欄位對應到資料庫中的測試訂單：

| paymentno | LogisticNumber | 貨態狀態 | 門市 |
|-----------|----------------|----------|------|
| H9898126 | TEST001 | PPS202 | 布蘭其(255767) |
| H9899162 | TEST002 | PPS202 | 九容(236364) |
| H9899165 | TEST003 | PPS202→PPS101 | 九容→巨新 |
| ... | ... | ... | ... |

---

## 完整測試執行順序

### 1. 資料庫準備
```sql
-- 步驟 1: 清理舊測試資料 (可選)
DELETE FROM [711FreezingC2COrder] WHERE LogisticNumber LIKE 'TEST%';
DELETE FROM Order_Accounting WHERE LogisticNumber LIKE 'TEST%';
DELETE FROM Order_Info WHERE LogisticNumber LIKE 'TEST%';

-- 步驟 2: 執行主訂單插入
-- 執行 batch_insert.sql

-- 步驟 3: 執行對帳資料插入
-- 執行 insert_accounting_data.sql

-- 步驟 4: 執行子訂單插入
-- 執行 insert_child_orders.sql
```

### 2. NPPS 檔案處理測試
1. 將 `72E202510090606.NPPS` 放到系統指定的 NPPS 檔案讀取目錄
2. 觸發 NPPS 檔案處理排程或手動執行處理程序
3. 系統應該會：
   - 讀取 NPPS 檔案
   - 根據 `paymentno` 比對訂單
   - 更新訂單貨態狀態
   - 記錄物流追蹤號碼

### 3. 驗證測試結果
```sql
-- 檢查訂單狀態更新
SELECT
    oi.LogisticNumber,
    oi.paymentno,
    oi.Status,
    fc.LogisticNumber AS ChildLogisticNumber,
    fc.receiver_storestatus
FROM Order_Info oi
LEFT JOIN [711FreezingC2COrder] fc ON oi.LogisticNumber = fc.LogisticNumber
WHERE oi.LogisticNumber LIKE 'TEST%'
ORDER BY oi.LogisticNumber;

-- 檢查是否有未更新的訂單
SELECT COUNT(*) as pending_orders
FROM Order_Info
WHERE LogisticNumber LIKE 'TEST%'
AND Status = '1';  -- 假設狀態1為待處理
```

---

## 測試重點檢查項目

### ✅ 資料完整性檢查
- [ ] 46 筆主訂單全部插入成功
- [ ] 46 筆對帳資料全部插入成功
- [ ] 46 筆子訂單全部插入成功
- [ ] 所有必要欄位都有正確的值

### ✅ NPPS 檔案處理檢查
- [ ] NPPS 檔案讀取成功
- [ ] paymentno 比對成功
- [ ] 貨態狀態正確更新
- [ ] 物流追蹤號碼正確記錄
- [ ] PPS202 (交貨便收件) 狀態處理正確
- [ ] PPS101 (門市配達) 狀態處理正確
- [ ] 異常資料 (無追蹤號) 處理正確

### ✅ 業務邏輯檢查
- [ ] 同一訂單多筆貨態更新處理正確
- [ ] 門市配達狀態轉換正確
- [ ] 收件門市資訊更新正確

---

## 常見問題處理

### Q1: 執行 SQL 後筆數不對？
**檢查項目**:
1. 確認資料庫連線正確
2. 檢查是否有舊測試資料殘留
3. 查看 SQL 執行錯誤訊息

### Q2: NPPS 檔案無法處理？
**檢查項目**:
1. 檔案編碼是否正確 (UTF-8 或 Big5)
2. 檔案格式是否符合 NPPS 標準
3. 檔案放置路徑是否正確
4. 檢查系統 log 是否有錯誤訊息

### Q3: paymentno 比對失敗？
**檢查項目**:
1. 確認資料庫中 paymentno 與 NPPS 檔案是否一致
2. 檢查是否有空白或特殊字元
3. 確認大小寫是否匹配

---

## 附註

### 測試資料特性
- 所有訂單使用相同測試帳號 (28229955)
- 主要收件門市: 九容 (236364)
- 其他門市: 布蘭其、輔進、華文、一中等
- 涵蓋 72E 和 72F 兩種訂單類型
- 包含正常流程和異常情況測試

### 清理測試資料
測試完成後，可使用以下 SQL 清理測試資料：
```sql
DELETE FROM [711FreezingC2COrder] WHERE LogisticNumber LIKE 'TEST%';
DELETE FROM Order_Accounting WHERE LogisticNumber LIKE 'TEST%';
DELETE FROM Order_Info WHERE LogisticNumber LIKE 'TEST%';
```

---

**文件版本**: 1.0
**建立日期**: 2025-10-15
**適用系統**: PayNowLogistics - 7-11 冷凍 C2C 物流系統
