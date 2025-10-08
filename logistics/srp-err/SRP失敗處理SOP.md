# SRP 失敗處理 SOP

## 報警內容範例
```
錯誤警告
SRP失敗：SRP訂單內容錯誤 檔案名稱:829I482025100801.SRP
```

## 處理步驟

### 1. 定位 130.4 資料夾
- 路徑：`D:\Logistics\711B2C\SIN\{商家帳號}`
- 範例：`D:\Logistics\711B2C\SIN\54305556`

### 2. 取得 FTP 設定
從 `webconfig` 查看 7-11 大宗 FTP 設定：
```xml
<!--7-11大宗ftp-->
<add key="7-11BulkftpUrl" value="FTP://b2c-ds.presco.com.tw" />
```

### 3. 查詢商家 FTP 帳密
```sql
select ftpusername,ftppassword
from User_LogisticService
where user_account='54305556'
and LogisticServiceID='02'
```

### 4. 分析 SRP 檔案
- 查看 `.SRP` 檔案內容（固定格式檔案）
- 範例：`829I482025100801.SRP`
```
45
44
1
I48880987992025100895100303867Y          DLYM0047B1251007003401121
```

格式說明：
- 第一行：總筆數 (45)
- 第二行：成功筆數 (44)
- 第三行：失敗筆數 (1)
- 第四行起：失敗的訂單明細

### 5. 比對 XML 原始檔案
- 找到對應的原始 XML 檔案：`829I482025100801.xml`
- 在 XML 中找到失敗的訂單編號 (例如：`DLYM0047B12510070034`)

### 6. 確認資料庫訂單狀態
```sql
select *
from Bulk711Order
where LogisticNumber='DLYM0047B12510070034'
```

### 7. 建立修正後的 XML 檔案
- 從原始 XML 中提取失敗訂單
- 修正問題（如姓名錯誤："阿J" → "阿阿J"）
- 建立新的 XML 檔案：`829I482025100802.xml`
- 檔案內容DocNo也要改：`829I482025100802`

### 8. 更新資料庫 SIN 檔案名稱
```sql
declare
@LogisticNumber varchar(20)='DLYM0047B12510070034',
@SinFileName varchar(20)='829I482025100802.xml';

Update Bulk711Order
set SINFileName=@SinFileName
where LogisticNumber=@LogisticNumber;
```

### 9. 重新上傳 FTP
- 使用步驟 3 取得的 FTP 帳密
- 上傳修正後的 XML 檔案至 7-11 FTP

### 10. 監控與驗證
- 等待 7-11 系統重新處理
- 確認是否收到新的 SRP 回應
- 驗證訂單狀態更新正確

## 常見問題原因

1. **訂單資料錯誤**
   - 姓名格式不符
   - 電話格式錯誤
   - 門市代碼錯誤

2. **檔案格式問題**
   - XML 格式不正確
   - 編碼問題（需使用 UTF-8）

3. **資料不一致**
   - 資料庫與 XML 內容不符
   - 訂單金額計算錯誤

## 注意事項

- 保留原始 SRP 和 XML 檔案作為備份
- 記錄處理過程和問題原因
- 更新資料庫時要確認 LogisticNumber 正確
- 新的 SIN 檔案名稱要遞增（如：801 → 802）
