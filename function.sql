USE ShopeeDB;
GO

-- ============================================================
-- HÀM 1: TÍNH DOANH THU RÒNG (JOIN thêm bảng Variant để lấy giá)
-- ============================================================
CREATE OR ALTER FUNCTION fn_Tinh_Doanh_Thu_Rong_Store (
    @Store_id INT,
    @Thang INT,
    @Nam INT
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Store WHERE Store_id = @Store_id) RETURN NULL;
    IF @Thang < 1 OR @Thang > 12 OR @Nam < 2000 RETURN NULL;

    DECLARE @Tong_Doanh_Thu_Rong DECIMAL(18,2) = 0;
    
    -- Biến con trỏ
    DECLARE @Doanh_Thu_Item DECIMAL(18,2);
    DECLARE @Category_id INT;
    DECLARE @Phi_San DECIMAL(18,2);

    -- Cursor duyệt qua từng Item đã bán
    DECLARE cursor_san_pham CURSOR FOR
    SELECT 
        (v.Gia_ban * oi.So_luong) AS Doanh_Thu_Item, -- Lấy giá từ Variant
        tv.Category_id
    FROM Order_item oi
    JOIN Variant v ON oi.Product_id = v.Product_id AND oi.SKU = v.SKU -- JOIN Variant lấy giá
    JOIN Product p ON oi.Product_id = p.Product_id
    JOIN Thuoc_ve tv ON p.Product_id = tv.Product_id
    JOIN [Order] o ON oi.Order_id = o.Order_id
    WHERE p.Store_id = @Store_id
      AND o.Trang_thai_don = N'Đã Giao'
      AND MONTH(o.Ngay_dat_hang) = @Thang
      AND YEAR(o.Ngay_dat_hang) = @Nam;

    OPEN cursor_san_pham;
    FETCH NEXT FROM cursor_san_pham INTO @Doanh_Thu_Item, @Category_id;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Tính phí sàn 
        IF @Category_id IN (1, 6) SET @Phi_San = 0.05;      -- Điện tử
        ELSE IF @Category_id IN (2, 7) SET @Phi_San = 0.08; -- Thời trang
        ELSE SET @Phi_San = 0.10;                           -- Khác

        SET @Tong_Doanh_Thu_Rong = @Tong_Doanh_Thu_Rong + (@Doanh_Thu_Item * (1 - @Phi_San));

        FETCH NEXT FROM cursor_san_pham INTO @Doanh_Thu_Item, @Category_id;
    END

    CLOSE cursor_san_pham;
    DEALLOCATE cursor_san_pham;

    RETURN @Tong_Doanh_Thu_Rong;
END;
GO

-- ============================================================
-- HÀM 2: TÍNH ĐIỂM UY TÍN (Tự tính tổng tiền đơn hàng trong Cursor)
-- ============================================================
CREATE OR ALTER FUNCTION fn_Tinh_Diem_Uy_Tin_Buyer (
    @Buyer_id INT
)
RETURNS INT
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Buyer WHERE User_id = @Buyer_id) RETURN NULL;

    DECLARE @Diem_Uy_Tin INT = 100;
    
    DECLARE @Order_id INT;
    DECLARE @Trang_thai_don NVARCHAR(50);
    DECLARE @Tong_Gia_Tri_Don DECIMAL(18,2);

    -- Cursor tính sẵn tổng tiền cho từng đơn hàng của Buyer
    DECLARE cursor_don_hang CURSOR FOR
    SELECT 
        o.Order_id, 
        o.Trang_thai_don,
        -- Tính tổng tiền đơn hàng ngay tại đây
        ISNULL((SELECT SUM(v.Gia_ban * oi.So_luong) 
                FROM Order_item oi 
                JOIN Variant v ON oi.Product_id = v.Product_id AND oi.SKU = v.SKU
                WHERE oi.Order_id = o.Order_id), 0) AS Tong_Gia_Tri
    FROM [Order] o
    WHERE o.Buyer_id = @Buyer_id;

    OPEN cursor_don_hang;
    FETCH NEXT FROM cursor_don_hang INTO @Order_id, @Trang_thai_don, @Tong_Gia_Tri_Don;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @Trang_thai_don = N'Đã Giao'
        BEGIN
            SET @Diem_Uy_Tin = @Diem_Uy_Tin + 10;

            -- Nếu đơn hàng > 1 triệu (Dựa vào giá trị vừa tính)
            IF @Tong_Gia_Tri_Don > 1000000 
                SET @Diem_Uy_Tin = @Diem_Uy_Tin + 5;

            -- Check đánh giá
            IF EXISTS (SELECT 1 FROM Danh_gia WHERE Order_id = @Order_id)
                SET @Diem_Uy_Tin = @Diem_Uy_Tin + 2;
        END
        ELSE IF @Trang_thai_don IN (N'Đã Hủy', N'Hoàn Trả')
        BEGIN
            SET @Diem_Uy_Tin = @Diem_Uy_Tin - 20;
        END

        FETCH NEXT FROM cursor_don_hang INTO @Order_id, @Trang_thai_don, @Tong_Gia_Tri_Don;
    END

    CLOSE cursor_don_hang;
    DEALLOCATE cursor_don_hang;

    IF @Diem_Uy_Tin < 0 SET @Diem_Uy_Tin = 0;

    RETURN @Diem_Uy_Tin;
END;
GO