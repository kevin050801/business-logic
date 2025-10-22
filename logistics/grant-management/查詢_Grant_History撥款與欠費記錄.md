# 查詢 Grant_History 撥款與欠費記錄

## 說明

`Grant_History` 表記錄了所有的撥款和欠費資訊,包括:
- 正數撥款記錄
- 負數欠費記錄(未結清和已結清)
- 歷史欠費的結清狀態

## Grant_txtName 的三種狀態

| Grant_txtName 格式 | GrantTotalAmount | 意義 |
|-------------------|-----------------|------|
| `D:\Logistic_Grant_txt\YYYY-MM-DDGrantReport.txt` | 正數 | 本次新增的**正數撥款** |
| `D:\Logistic_Grant_txt\YYYY-MM-DDGrantReport[1].txt` | 正數 | 本次新增的**正數撥款**(同天第2次) |
| `YYYY-MM-DDGrantReport.txt` | 負數 | 歷史欠費-**已在該日結清** |
| `YYYY-MM-DDGrantReport[1].txt` | 負數 | 歷史欠費-**已在該日結清**(同天第2次) |
| `''` (空字串) | 負數 | **欠費-尚未結清** |

### 檔名編號說明

當同一天有多次撥款時,系統會自動加上 `[1]`, `[2]` 等編號:
- 第一次撥款: `2025-10-17GrantReport.txt`
- 第二次撥款: `2025-10-17GrantReport[1].txt`
- 第三次撥款: `2025-10-17GrantReport[2].txt`

**常見情況**:
- 先跑 B2C 大宗撥款 → 產生 `2025-10-17GrantReport.txt`
- 再跑 C2C 撥款 → 產生 `2025-10-17GrantReport[1].txt`

---

## 常用查詢 SQL

### 1. 查詢特定商家的所有撥款與欠費記錄

```sql
SELECT
    user_account,
    GrantTotalAmount,
    Grant_txtName,
    Grantdate,
    TotalServicefee,
    Excel_Name,
    grant_type,
    payout_date,
    CASE
        WHEN GrantTotalAmount > 0 AND Grant_txtName LIKE 'D:\%'
            THEN '正數撥款'
        WHEN GrantTotalAmount < 0 AND Grant_txtName LIKE '____-__-__GrantReport%' AND Grant_txtName NOT LIKE 'D:\%'
            THEN '歷史欠費-已結清'
        WHEN GrantTotalAmount < 0 AND Grant_txtName = ''
            THEN '欠費-未結清'
        WHEN GrantTotalAmount = 0
            THEN '歸零記錄(異常)'
        ELSE '其他狀況'
    END AS 記錄類型,
    CASE
        WHEN grant_type = 1 THEN 'C2C撥款'
        WHEN grant_type = 2 THEN 'B2C撥款'
        WHEN grant_type = 3 THEN '全家冷凍'
        WHEN grant_type = 4 THEN '黑貓宅配'
        ELSE '未知類型'
    END AS 撥款類型
FROM Grant_History
WHERE user_account = '商家帳號'
ORDER BY Grantdate DESC, GrantTotalAmount DESC;
```

---

### 2. 查詢特定日期的所有撥款記錄

```sql
-- 查詢 2025-10-17 的所有撥款記錄
SELECT
    user_account,
    GrantTotalAmount,
    Grant_txtName,
    TotalServicefee,
    grant_type,
    COUNT(*) OVER (PARTITION BY user_account) AS 該商家記錄數
FROM Grant_History
WHERE Grant_txtName LIKE '%2025-10-17%'
ORDER BY user_account, GrantTotalAmount DESC;
```

---

### 3. 查詢特定日期撥款的統計資訊

```sql
-- 統計 2025-10-17 的撥款狀況
SELECT
    Grant_txtName,
    grant_type,
    CASE
        WHEN grant_type = 1 THEN 'C2C撥款'
        WHEN grant_type = 2 THEN 'B2C撥款'
        WHEN grant_type = 3 THEN '全家冷凍'
        WHEN grant_type = 4 THEN '黑貓宅配'
        ELSE '未知'
    END AS 撥款類型,
    COUNT(*) AS 記錄筆數,
    SUM(CASE WHEN GrantTotalAmount > 0 THEN 1 ELSE 0 END) AS 正數筆數,
    SUM(CASE WHEN GrantTotalAmount < 0 THEN 1 ELSE 0 END) AS 負數筆數,
    SUM(GrantTotalAmount) AS 撥款總額,
    SUM(TotalServicefee) AS 服務費總額
FROM Grant_History
WHERE Grant_txtName LIKE '%2025-10-17%'
GROUP BY Grant_txtName, grant_type
ORDER BY Grant_txtName;
```

---

### 4. 查詢所有尚未結清的欠費

```sql
-- 查詢所有未結清欠費
SELECT
    user_account,
    GrantTotalAmount AS 欠費金額,
    Grantdate AS 欠費發生日期,
    TotalServicefee AS 服務費,
    Excel_Name,
    DATEDIFF(DAY, Grantdate, GETDATE()) AS 欠費天數
FROM Grant_History
WHERE Grant_txtName = ''  -- 空字串代表未結清
AND GrantTotalAmount < 0
ORDER BY Grantdate ASC;
```

---

### 5. 查詢特定日期被結清的歷史欠費

```sql
-- 查詢在 2025-10-17 被結清的歷史欠費
SELECT
    user_account,
    GrantTotalAmount AS 欠費金額,
    Grantdate AS 原始欠費日期,
    Grant_txtName AS 結清於哪次撥款,
    DATEDIFF(DAY, Grantdate, '2025-10-17') AS 欠費天數
FROM Grant_History
WHERE (Grant_txtName = '2025-10-17GrantReport.txt'
       OR Grant_txtName = '2025-10-17GrantReport[1].txt')
AND GrantTotalAmount < 0
ORDER BY user_account, Grantdate;
```

