# 全家冷凍大宗訂單流程說明

**物流服務代號**: 24 (全家大宗冷凍)
**最後更新**: 2025-10-22
**版本**: v3.1 (完整說明 WACA 和 D+1 商家的特殊處理)

---

## 📌 重要提醒

### 本文件適用對象

**本文件適用於所有使用全家冷凍大宗的商家**

| 使用方式 | 選店方式 | 建單方式 | 說明 |
|---------|---------|---------|------|
| **API 串接** | 透過 PayNow 電子地圖 | API 呼叫 | WACA 等平台商家 |
| **後台操作** | 透過 PayNow 電子地圖 | 後台手動操作 | 一般商家登入後台 |

### ⚠️ 關鍵觀念

**商家不可能自己串全家電子地圖！**

- 全家電子地圖是全家提供的服務
- 所有商家（API 串接或後台操作）都必須透過 PayNow 當中介
- 消費者選完門市後，全家會回傳資料到 PayNow 的 `GetFamiFreezingStoreid`
- PayNow 再將資料轉給商家或儲存到資料庫

### 🔴 特殊處理 1: WACA 平台（歷史遺留問題）

**WACA 有歷史遺留問題，回傳的日期會減 1 天！**

**程式碼位置**: `OrderController.cs:1281-1287`
```csharp
if (WACA == true)
{
    //WACA的單都要-1天
    //這邊的OrderDate是上收日(全家派車去廠商那的日子)
    //但當初跟WACA溝通有誤，所以所有WACA的單都要-1天
    model.ShipDate = Convert.ToDateTime(mapItemDetail.OrderDate).AddDays(-1).ToString("yyyy-MM-dd");
}
```

**範例**:
- 全家回傳: OrderDate = 10/7
- PayNow 回給 WACA: ShipDate = 10/6（**減 1 天**）

**影響**:
- ⚠️ 這只影響「回傳給 WACA 的顯示日期」
- ✅ 資料庫儲存的還是正確的 10/7
- ✅ 後續建單、取號邏輯不受影響

---

### 🟢 特殊處理 2: D+1 商家（業務邏輯）

**某些商家設定為「D+1」（訂單上傳後晚一天才收貨），回傳的日期會加 1 天！**

**程式碼位置**: `OrderController.cs:1292-1297`
```csharp
//全家收貨日 DeliveryDay是1 代表收貨日為D+1 訂單上傳後晚一天才收貨
if (bulk_register.DeliveryDay == 1)
{
    //這邊的SHIPDATE是全家上收的SHIPDATE 為全家估計貨應該到全家艙的時間 通常為OrderDate+1天
    model.ShipDate = Convert.ToDateTime(model.ShipDate).AddDays(1).ToString("yyyy-MM-dd");
}
```

**範例**:
- 全家回傳: OrderDate = 10/7
- PayNow 回給 D+1 商家: ShipDate = 10/8（**加 1 天**）

**目的**:
- 避免商家覺得「收貨延遲」
- 讓商家提早取號，實際收貨時間才對得上

**影響範圍**:
- ✅ 所有 `DeliveryDay = 1` 的商家（不限平台）
- ❌ 不是只有 WACA

**註解說明**:
```
要在OrderDate前一天對我們取號。一般的流程是 OrderDate上傳訂單資料，OrderDate上收。
但對D+1的商家來說，OrderDate是不會有人來收貨的。
如果商家是OrderDate當天才取號，會變成下午上傳檔案，上收日又會更晚一天，會變D+2。
為了不讓商家覺得晚兩天才收貨，直接把SHIPDATE往後，然後跟商家說讓他提早取號。
其實是把原本的Ordate改用SHIPDATE吐回給商家，這樣日子就對得起來了，讓他們產生錯覺。

範例: OrderDate=5/3, ShipDate=5/4
- 正常商家: 回傳5/3給商家，5/2取號，5/3上收
- D+1商家: 回傳5/5給商家(ShipDate+1)，商家在5/2~5/4取號
  - 5/2下午~5/3早上上傳 → 5/4收貨
  - 5/3下午~5/4早上上傳 → 5/5收貨
```

---

### 📊 兩種特殊處理的組合情境

**執行順序**: 先處理 WACA -1 天，再處理 D+1 +1 天

