# SQL 對比與修正 - 誤撥商家查詢

## 你的原始 SQL

```sql
select *,TotalAmount-Service_fee-m as d from(
    select user_account,
           sum(TotalAmount) TotalAmount,
           sum(Service_fee) Service_fee,
           (
               select sum(TotalAmount)
               from Order_Info
               where LogisticNumber in (
                   select LogisticNumber
                   from Order_Accounting
                   where GrantdaisouDate > '2025/10/15 00:00:00'
               )
               and Detail_Status_Description != '買家已取件'
               and Detail_Status_Description != '消費者成功取件'
               and user_account=Order_Accounting.user_account
           ) as m
    from Order_Accounting
    where GrantdaisouDate > '2025/10/15 00:00:00'
    and user_account in (
        '92653668', '96771271', '54895238', '90438307',
        '98648853', '85238336', '90081094', '27545589',
        '82379115', '83614969', '93192566', '22607683',
        '24584898', '41327634'
    )
    group by user_account
) a
order by d
```

## 關鍵差異點分析

### 差異 1: Order_Info vs Order_Accounting

**你的 SQL**:
```sql
select sum(TotalAmount)
from Order_Info  -- ← 從 Order_Info 抓 TotalAmount
where LogisticNumber in (...)
```

**我的 SQL**:
```sql
SELECT ISNULL(SUM(oi2.TotalAmount), 0)
FROM Order_Accounting oa2  -- ← 從 Order_Accounting 抓
INNER JOIN Order_Info oi2
    ON oa2.LogisticNumber = oi2.LogisticNumber
```

**問題**:
- `Order_Info.TotalAmount` 和 `Order_Accounting.TotalAmount` **可能不一樣**
- 你的查詢是用 `Order_Info.TotalAmount`
- 外層查詢是用 `Order_Accounting` 的 `sum(TotalAmount)`
- 這會造成分子分母不一致!

### 差異 2: sonid 的處理

**你的 SQL**:
- 沒有考慮 `sonid` (分店編號)
- 只用 `user_account` 分組

**實際狀況**:
- 同一個 `user_account` 可能有多個 `sonid`
- `Grant_History` 是用 `user_account + sonid` 來識別商家

---

## 🔧 修正後的 SQL (完全對應你的邏輯)

```sql
-- ========================================
-- 修正版:完全對應你的查詢邏輯
-- ========================================
SELECT
    user_account,
    TotalAmount,
    Service_fee,
    m AS AbnormalAmount,
    (TotalAmount - Service_fee - m) AS d
FROM (
    SELECT
        user_account,
        SUM(TotalAmount) AS TotalAmount,
        SUM(Service_fee) AS Service_fee,
        -- 修正:從 Order_Accounting + Order_Info JOIN 來抓異常金額
        (
            SELECT ISNULL(SUM(oa2.TotalAmount), 0)
            FROM Order_Accounting oa2
            INNER JOIN Order_Info oi2
                ON oa2.LogisticNumber = oi2.LogisticNumber
                AND oa2.sno = oi2.sno
            WHERE oa2.GrantdaisouDate > '2025/10/15 00:00:00'
                AND oa2.user_account = Order_Accounting.user_account
                AND oi2.Detail_Status_Description != '買家已取件'
                AND oi2.Detail_Status_Description != '消費者成功取件'
        ) AS m
    FROM Order_Accounting
    WHERE GrantdaisouDate > '2025/10/15 00:00:00'
        AND user_account IN (
            '92653668', '96771271', '54895238', '90438307',
            '98648853', '85238336', '90081094', '27545589',
            '82379115', '83614969', '93192566', '22607683',
            '24584898', '41327634'
        )
    GROUP BY user_account
) a
ORDER BY d;
```

---

## 🔍 驗證查詢 - 找出差異原因

### 1. 檢查 Order_Info vs Order_Accounting 的 TotalAmount 差異

```sql
-- ========================================
-- 檢查兩個表的 TotalAmount 是否一致
-- ========================================
SELECT
    oa.LogisticNumber,
    oa.sno,
    oa.user_account,
    oa.TotalAmount AS OA_TotalAmount,
    oi.TotalAmount AS OI_TotalAmount,
    CASE
        WHEN oa.TotalAmount = oi.TotalAmount THEN '一致'
        ELSE '不一致'
    END AS 比對結果
FROM Order_Accounting oa
INNER JOIN Order_Info oi
    ON oa.LogisticNumber = oi.LogisticNumber
    AND oa.sno = oi.sno
WHERE oa.GrantdaisouDate > '2025/10/15 00:00:00'
    AND oa.user_account IN (
        '92653668', '96771271', '54895238', '90438307',
        '98648853', '85238336', '90081094', '27545589',
        '82379115', '83614969', '93192566', '22607683',
        '24584898', '41327634'
    )
    AND oa.TotalAmount != oi.TotalAmount;  -- 只看不一致的
```