---

### 6. 查詢商家的欠費結清歷史

```sql
-- 查詢商家的所有欠費(包含已結清和未結清)
SELECT
    user_account,
    GrantTotalAmount AS 欠費金額,
    Grantdate AS 欠費發生日期,
    Grant_txtName,
    CASE
        WHEN Grant_txtName = '' THEN '未結清'
        ELSE '已結清於: ' + Grant_txtName
    END AS 結清狀態
FROM Grant_History
WHERE user_account = '商家帳號'
AND GrantTotalAmount < 0
ORDER BY Grantdate DESC;
```

---

### 7. 綜合查詢:商家的撥款與欠費對帳

```sql
-- 商家的完整對帳資訊
WITH 撥款記錄 AS (
    SELECT
        user_account,
        SUM(CASE WHEN GrantTotalAmount > 0 THEN GrantTotalAmount ELSE 0 END) AS 累計撥款,
        SUM(CASE WHEN GrantTotalAmount < 0 AND Grant_txtName != '' THEN ABS(GrantTotalAmount) ELSE 0 END) AS 累計結清欠費,
        SUM(CASE WHEN GrantTotalAmount < 0 AND Grant_txtName = '' THEN GrantTotalAmount ELSE 0 END) AS 未結清欠費,
        COUNT(CASE WHEN GrantTotalAmount > 0 THEN 1 END) AS 撥款次數,
        COUNT(CASE WHEN GrantTotalAmount < 0 THEN 1 END) AS 欠費次數
    FROM Grant_History
    WHERE user_account = '商家帳號'
    GROUP BY user_account
)

SELECT
    user_account,
    累計撥款,
    累計結清欠費,
    未結清欠費,
    累計撥款 - 累計結清欠費 AS 實際撥款淨額,
    撥款次數,
    欠費次數
FROM 撥款記錄;
```

---

### 8. 查詢異常記錄(供除錯用)

```sql
-- 查詢可能的異常記錄
SELECT
    user_account,
    GrantTotalAmount,
    Grant_txtName,
    Grantdate,
    CASE
        WHEN GrantTotalAmount = 0 THEN '❌ 異常:金額為0'
        WHEN GrantTotalAmount > 0 AND Grant_txtName = '' THEN '❌ 異常:正數但txtName為空'
        WHEN GrantTotalAmount > 0 AND Grant_txtName NOT LIKE 'D:\%' THEN '❌ 異常:正數但txtName格式錯誤'
        WHEN GrantTotalAmount < 0 AND Grant_txtName LIKE 'D:\%' THEN '❌ 異常:負數但txtName是完整路徑'
        ELSE '正常'
    END AS 異常診斷
FROM Grant_History
WHERE Grantdate >= '2025-01-01'  -- 限定查詢範圍
AND (
    GrantTotalAmount = 0
    OR (GrantTotalAmount > 0 AND Grant_txtName = '')
    OR (GrantTotalAmount > 0 AND Grant_txtName NOT LIKE 'D:\%')
    OR (GrantTotalAmount < 0 AND Grant_txtName LIKE 'D:\%')
)
ORDER BY Grantdate DESC;
```

---

## 重要欄位說明

| 欄位名稱 | 型別 | 說明 |
|---------|------|------|
| `user_account` | VARCHAR | 商家帳號 |
| `sonid` | INT | 分店編號(可能沒有此欄位) |
| `bank_account` | VARCHAR | 銀行帳號 |
| `bank_code` | VARCHAR | 銀行代碼 |
| `bank_branch_code` | VARCHAR | 分行代碼 |
| `account_name` | NVARCHAR | 戶名 |
| `bankname` | NVARCHAR | 銀行名稱 |
| `GrantTotalAmount` | INT | 撥款/欠費金額(正數=撥款,負數=欠費) |
| `Excel_Name` | NVARCHAR | Excel檔案路徑 |
| `Grant_txtName` | NVARCHAR | ACH撥款檔案名稱(判斷結清狀態的關鍵欄位) |
| `Grantdate` | DATE | 撥款日期或欠費發生日期 |
| `TotalServicefee` | INT | 服務費總額 |
| `BulkGrantTotalAmount` | INT | 大宗撥款金額 |
| `SettledAmount` | INT | 已結算金額 |
| `grant_type` | INT | 撥款類型(1=C2C, 2=B2C, 3=全家冷凍, 4=黑貓) |
| `payout_date` | DATE | 實際撥款日期 |

---

## 使用時機

### 查詢 1-3
適用於**日常對帳**,查看商家的撥款記錄和統計資訊

### 查詢 4-6
適用於**欠費管理**,追蹤未結清欠費和結清歷史

### 查詢 7
適用於**月結對帳**,產生商家的完整對帳報表

### 查詢 8
適用於**系統除錯**,發現資料異常

---

## 注意事項

1. ✅ `Grant_txtName` 是判斷欠費是否結清的**關鍵欄位**
2. ✅ 同一天可能有多次撥款,檔名會有 `[1]`, `[2]` 等編號
3. ✅ 正數記錄的 `Grant_txtName` 是**完整路徑** (`D:\Logistic_Grant_txt\...`)
4. ✅ 負數記錄的 `Grant_txtName` 是**檔名** (無路徑) 或**空字串**
5. ⚠️ 不要用 `payout_date` 判斷欠費是否結清,要用 `Grant_txtName`
6. ⚠️ `GrantTotalAmount = 0` 的記錄理論上不應該存在
