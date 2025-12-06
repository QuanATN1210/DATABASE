USE ShopeeDB;
GO

-- ============================================================================
-- PHẦN 1: TẠO CÁC BẢNG PHỤ (SHADOW TABLES)
-- ============================================================================

-- Bảng 1: Lưu Đơn giá thực tế (Thuộc tính B)
IF OBJECT_ID('Shadow_Item_Price', 'U') IS NOT NULL DROP TABLE Shadow_Item_Price;
CREATE TABLE Shadow_Item_Price
(
    Order_id INT,
    Item_id INT,
    Product_id INT,
    SKU NVARCHAR(100),
    So_luong INT,
    Don_gia_thuc_te DECIMAL(18, 2),
    -- THUỘC TÍNH B
    Last_Updated DATETIME DEFAULT GETDATE(),
    PRIMARY KEY (Order_id, Item_id)
);
GO

-- Bảng 2: Lưu Tổng tiền đơn hàng (Thuộc tính A)
IF OBJECT_ID('Shadow_Order_Total', 'U') IS NOT NULL DROP TABLE Shadow_Order_Total;
CREATE TABLE Shadow_Order_Total
(
    Order_id INT PRIMARY KEY,
    Tong_tien DECIMAL(18, 2),
    -- THUỘC TÍNH A
    Last_Updated DATETIME DEFAULT GETDATE()
);
GO

-- ============================================================================
-- PHẦN 2: TRIGGER DÂY CHUYỀN
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TRIGGER 1: TÍNH 'ĐƠN GIÁ' (B) -> LƯU VÀO SHADOW_ITEM_PRICE 
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Calculate_B_Shadow_Item
ON Order_item
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AffectedList TABLE (Order_id INT,
        Item_id INT);
    INSERT INTO @AffectedList
        (Order_id, Item_id)
            SELECT Order_id, Item_id
        FROM inserted
    UNION
        SELECT Order_id, Item_id
        FROM deleted;

    MERGE INTO Shadow_Item_Price AS Target
    USING (
        SELECT
        oi.Order_id, oi.Item_id, oi.Product_id, oi.SKU, oi.So_luong,
        ISNULL(v.Gia_ban * (1 - ISNULL(c.Ti_le_giam, 0) / 100.0), 0) AS Don_gia_moi
    FROM @AffectedList al
        JOIN Order_item oi ON al.Order_id = oi.Order_id AND al.Item_id = oi.Item_id
        JOIN Variant v ON oi.Product_id = v.Product_id AND oi.SKU = v.SKU
        LEFT JOIN Ap_dung ad ON oi.Order_id = ad.Order_id AND oi.Item_id = ad.Item_id
        LEFT JOIN Coupon c ON ad.Coupon_id = c.Coupon_id
    ) AS Source
    ON (Target.Order_id = Source.Order_id AND Target.Item_id = Source.Item_id)
    
    WHEN MATCHED THEN
        UPDATE SET 
            Target.So_luong = Source.So_luong,
            Target.Don_gia_thuc_te = Source.Don_gia_moi,
            Target.Last_Updated = GETDATE()
            
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (Order_id, Item_id, Product_id, SKU, So_luong, Don_gia_thuc_te, Last_Updated)
        VALUES (Source.Order_id, Source.Item_id, Source.Product_id, Source.SKU, Source.So_luong, Source.Don_gia_moi, GETDATE())
        
    -- Chỉ xóa khi Item đó thực sự nằm trong danh sách bị ảnh hưởng
    WHEN NOT MATCHED BY SOURCE 
         AND EXISTS (SELECT 1
    FROM @AffectedList al
    WHERE al.Order_id = Target.Order_id AND al.Item_id = Target.Item_id) 
    THEN
        DELETE;

    PRINT N'>>> STEP 1: Đã tính xong Đơn giá (B) và lưu vào bảng phụ Shadow_Item_Price';
END;
GO