| 商家類型 | WACA? | DeliveryDay | 全家回傳 OrderDate | 最終回傳給商家 | 計算過程 |
|---------|-------|-------------|-------------------|--------------|---------|
| **一般商家** | ❌ | 0 | 10/7 | **10/7** | 不變 |
| **一般 D+1 商家** | ❌ | 1 | 10/7 | **10/8** | 10/7 + 1 |
| **WACA 一般** | ✅ | 0 | 10/7 | **10/6** | 10/7 - 1 |
| **WACA D+1 商家** | ✅ | 1 | 10/7 | **10/7** | (10/7 - 1) + 1 = 10/7 |

**程式碼位置**: `OrderController.cs:1281-1297`

---

## 📋 商家名詞對照表

| 商家說法 | 系統 API/功能 | 實際動作 | 說明 |
|---------|--------------|----------|------|
| **選店** | 全家電子地圖 → GetFamiFreezingStoreid | 消費者選擇門市 | 所有商家都透過 PayNow 處理 |
| **出貨** | Add_Order + ShipFamiB2Cpaymentno | 建單 + 取號 | API 串接或後台操作 |
| **列印標籤** | PrintFamiFreezingB2CLabel | 產生出貨標籤 | 商家貼在包裹上出貨 |

---

## 🔄 完整流程說明

### 1️⃣ 選店流程（所有商家都一樣）

```
消費者選擇全家冷凍配送:
  ├─ API 串接: WACA 呼叫 ChoseLogistics API
  │  └─ 參數: Ecplateform = "WACA_xxxx", StartDate, EndDate
  │
  ├─ 後台操作: 商家在 PayNow 後台點選「選擇門市」
  │  └─ 參數: StartDate, EndDate
  │
  └─ PayNow 產生全家電子地圖 JSON
     ├─ CvsName: 全家地圖 URL
     ├─ Cvslink: /Member/Order/GetFamiFreezingStoreid (回傳網址)
     ├─ CvsTemp: 商家帳號,子代號,urltype,訂單編號,Ecplateform
     └─ Items: StartDate, EndDate, 材積資料

消費者在電子地圖選擇門市:
  └─ 全家 API 回傳到 PayNow 的 GetFamiFreezingStoreid
     ├─ ReservedNo = 25100300000039823192 (保留編號)
     ├─ OrderDate = 10/7 (預定進倉日) ⭐
     ├─ ShipDate = 10/8 (DC出貨日) ⭐
     └─ StoreID, StoreName, StoreAddress

PayNow 處理:
  ├─ 儲存到 OrderStoreID 資料表
  │  ├─ OrderDate = 10/7
  │  └─ ShipDate = 10/8
  │
  └─ 回傳給商家/平台
     ├─ 一般商家: OrderDate = 10/7
     └─ WACA 平台: ShipDate = 10/6 ⚠️ 減 1 天（歷史遺留問題）
```

**⚠️ 重要發現**:
- OrderDate 和 ShipDate **不是固定公式**
- 全家 API 會根據 StartDate/EndDate **動態計算**
- 不同案例可能得到不同的日期差距

**urltype 說明**:
- `01`: 回傳於 API 串接的電子地圖（WACA 等平台）
- `02`: 回傳於 PayNow 後台操作
- `03`: 重選店鋪（API 串接）

### 2️⃣ 商家建單
```
WACA 平台呼叫: api/Orderapi/Add_Order
  ├─ 參數: ReservedNo, 商品資訊, 收件人資訊
  ├─ 系統查詢 OrderStoreID 取得:
  │  ├─ OrderDate = 10/7
  │  └─ ShipDate = 10/8
  └─ 建立 FamiFreezingB2COrder 訂單
     ├─ LogisticNumber = 系統產生
     └─ ShipDate = 10/7 ⚠️ 存的是 OrderDate!
```

**⚠️ 重大陷阱**: `FamiFreezingB2COrder.ShipDate` 雖然叫 ShipDate，但程式碼實際存入的是 `OrderStoreID.OrderDate`！

程式碼證據 (`Cls_Order.cs:10654`):
```csharp
obj_Famib2c.ShipDate = order_storeID.OrderDate;  // 存的是 OrderDate!
```

### 3️⃣ 商家取號 (ShipFamiB2Cpaymentno API)
```
WACA 平台呼叫: api/FamiFreezingB2C/ShipFamiB2Cpaymentno
  ├─ 參數: LogisticNumber (物流編號)
  ├─ 驗證 1: FamiFreezingB2COrder.ShipDate + 2天 >= 今天
  │  └─ 10/7 + 2 = 10/9 (最後取號日)
  ├─ 驗證 2: OrderStoreID.Flag = '0' (未取消)
  ├─ 呼叫全家 API 取得 paymentno
  └─ 回傳: paymentno (配送編號)
```

