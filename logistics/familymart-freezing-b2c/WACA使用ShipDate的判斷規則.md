# WACA 使用 ShipDate 判斷建單、取號、印標的規則

**建立日期**: 2025-10-22
**物流服務**: 全家冷凍大宗 (24)
**適用對象**: WACA 平台商家

---

## 📌 前提說明

### WACA 收到的 ShipDate 來源

**情境**: 消費者在 WACA 選擇全家冷凍配送門市

**全家 API 回傳給 PayNow**:
```
mapItemDetail.OrderDate = 10/7 (預定進倉日)
mapItemDetail.ShipDate = 10/8 (DC出貨日)
```

**PayNow 儲存到資料庫**:
```
OrderStoreID.OrderDate = 10/7
OrderStoreID.ShipDate = 10/8
```

**PayNow 回傳給 WACA** (特殊處理):
```csharp
// OrderController.cs:1281-1287
if (WACA == true)
{
    //WACA的單都要-1天
    //這邊的OrderDate是上收日(全家派車去廠商那的日子)
    //但當初跟WACA溝通有誤，所以所有WACA的單都要-1天
    model.ShipDate = Convert.ToDateTime(mapItemDetail.OrderDate).AddDays(-1).ToString("yyyy-MM-dd");
}

結果: WACA 收到 ShipDate = 10/6 (OrderDate - 1天)
```

---

## 🎯 核心觀念

### WACA 對 ShipDate 的理解

**WACA 收到**: `ShipDate = 10/6`

**WACA 認知**:
- `ShipDate = 10/6` 是「建議出貨日」
- 10/6 當天可以開始「建單 + 取號 + 印標」

### PayNow 系統實際驗證

**重要**: 系統驗證邏輯使用的是「資料庫的 OrderStoreID.OrderDate」，不是回傳給 WACA 的 ShipDate！

```
資料庫: OrderStoreID.OrderDate = 10/7
WACA 收到: ShipDate = 10/6

關係: WACA的ShipDate = OrderStoreID.OrderDate - 1天
```

---

## 📅 WACA 使用 ShipDate 的判斷規則

### 情境設定
- **選店日期**: 10/6 (消費者選完門市)
- **WACA 收到**: ShipDate = 10/6
- **資料庫實際**: OrderStoreID.OrderDate = 10/7

---

### 規則 1️⃣: 建單 (Add_Order)

#### WACA 的判斷邏輯
```
收到 ShipDate = 10/6

WACA 認知:
- 最早建單時間: ShipDate 當天 = 10/6
- 最晚建單時間: ShipDate + 3天 = 10/9
```

#### PayNow 系統實際驗證

**程式碼位置**: `Cls_Order.cs:10544-10557`

```csharp
DateTime OrderDatetime = Convert.ToDateTime(order_storeID.OrderDate);  // 10/7
DateTime PrintDate = OrderDatetime.AddDays(-1);  // 10/7 - 1 = 10/6
DateTime Shipdate = OrderDatetime.AddDays(2);    // 10/7 + 2 = 10/9

// 最早建單驗證
if (DateTime.Now.Date < PrintDate)  // 今天 < 10/6
{
    throw new Exception("於" + PrintDate.ToString("yyyy-MM-dd") + "允許取號");
}

// 最晚建單驗證
if (DateTime.Now.Date > Shipdate)  // 今天 > 10/9
{
    throw new Exception("此保留編號已逾時 請重選店鋪");
}
```

**驗證結果**:
- 最早: OrderDate - 1天 = 10/7 - 1 = **10/6** ✅
- 最晚: OrderDate + 2天 = 10/7 + 2 = **10/9** ✅

#### 結論
| WACA 認知 | 系統驗證 | 是否一致 |
|----------|---------|---------|
| 10/6 可以建單 | 10/6 可以建單 | ✅ 一致 |
| 10/9 最後期限 | 10/9 最後期限 | ✅ 一致 |

**可建單期間**: 10/6 ~ 10/9

---

### 規則 2️⃣: 取號 (ShipFamiB2Cpaymentno)

#### WACA 的判斷邏輯
```
收到 ShipDate = 10/6

WACA 認知:
- 建單後即可取號
- 最晚取號時間: ShipDate + 3天 = 10/9
```

#### PayNow 系統實際驗證

**程式碼位置**: `FamiFreezingB2CController.cs:327-341`