-- ----------------------------------------------------------------------------
-- TRIGGER 2: TÍNH 'TỔNG TIỀN' (A) -> LƯU VÀO SHADOW_ORDER_TOTAL
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Calculate_A_Shadow_Total
ON Shadow_Item_Price
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AffectedOrders TABLE (Order_id INT);
    INSERT INTO @AffectedOrders
            SELECT DISTINCT Order_id
        FROM inserted
    UNION
        SELECT DISTINCT Order_id
        FROM deleted;

    MERGE INTO Shadow_Order_Total AS Target
    USING (
        SELECT
        Order_id,
        ISNULL(SUM(Don_gia_thuc_te * So_luong), 0) AS Tong_tien_moi
    FROM Shadow_Item_Price
    WHERE Order_id IN (SELECT Order_id
    FROM @AffectedOrders)
    GROUP BY Order_id
    ) AS Source
    ON (Target.Order_id = Source.Order_id)
    
    WHEN MATCHED THEN
        UPDATE SET Target.Tong_tien = Source.Tong_tien_moi, Target.Last_Updated = GETDATE()
        
    WHEN NOT MATCHED THEN
        INSERT (Order_id, Tong_tien, Last_Updated)
        VALUES (Source.Order_id, Source.Tong_tien_moi, GETDATE());

    PRINT N'>>> STEP 2: Đã tính xong Tổng tiền (A) từ bảng phụ Item và lưu vào Shadow_Order_Total';
END;
GO

-- ----------------------------------------------------------------------------
-- TRIGGER 3: XỬ LÝ KHI THAY ĐỔI COUPON (BẢNG AP_DUNG)
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Update_Chain_On_Coupon
ON Ap_dung
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AffectedList TABLE (Order_id INT,
        Item_id INT);
    INSERT INTO @AffectedList
        (Order_id, Item_id)
            SELECT Order_id, Item_id
        FROM inserted
    UNION
        SELECT Order_id, Item_id
        FROM deleted;

    UPDATE sip
    SET 
        sip.Don_gia_thuc_te = ISNULL(v.Gia_ban * (1 - ISNULL(c.Ti_le_giam, 0) / 100.0), 0),
        sip.Last_Updated = GETDATE()
    FROM Shadow_Item_Price sip
        JOIN Variant v ON sip.Product_id = v.Product_id AND sip.SKU = v.SKU
        JOIN @AffectedList al ON sip.Order_id = al.Order_id AND sip.Item_id = al.Item_id
        LEFT JOIN Ap_dung ad ON sip.Order_id = ad.Order_id AND sip.Item_id = ad.Item_id
        LEFT JOIN Coupon c ON ad.Coupon_id = c.Coupon_id;

    PRINT N'>>> STEP 0: Coupon thay đổi -> Đã cập nhật lại giá B trong bảng phụ';
END;
GO

-- ============================================================================
-- PHẦN 3: ĐỒNG BỘ DỮ LIỆU CŨ (DATA SYNC)
-- ============================================================================
PRINT N'Đang đồng bộ dữ liệu vào bảng phụ...';

-- 1. Xóa sạch dữ liệu cũ trong bảng phụ
TRUNCATE TABLE Shadow_Item_Price;
TRUNCATE TABLE Shadow_Order_Total;

-- 2. Đổ dữ liệu vào Shadow Items (Tính B)
-- Ngay khi lệnh này chạy xong, Trigger 'trg_Calculate_A_Shadow_Total' 
-- sẽ TỰ ĐỘNG chạy để tính toán và điền dữ liệu vào bảng 'Shadow_Order_Total'.

INSERT INTO Shadow_Item_Price
    (Order_id, Item_id, Product_id, SKU, So_luong, Don_gia_thuc_te)
SELECT
    oi.Order_id, oi.Item_id, oi.Product_id, oi.SKU, oi.So_luong,
    ISNULL(v.Gia_ban * (1 - ISNULL(c.Ti_le_giam, 0) / 100.0), 0)
FROM Order_item oi
    JOIN Variant v ON oi.Product_id = v.Product_id AND oi.SKU = v.SKU
    LEFT JOIN Ap_dung ad ON oi.Order_id = ad.Order_id AND oi.Item_id = ad.Item_id
    LEFT JOIN Coupon c ON ad.Coupon_id = c.Coupon_id;

PRINT N'Hoàn tất thiết lập! Trigger đã tự động tính toán cho cả 2 bảng.';
GO