**驗證邏輯位置**: `FamiFreezingB2CController.cs:327-341`

### 4️⃣ 列印標籤（API 或後台都一樣）

```
API 串接: 存取 Member/Order/PrintFamiFreezingB2CLabel
  ├─ 參數: LogisticNumbers (物流編號)
  └─ 系統產生標籤 PDF/圖片

後台操作: 商家在 PayNow 後台點「列印標籤」
  └─ 導向 Member/Order/PrintFamiFreezingB2CLabel

結果:
  ├─ 產生條碼標籤
  └─ 商家下載後貼在包裹上出貨
```

**重要**: WACA 需要先完成「建單 → 取號 → 列印標籤」的順序

---

## 📅 真實案例時間軸

**案例資料**:
- 商家: 本西堂 (83167011)
- 保留編號: 25100300000039823192
- 選店日期: 2025-10-06
- StartDate: 2025-10-07
- EndDate: 2025-10-09
- **全家回傳**:
  - OrderDate = 2025-10-07 (預定進倉日)
  - ShipDate = 2025-10-08 (DC出貨日)

### 時間軸說明

```
10/6 (選店日) - 消費者選完店後
  ✅ 商家馬上就可以出貨 (建單 + 取號)

  驗證邏輯:
  - 建單 API: OrderDate - 1天 = 10/7 - 1 = 10/6 ✅ 可以建單
  - 取號 API: 建單後即可取號 ✅

10/6 ~ 10/9 - 可以出貨期間
  ✅ 建單 (Add_Order)
  ✅ 取號 (ShipFamiB2Cpaymentno)
  ✅ 列印標籤

10/10 - 無法出貨
  ❌ 建單 API 會拋錯: 「此保留編號已逾時 請重選店鋪」
     計算: OrderDate + 2天 = 10/7 + 2 = 10/9
     位置: Cls_Order.cs:10548-10552

  ❌ 取號 API 會拋錯: 「訂單已超過出貨期限 請重新建立訂單」
     計算: FamiFreezingB2COrder.ShipDate + 2天 = 10/7 + 2 = 10/9
     位置: FamiFreezingB2CController.cs:327-332

10/11 凌晨 02:45 - 系統自動取消 ⭐
  系統排程執行: Sel_CancelSpaceStore (SP)

  檢查邏輯:
  SELECT * FROM OrderStoreID
  WHERE NOT EXISTS (
      SELECT LogisticNumber FROM FamiFreezingB2COrder
      WHERE FamiFreezingB2COrder.ReservedNo = OrderStoreID.ReservedNo
  )
  AND OrderDate < DATEADD(DAY, -3, GETDATE())  -- 10/7 < 10/11 - 3 = 10/8
  AND Flag = '0'
  AND Logistic_service = '24'

  執行動作: Flag = '1' (已取消)
  程式位置: Cls_FamiFreezingB2C.cs:3186-3228
```

---

## 🎯 關鍵重點

### ✅ 正確觀念

1. **選店後馬上可以出貨**
   - 10/6 選完店 → 10/6 就能建單+取號
   - 不用等到 10/7 或 10/8

2. **建單和取號要在 10/9 前完成**
   - 10/6 ~ 10/9: API 正常運作
   - 10/10 開始: API 會拋錯

3. **系統取消有延遲**
   - 10/10: API 已經拋錯，但 Flag 還是 '0'
   - 10/11 凌晨: 系統才正式取消 (Flag = '1')

### ❌ 錯誤觀念 (舊文件的錯誤)

舊文件說:
- ❌ 全家回傳 `OrderDate = StartDate+1 = 10/8`
- ✅ 正確: 全家回傳 `OrderDate = StartDate = 10/7`

舊文件說:
- ❌ 全家回傳 `ShipDate = StartDate+2 = 10/9`
- ✅ 正確: 全家回傳 `ShipDate = StartDate+1 = 10/8`

**為什麼錯誤?**
全家 API 根據 StartDate/EndDate **動態計算**，不是固定公式！

舊文件說:
- ❌ 10/8 (StartDate+1) 才能開始取號
- ✅ 正確: 10/6 選完店馬上就能建單+取號

