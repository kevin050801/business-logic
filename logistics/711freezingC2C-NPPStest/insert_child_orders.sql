-- 711冷凍C2C子訂單測試資料 (46筆)
-- 對應主訂單的 LogisticNumber
SET NOCOUNT ON;
GO

-- 批次插入子訂單
INSERT INTO [711FreezingC2COrder] (LogisticNumber, OrderNo, user_account, eshopid, eshopsonid, service_type, account, payamount, payment_cpname, deadlinedate, daishou_account, sender, sender_phone, receiver, receiver_phone, receiver_storeid, return_storeid, showtype, AwardAmount, paymentno, validationno, receiver_storestatus, return_storestatus, receiver_storename, return_storename, createtime, Id)
SELECT LogisticNumber, '', user_account, '', sonid, '1', 0, 0, '', CAST(Deadline AS NCHAR(10)), 0, '', '', '', '', receiver_storeid, receiver_storeid, '0', 0, paymentno, '', '0', '0', '', '', OrderDate, ROW_NUMBER() OVER (ORDER BY LogisticNumber)
FROM Order_Info
WHERE LogisticNumber LIKE 'TEST%';

GO
SELECT COUNT(*) as child_order_count FROM [711FreezingC2COrder] WHERE LogisticNumber LIKE 'TEST%';
GO