```csharp
// 查詢子訂單
Obj_FamiFreezingB2C order_FamiFreezing = cls_famib2c.Sel_FamiFreezingB2C(order.LogisticNumber);

// ⚠️ 重要: FamiFreezingB2COrder.ShipDate 實際存的是 OrderStoreID.OrderDate
DateTime ShipDate = Convert.ToDateTime(order_FamiFreezing.ShipDate);  // 10/7

// 驗證期限
if (ShipDate.AddDays(2) < DateTime.Now.Date)  // 10/7 + 2 = 10/9
{
    throw new Exception("物流編號為:" + ShipOrder.LogisticNumber + "的訂單已超過出貨期限 請重新建立訂單");
}

// 驗證保留狀態
OrderStoreID orderStoreID = cls_order.Sel_OrderStoreID(...);
if (orderStoreID.Flag != "0")
{
    throw new Exception("物流編號為:" + ShipOrder.LogisticNumber + "的店鋪空間未保留");
}
```

**驗證結果**:
- 最晚取號: FamiFreezingB2COrder.ShipDate + 2天 = 10/7 + 2 = **10/9** ✅

**⚠️ 重大陷阱**:
- `FamiFreezingB2COrder.ShipDate` 雖然叫 ShipDate
- 但實際儲存的是 `OrderStoreID.OrderDate = 10/7`
- 程式碼證據: `Cls_Order.cs:10654` → `obj_Famib2c.ShipDate = order_storeID.OrderDate;`

#### 結論
| WACA 認知 | 系統驗證 | 是否一致 |
|----------|---------|---------|
| 建單後可取號 | 建單後可取號 | ✅ 一致 |
| 10/9 最後期限 | 10/9 最後期限 | ✅ 一致 |

**可取號期間**: 建單後 ~ 10/9

---

### 規則 3️⃣: 列印標籤 (PrintFamiFreezingB2CLabel)

#### WACA 的判斷邏輯
```
收到 ShipDate = 10/6

WACA 認知:
- 取號後即可列印標籤
- 最晚列印時間: 需要查看系統驗證邏輯
```

#### PayNow 系統實際驗證

**程式碼位置**: `OrderController.cs:14057-14089`

```csharp
Obj_FamiFreezingB2C order_Famib2c = cls_famib2c.Sel_FamiFreezingB2C(LogisticNumber, sno);
OrderStoreID orderStore = cls_order.Sel_OrderStoreID(order_Famib2c.ReservedNo, user_account, sonid, "24");

// 首次列印驗證（未列印過）
if (!order.IsPrinted)
{
    // 使用 OrderStoreID.OrderDate + 2天
    if (Convert.ToDateTime(orderStore.OrderDate).AddDays(2) < DateTime.Now.Date)
    {
        print_bulk_order.Error = "物流編號:" + LogisticNumber + "已超過出貨日期";
        goto AddPrint;
    }

    // 時間限制: 15:50 前
    if (Convert.ToDateTime(orderStore.OrderDate).AddDays(2).Date == DateTime.Now.Date)
    {
        if (DateTime.Now.Hour > 15 || (DateTime.Now.Hour == 15 && DateTime.Now.Minute >= 50))
        {
            print_bulk_order.Error = "物流編號:" + LogisticNumber + "，當日已超過列印時間(15:50)";
            goto AddPrint;
        }
    }
}
// 重複列印驗證（已列印過）
else
{
    // 使用 OrderStoreID.ShipDate + 6天
    if (Convert.ToDateTime(orderStore.ShipDate).AddDays(6) < DateTime.Now.Date)
    {
        print_bulk_order.Error = "物流編號:" + LogisticNumber + "已超過出貨日期";
        goto AddPrint;
    }
}
```

**驗證結果**:
- **首次列印**: OrderStoreID.OrderDate + 2天 15:50 前 = 10/7 + 2 = **10/9 15:50** 前 ✅
- **重複列印**: OrderStoreID.ShipDate + 6天 = 10/8 + 6 = **10/14** ✅

#### 結論
| WACA 認知 | 系統驗證 | 實際可用時間 |
|----------|---------|------------|
| 取號後可列印 | 10/9 15:50 前（首次） | 10/6 ~ 10/9 15:50 |
| - | 10/14 前（重複列印） | 10/6 ~ 10/14 |