**錯誤認知來源**:
有人誤解了程式碼 `Cls_Order.cs:10546` 的驗證邏輯：
```csharp
DateTime PrintDate = OrderDatetime.AddDays(-1);  // 10/7 - 1 = 10/6
if (result2 < 0)  // 如果今天 < 10/6
{
    throw new Exception("於" + PrintDate.ToString("yyyy-MM-dd") + "允許取號");
}
```
這段程式碼的意思是：**10/6 (含) 以後就可以建單**，不是「10/8 才能取號」！

---

## 📊 資料庫欄位說明

### OrderStoreID 資料表

| 欄位 | 範例值 | 說明 |
|-----|-------|------|
| user_account | 83167011 | 商家帳號 |
| sonid | 001 | 分店代號 |
| orderno | 523bdaee09a44f0aa321 | 訂單編號 |
| **OrderDate** | 2025-10-07 | 預定進倉日 (全家回傳) |
| **ShipDate** | 2025-10-08 | DC出貨日 (全家回傳) |
| **ReservedNo** | 25100300000039823192 | 保留編號 |
| **Flag** | 0 或 1 | 0=已保留, 1=已取消 |
| StoreID | 007729 | 門市店號 |
| StoreName | 全家新營新興店 | 門市名稱 |

### FamiFreezingB2COrder 資料表

| 欄位 | 說明 | ⚠️ 重要提醒 |
|-----|------|-----------|
| LogisticNumber | PayNow 物流編號 | 系統產生 |
| ReservedNo | 保留編號 | 關聯 OrderStoreID |
| OrderDate | 系統建單日期 | 當天日期 |
| **ShipDate** | **預定進倉日** | **欄位名稱誤導!實際存 OrderStoreID.OrderDate** |
| paymentno | 全家配送編號 | 取號後才有值 |

**⚠️ 重大陷阱**: `FamiFreezingB2COrder.ShipDate` 雖然叫 ShipDate，但儲存的是 `OrderStoreID.OrderDate` (10/7)，不是 `OrderStoreID.ShipDate` (10/8)!

程式碼證據:
```csharp
// Cls_Order.cs:10654
obj_Famib2c.ShipDate = order_storeID.OrderDate;  // 存的是 OrderDate!
```

---

## 💻 程式碼位置快查

### API 驗證邏輯

| API | 驗證項目 | 檔案 | 行數 | 計算邏輯 |
|-----|---------|------|------|---------|
| Add_Order | 最早建單 | Cls_Order.cs | 10553-10557 | OrderDate - 1 = 10/6 |
| Add_Order | 最晚建單 | Cls_Order.cs | 10548-10552 | OrderDate + 2 = 10/9 |
| ShipFamiB2Cpaymentno | 取號期限 | FamiFreezingB2CController.cs | 327-332 | ShipDate + 2 = 10/9 |
| ShipFamiB2Cpaymentno | 保留狀態 | FamiFreezingB2CController.cs | 337-341 | Flag = '0' |

### 系統排程

| 功能 | 檔案 | 行數 | 說明 |
|-----|------|------|------|
| 排程主程式 | Cls_FamiFreezingB2C.cs | 3186-3228 | CancelSpace() |
| SP 呼叫 | Cls_FamiFreezingB2C.cs | 3194 | Sel_CancelSpaceStore |
| 更新 Flag | Cls_FamiFreezingB2C.cs | 3207 | Up_OrderStoreIDFlag(Flag='1') |

---

## 🔍 查詢 SQL

```sql
-- 查詢完整訂單狀態
SELECT
    osi.ReservedNo,
    osi.OrderDate,      -- 10/7 預定進倉日
    osi.ShipDate,       -- 10/8 DC出貨日
    osi.Flag,           -- 0=已保留, 1=已取消
    osi.StoreName,
    ffb.LogisticNumber,
    ffb.ShipDate as FFB_ShipDate,  -- ⚠️ 存的是 OrderDate (10/7)
    oi.paymentno,
    oi.IsPrinted
FROM OrderStoreID osi
LEFT JOIN FamiFreezingB2COrder ffb ON osi.ReservedNo = ffb.ReservedNo
LEFT JOIN Order_Info oi ON osi.orderno = oi.LogisticNumber
WHERE osi.ReservedNo = '25100300000039823192'
```

**判斷訂單狀態**:
- `ffb.LogisticNumber IS NULL` → 未建單
- `oi.paymentno IS NULL` → 已建單但未取號
- `oi.paymentno IS NOT NULL` → 已取號
- `oi.IsPrinted = '1'` → 已列印標籤
- `osi.Flag = '1'` → 保留編號已取消

---

## 📝 測試案例 (使用真實資料)