### 2. 檢查是否有 sonid 的問題

```sql
-- ========================================
-- 檢查同一 user_account 是否有多個 sonid
-- ========================================
SELECT
    user_account,
    COUNT(DISTINCT sonid) AS sonid_count,
    STRING_AGG(DISTINCT sonid, ',') AS sonid_list
FROM Order_Accounting
WHERE GrantdaisouDate > '2025/10/15 00:00:00'
    AND user_account IN (
        '92653668', '96771271', '54895238', '90438307',
        '98648853', '85238336', '90081094', '27545589',
        '82379115', '83614969', '93192566', '22607683',
        '24584898', '41327634'
    )
GROUP BY user_account
HAVING COUNT(DISTINCT sonid) > 1;
```

### 3. 完整對比查詢

```sql
-- ========================================
-- 完整對比:你的 SQL vs 修正後的 SQL
-- ========================================
-- 你的原始邏輯
WITH YourQuery AS (
    SELECT
        user_account,
        SUM(TotalAmount) AS TotalAmount,
        SUM(Service_fee) AS Service_fee,
        (
            SELECT SUM(TotalAmount)
            FROM Order_Info
            WHERE LogisticNumber IN (
                SELECT LogisticNumber
                FROM Order_Accounting
                WHERE GrantdaisouDate > '2025/10/15 00:00:00'
            )
            AND Detail_Status_Description != '買家已取件'
            AND Detail_Status_Description != '消費者成功取件'
            AND user_account = Order_Accounting.user_account
        ) AS m
    FROM Order_Accounting
    WHERE GrantdaisouDate > '2025/10/15 00:00:00'
        AND user_account IN (
            '92653668', '96771271', '54895238', '90438307',
            '98648853', '85238336', '90081094', '27545589',
            '82379115', '83614969', '93192566', '22607683',
            '24584898', '41327634'
        )
    GROUP BY user_account
),
-- 修正後的邏輯
FixedQuery AS (
    SELECT
        user_account,
        SUM(TotalAmount) AS TotalAmount,
        SUM(Service_fee) AS Service_fee,
        (
            SELECT ISNULL(SUM(oa2.TotalAmount), 0)
            FROM Order_Accounting oa2
            INNER JOIN Order_Info oi2
                ON oa2.LogisticNumber = oi2.LogisticNumber
                AND oa2.sno = oi2.sno
            WHERE oa2.GrantdaisouDate > '2025/10/15 00:00:00'
                AND oa2.user_account = Order_Accounting.user_account
                AND oi2.Detail_Status_Description != '買家已取件'
                AND oi2.Detail_Status_Description != '消費者成功取件'
        ) AS m
    FROM Order_Accounting
    WHERE GrantdaisouDate > '2025/10/15 00:00:00'
        AND user_account IN (
            '92653668', '96771271', '54895238', '90438307',
            '98648853', '85238336', '90081094', '27545589',
            '82379115', '83614969', '93192566', '22607683',
            '24584898', '41327634'
        )
    GROUP BY user_account
)
-- 對比結果
SELECT
    COALESCE(y.user_account, f.user_account) AS user_account,
    y.TotalAmount AS Your_TotalAmount,
    f.TotalAmount AS Fixed_TotalAmount,
    y.Service_fee AS Your_ServiceFee,
    f.Service_fee AS Fixed_ServiceFee,
    y.m AS Your_AbnormalAmount,
    f.m AS Fixed_AbnormalAmount,
    (y.TotalAmount - y.Service_fee - y.m) AS Your_d,
    (f.TotalAmount - f.Service_fee - f.m) AS Fixed_d,
    CASE
        WHEN ABS((y.TotalAmount - y.Service_fee - y.m) - (f.TotalAmount - f.Service_fee - f.m)) < 1 THEN '一致'
        ELSE '有差異'
    END AS 比對結果
FROM YourQuery y
FULL OUTER JOIN FixedQuery f
    ON y.user_account = f.user_account
ORDER BY user_account;
```

---

## 🎯 可能的差異原因

### 1. Order_Info.TotalAmount 可能包含已取消訂單