**可列印期間**:
- 首次列印: 取號後 ~ 10/9 15:50
- 重複列印: 10/6 ~ 10/14

---

## 📊 WACA 時間軸總覽

### 以 WACA 收到 ShipDate = 10/6 為例

```
10/6 (WACA ShipDate)
  ├─ ✅ 可以建單 (OrderDate - 1 = 10/7 - 1 = 10/6)
  ├─ ✅ 建單後可取號
  └─ ✅ 取號後可列印標籤

10/7 (資料庫 OrderDate - 全家上收日)
  └─ 全家派車到商家收貨

10/8 (資料庫 ShipDate - DC出貨日)
  └─ 貨物到達全家物流中心

10/9 15:50
  ├─ ❌ 最晚建單時間 (OrderDate + 2 = 10/7 + 2)
  ├─ ❌ 最晚取號時間 (ShipDate + 2 = 10/7 + 2)
  └─ ❌ 最晚首次列印時間 (OrderDate + 2)

10/10
  └─ ❌ API 開始拋錯

10/11 凌晨 02:45
  └─ ⚠️ 未建單的保留編號會被系統自動取消

10/14
  └─ ❌ 最後可重複列印標籤日期 (ShipDate + 6 = 10/8 + 6)
```

---

## 🎯 WACA 使用建議

### ✅ 最佳實踐

**建議操作時間**: WACA 收到 ShipDate 當天

```
10/6 收到 ShipDate = 10/6
  ├─ 09:00 建單 (Add_Order) ✅
  ├─ 09:05 取號 (ShipFamiB2Cpaymentno) ✅
  └─ 09:10 列印標籤 (PrintFamiFreezingB2CLabel) ✅
```

### ⚠️ 注意事項

1. **建單和取號要在 10/9 前完成**
   - 最晚期限: ShipDate + 3天 = 10/6 + 3 = 10/9
   - 實際驗證: OrderDate + 2天 = 10/7 + 2 = 10/9

2. **首次列印有時間限制**
   - 最晚: 10/9 15:50
   - 超過時間只能等隔天或重選店

3. **理解 ShipDate 的真實意義**
   - WACA 收到的 ShipDate = 資料庫 OrderDate - 1天
   - 這是為了修正「當初溝通有誤」的歷史問題
   - 讓 WACA 的理解與系統驗證一致

---

## 🔍 驗證公式對照表

| 驗證項目 | WACA 認知公式 | 系統實際驗證公式 | 結果 |
|---------|--------------|----------------|------|
| **最早建單** | ShipDate = 10/6 | OrderDate - 1 = 10/7 - 1 = 10/6 | ✅ 一致 |
| **最晚建單** | ShipDate + 3 = 10/9 | OrderDate + 2 = 10/7 + 2 = 10/9 | ✅ 一致 |
| **最晚取號** | ShipDate + 3 = 10/9 | FFB.ShipDate + 2 = 10/7 + 2 = 10/9 | ✅ 一致 |
| **首次列印** | - | OrderDate + 2 = 10/7 + 2 = 10/9 15:50 | - |
| **重複列印** | - | OrderStoreID.ShipDate + 6 = 10/8 + 6 = 10/14 | - |

**結論**: WACA 的 ShipDate 認知與系統驗證邏輯完全一致！

---

## 💻 相關程式碼位置

| 功能 | 檔案 | 行數 | 說明 |
|------|------|------|------|
| WACA ShipDate 處理 | OrderController.cs | 1281-1287 | OrderDate - 1天 |
| 建單最早時間驗證 | Cls_Order.cs | 10553-10557 | OrderDate - 1 |
| 建單最晚時間驗證 | Cls_Order.cs | 10548-10552 | OrderDate + 2 |
| 取號時間驗證 | FamiFreezingB2CController.cs | 327-332 | ShipDate + 2 |
| 首次列印時間驗證 | OrderController.cs | 14073-14089 | OrderDate + 2 |
| 重複列印時間驗證 | OrderController.cs | 14067 | ShipDate + 6 |
| ShipDate 欄位誤導 | Cls_Order.cs | 10654 | 存的是 OrderDate |

---

**文件維護**:
- ✅ 已驗證所有規則與程式碼一致
- ✅ 已確認 WACA 的 ShipDate 認知與系統驗證邏輯一致
- ⚠️ ShipDate - 1天 的處理是為了修正歷史溝通問題