```sql
-- 1. 查詢保留編號狀態
SELECT Flag FROM OrderStoreID WHERE ReservedNo = '25100300000039823192'
-- 結果: Flag = 1 (已取消)

-- 2. 檢查是否已建單
SELECT COUNT(*) FROM FamiFreezingB2COrder
WHERE ReservedNo = '25100300000039823192'
-- 結果: 0 (未建單，所以被系統取消了)

-- 3. 檢查取消條件
SELECT OrderDate, DATEADD(DAY, 3, OrderDate) as 取消日期
FROM OrderStoreID
WHERE ReservedNo = '25100300000039823192'
-- 結果: OrderDate=2025-10-07, 取消日期=2025-10-10
-- 說明: 10/11 凌晨檢查時, 10/7 < 10/11-3=10/8, 所以被取消
```

---

## ⚠️ 與舊文件的主要差異

| 項目 | 舊文件 (錯誤) | 新文件 (正確) | 驗證依據 |
|------|-------------|-------------|---------|
| 適用對象 | 混合 API 和頁面操作 | 僅 API 串接商家 | 需求澄清 |
| OrderDate 計算 | StartDate + 1 | **全家 API 動態計算** | 真實資料驗證 |
| ShipDate 計算 | StartDate + 2 | **全家 API 動態計算** | 真實資料驗證 |
| 選店後可建單時間 | StartDate | **選店當天 (StartDate-1)** | 程式碼驗證 |
| FFB.ShipDate 內容 | DC出貨日 | **預定進倉日 (OrderDate)** | 程式碼證據 |

---

---

## ❓ 常見問題 FAQ

### Q1: WACA 平台的訂單處理有什麼不同嗎？

**A: ❌ 沒有不同**

- 所有透過 API 串接的平台都走同一套流程
- `Ecplateform` 參數只用於識別來源，不影響業務邏輯
- 建單和取號的驗證規則完全一樣

### Q2: 為什麼之前說「10/8 才能取號」？

**A: 這是對程式碼的誤解！**

**程式碼實際邏輯**:
```csharp
// Cls_Order.cs:10546
DateTime PrintDate = OrderDatetime.AddDays(-1);  // 10/7 - 1 = 10/6
if (result2 < 0)  // 如果今天 < 10/6
{
    throw new Exception("於" + PrintDate.ToString("yyyy-MM-dd") + "允許取號");
}
```

有人誤以為「要等到 OrderDate+1」，其實程式碼的意思是：
- ✅ **10/6 (含) 以後就可以建單**
- ❌ 不是「要等到 10/8」

### Q3: 選店後真的可以「馬上」建單+取號嗎？

**A: ✅ 是的，馬上就可以！**

**驗證邏輯**:
- 建單 API: `OrderDate - 1天 >= 今天` → 10/7 - 1 = 10/6 ✅
- 取號 API: `ShipDate + 2天 >= 今天` → 10/7 + 2 = 10/9 ✅
- 兩個條件在 10/6 都滿足！

### Q4: 為什麼有時候 OrderDate = ShipDate？

**A: 全家 API 會根據實際情況動態計算**

**案例 1** (你的案例):
```
StartDate = 10/7, EndDate = 10/9
→ OrderDate = 10/7, ShipDate = 10/8 (差距 1 天)
```

**案例 2** (資料庫其他案例):
```
StartDate = 4/8, EndDate = 4/8
→ OrderDate = 4/8, ShipDate = 4/8 (差距 0 天)
```

**結論**: 不要用固定公式計算，以全家 API 回傳值為準！

### Q5: 建單和取號一定要同一天嗎？

**A: ❌ 不一定，但都要在期限內完成**

- 可以 10/6 建單，10/7 取號 ✅
- 可以 10/8 建單，10/8 取號 ✅
- 可以 10/6 建單，10/9 取號 ✅
- ❌ 不能 10/10 建單 (超過期限)
- ❌ 不能 10/6 建單，10/10 取號 (超過期限)

**期限**: 10/6 ~ 10/9 之間完成即可

---

**文件維護說明**:
- ✅ 此文件為最終正確版本 (v2.1)
- ✅ 已根據真實案例驗證 (ReservedNo: 25100300000039823192)
- ✅ 已根據程式碼驗證 (Cls_Order.cs, FamiFreezingB2CController.cs)
- ✅ 已根據資料庫結構驗證
- ⚠️ 其他文件包含過時或錯誤資訊，請以此文件為準
- ⚠️ 僅適用於 API 串接商家 (如 WACA 平台)
