-- 批次插入 Order_Accounting 測試資料 (46筆，對應 TEST001-TEST046)
-- 使用 SELECT FROM Order_Info 確保資料一致性
-- 注意: Checkoutable 預設為 0 (false)，Service_fee 預設為 0

SET NOCOUNT ON;
GO

INSERT INTO Order_Accounting (
    LogisticNumber, sno, paymentno, user_account, sonid,
    Logistic_service, DeliverMode, TotalAmount,
    Checkoutable, Service_fee
)
SELECT
    LogisticNumber,
    sno,
    paymentno,
    user_account,
    sonid,
    Logistic_service,
    DeliverMode,
    TotalAmount,
    0 AS Checkoutable,  -- 預設未對帳
    0 AS Service_fee     -- 預設服務費為0
FROM Order_Info
WHERE LogisticNumber LIKE 'TEST%'
ORDER BY LogisticNumber;

GO

-- 驗證插入筆數
SELECT COUNT(*) as inserted_count
FROM Order_Accounting
WHERE LogisticNumber LIKE 'TEST%';

GO

-- 顯示前5筆確認資料正確
SELECT TOP 5
    LogisticNumber, sno, paymentno, user_account,
    Logistic_service, Checkoutable, Service_fee
FROM Order_Accounting
WHERE LogisticNumber LIKE 'TEST%'
ORDER BY LogisticNumber;

GO