你的子查詢:
```sql
select sum(TotalAmount)
from Order_Info
where LogisticNumber in (
    select LogisticNumber
    from Order_Accounting
    where GrantdaisouDate > '2025/10/15 00:00:00'
)
```

**問題**:
- `Order_Info` 可能有多筆 (不同 sno)
- 沒有 JOIN `Order_Accounting` 確保是同一筆
- 可能會重複計算或漏算

### 2. Detail_Status_Description 的判斷

```sql
and Detail_Status_Description != '買家已取件'
and Detail_Status_Description != '消費者成功取件'
```

**可能遺漏的狀態**:
- 是否還有其他「正常取件」的描述?
- 建議改用 `NOT IN` 或 `IN` 明確列出

---

## ✅ 推薦使用的完整查詢

```sql
-- ========================================
-- 推薦版本:加入更多驗證資訊
-- ========================================
WITH MerchantSummary AS (
    SELECT
        oa.user_account,
        oa.sonid,
        bm.mem_Branchwebname AS MerchantName,
        bm.bank_code,
        bm.bank_account,
        bm.account_name,
        -- 該商家所有撥款訂單
        SUM(oa.TotalAmount) AS TotalAmount,
        SUM(oa.Service_fee) AS Service_fee,
        SUM(oa.cost) AS cost,
        COUNT(*) AS TotalOrders,
        -- 該商家異常訂單的代收款
        (
            SELECT ISNULL(SUM(oa2.TotalAmount), 0)
            FROM Order_Accounting oa2
            INNER JOIN Order_Info oi2
                ON oa2.LogisticNumber = oi2.LogisticNumber
                AND oa2.sno = oi2.sno
            WHERE oa2.GrantdaisouDate > '2025/10/15 00:00:00'
                AND oa2.user_account = oa.user_account
                AND oa2.sonid = oa.sonid  -- ★ 加上 sonid 匹配
                AND oi2.Detail_Status_Description NOT IN ('買家已取件', '消費者成功取件')
        ) AS AbnormalAmount,
        -- 異常訂單筆數
        (
            SELECT COUNT(*)
            FROM Order_Accounting oa2
            INNER JOIN Order_Info oi2
                ON oa2.LogisticNumber = oi2.LogisticNumber
                AND oa2.sno = oi2.sno
            WHERE oa2.GrantdaisouDate > '2025/10/15 00:00:00'
                AND oa2.user_account = oa.user_account
                AND oa2.sonid = oa.sonid
                AND oi2.Detail_Status_Description NOT IN ('買家已取件', '消費者成功取件')
        ) AS AbnormalOrders
    FROM Order_Accounting oa
    INNER JOIN Branch_Member bm
        ON oa.user_account = bm.user_account
        AND oa.sonid = bm.sonid
    WHERE oa.GrantdaisouDate > '2025/10/15 00:00:00'
        AND oa.DeliverMode = '01'
        AND oa.user_account IN (
            '92653668', '96771271', '54895238', '90438307',
            '98648853', '85238336', '90081094', '27545589',
            '82379115', '83614969', '93192566', '22607683',
            '24584898', '41327634'
        )
    GROUP BY
        oa.user_account,
        oa.sonid,
        bm.mem_Branchwebname,
        bm.bank_code,
        bm.bank_account,
        bm.account_name
)
SELECT
    user_account,
    sonid,
    MerchantName,
    bank_account,
    account_name,
    TotalAmount AS 代收款總額,
    Service_fee AS 服務費總額,
    cost AS 成本總額,
    TotalOrders AS 總訂單數,
    AbnormalAmount AS 異常代收款,
    AbnormalOrders AS 異常訂單數,
    (TotalAmount - Service_fee) AS 商家應收淨額,
    (TotalAmount - Service_fee - AbnormalAmount) AS d值,
    CASE
        WHEN (TotalAmount - Service_fee - AbnormalAmount) > 0 THEN '正數-不處理'
        WHEN (TotalAmount - Service_fee - AbnormalAmount) = 0 THEN '歸零-不處理'
        WHEN (TotalAmount - Service_fee - AbnormalAmount) < 0 THEN '負數-寫欠費'
    END AS 處理方式
FROM MerchantSummary
ORDER BY d值 ASC;
```

---

## 📝 建議執行順序

1. **先執行「驗證查詢1」** - 檢查 TotalAmount 差異
2. **執行「驗證查詢2」** - 檢查 sonid 問題
3. **執行「完整對比查詢」** - 看看差異在哪
4. **執行「推薦版本」** - 使用修正後的完整查詢

把結果給我看,我可以幫你進一步分析差異原因!
