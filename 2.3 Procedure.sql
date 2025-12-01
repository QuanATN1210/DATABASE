USE ShopeeDB
-- ============================================================
-- THỦ TỤC 2.3.1: TÌM KIẾM SẢN PHẨM CỦA CỬA HÀNG
-- ============================================================
-- Mục đích: Cho phép cửa hàng tìm kiếm và lọc sản phẩm của mình
-- Tham số: Store_id (bắt buộc), các filter tùy chọn
-- Kết quả: Danh sách sản phẩm với thông tin tổng hợp (số variant, tổng tồn kho, giá min-max)

GO
CREATE OR ALTER PROCEDURE sp_TimKiemSanPham_CuaHang
    @Store_id INT,                                    -- ID cửa hàng (bắt buộc)
    @Ten_san_pham NVARCHAR(200) = NULL,              -- Tìm theo tên (tùy chọn)
    @Ten_danh_muc NVARCHAR(100) = NULL,              -- Lọc theo tên danh mục (tùy chọn)
    @Gia_tu DECIMAL(18,2) = NULL,                    -- Lọc giá từ
    @Gia_den DECIMAL(18,2) = NULL,                   -- Lọc giá đến
    @Sap_xep VARCHAR(50) = 'Ngay_dang_DESC'          -- Sắp xếp: Ngay_dang_DESC/ASC, Ten_ASC/DESC, Gia_ASC/DESC
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Kiểm tra Store_id có tồn tại không
    IF NOT EXISTS (SELECT 1 FROM Store WHERE Store_id = @Store_id)
    BEGIN
        RAISERROR(N'Lỗi: Không tìm thấy cửa hàng với Store_id = %d', 16, 1, @Store_id);
        RETURN;
    END
    
    -- Kiểm tra Ten_danh_muc nếu có
    IF @Ten_danh_muc IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Category WHERE Ten LIKE N'%' + @Ten_danh_muc + '%')
    BEGIN
        RAISERROR(N'Lỗi: Không tìm thấy danh mục có chứa từ khóa "%s"', 16, 1, @Ten_danh_muc);
        RETURN;
    END
    
    -- Kiểm tra tham số giá hợp lệ
    IF (@Gia_tu IS NOT NULL AND @Gia_tu < 0)
    BEGIN
        RAISERROR(N'Lỗi: Giá từ phải >= 0', 16, 1);
        RETURN;
    END
    
    IF (@Gia_den IS NOT NULL AND @Gia_den < 0)
    BEGIN
        RAISERROR(N'Lỗi: Giá đến phải >= 0', 16, 1);
        RETURN;
    END
    
    IF (@Gia_tu IS NOT NULL AND @Gia_den IS NOT NULL AND @Gia_tu > @Gia_den)
    BEGIN
        RAISERROR(N'Lỗi: Giá từ không được lớn hơn giá đến', 16, 1);
        RETURN;
    END
    
    -- Truy vấn chính với JOIN từ nhiều bảng
    SELECT 
        p.Product_id,
        p.Ten_san_pham,
        p.Mo_ta_chi_tiet,
        p.Tinh_trang,
        p.Trong_luong,
        p.Trang_thai_dang,
        p.Ngay_dang,
        
        -- Thông tin từ bảng Image (lấy ảnh đầu tiên)
        (SELECT TOP 1 Duong_dan_anh 
         FROM [Image] 
         WHERE Product_id = p.Product_id 
         ORDER BY Image_id) AS Anh_dai_dien,
        
        -- Thông tin từ bảng Category (lấy tên category đầu tiên nếu có nhiều)
        (SELECT TOP 1 c.Ten 
         FROM Thuoc_ve tv 
         INNER JOIN Category c ON tv.Category_id = c.Category_id
         WHERE tv.Product_id = p.Product_id) AS Ten_danh_muc,
        
        -- Thông tin tổng hợp từ bảng Variant (aggregate functions)
        COUNT(DISTINCT v.SKU) AS So_luong_variant,
        MIN(v.Gia_ban) AS Gia_thap_nhat,
        MAX(v.Gia_ban) AS Gia_cao_nhat,
        SUM(v.So_luong_ton_kho) AS Tong_ton_kho,
        
        -- Thông tin đánh giá trung bình
        AVG(CAST(dg.So_sao AS FLOAT)) AS Diem_danh_gia_TB,
        COUNT(DISTINCT dg.Order_id) AS So_luot_danh_gia
        
    FROM Product p
    -- JOIN với Variant (bắt buộc vì cần thông tin giá và tồn kho)
    LEFT JOIN Variant v ON p.Product_id = v.Product_id
    
    -- JOIN với Thuoc_ve và Category (để lọc theo danh mục)
    LEFT JOIN Thuoc_ve tv ON p.Product_id = tv.Product_id
    LEFT JOIN Category c ON tv.Category_id = c.Category_id
    
    -- JOIN với Danh_gia (để tính điểm đánh giá)
    LEFT JOIN Danh_gia dg ON p.Product_id = dg.Product_id
    
    WHERE p.Store_id = @Store_id
        -- Điều kiện WHERE với các filter
        AND (@Ten_san_pham IS NULL OR p.Ten_san_pham LIKE N'%' + @Ten_san_pham + '%')
        AND (@Ten_danh_muc IS NULL OR c.Ten LIKE N'%' + @Ten_danh_muc + '%')
    
    GROUP BY 
        p.Product_id, p.Ten_san_pham, p.Mo_ta_chi_tiet, 
        p.Tinh_trang, p.Trong_luong, p.Trang_thai_dang, p.Ngay_dang
    
    -- HAVING để lọc theo giá (sau khi đã tính MIN/MAX)
    HAVING 
        (@Gia_tu IS NULL OR MIN(v.Gia_ban) >= @Gia_tu)
        AND (@Gia_den IS NULL OR MAX(v.Gia_ban) <= @Gia_den)
    
    -- ORDER BY động dựa vào tham số
    ORDER BY 
        CASE 
            WHEN @Sap_xep = 'Ngay_dang_DESC' THEN p.Ngay_dang
        END DESC,
        CASE 
            WHEN @Sap_xep = 'Ngay_dang_ASC' THEN p.Ngay_dang
        END ASC,
        CASE 
            WHEN @Sap_xep = 'Ten_ASC' THEN p.Ten_san_pham
        END ASC,
        CASE 
            WHEN @Sap_xep = 'Ten_DESC' THEN p.Ten_san_pham
        END DESC,
        CASE 
            WHEN @Sap_xep = 'Gia_ASC' THEN MIN(v.Gia_ban)
        END ASC,
        CASE 
            WHEN @Sap_xep = 'Gia_DESC' THEN MAX(v.Gia_ban)
        END DESC;
END;
GO


-- ============================================================
-- THỦ TỤC 2.3.2: XEM CHI TIẾT SẢN PHẨM VỚI CÁC VARIANT
-- ============================================================
-- Mục đích: Hiển thị đầy đủ thông tin sản phẩm khi người dùng click vào
-- Bao gồm: Thông tin cơ bản, tất cả ảnh, tất cả variant với màu/size/giá/tồn kho
-- Kết quả: Trả về nhiều result set cho các phần khác nhau

GO
CREATE OR ALTER PROCEDURE sp_XemChiTiet_SanPham
    @Product_id INT,                    -- ID sản phẩm cần xem (bắt buộc)
    @Store_id INT = NULL                -- ID cửa hàng (tùy chọn, để kiểm tra quyền)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Kiểm tra Product_id có tồn tại không
    IF NOT EXISTS (SELECT 1 FROM Product WHERE Product_id = @Product_id)
    BEGIN
        RAISERROR(N'Lỗi: Không tìm thấy sản phẩm với Product_id = %d', 16, 1, @Product_id);
        RETURN;
    END
    
    -- Kiểm tra quyền truy cập nếu Store_id được cung cấp
    IF @Store_id IS NOT NULL 
        AND NOT EXISTS (SELECT 1 FROM Product WHERE Product_id = @Product_id AND Store_id = @Store_id)
    BEGIN
        RAISERROR(N'Lỗi: Sản phẩm này không thuộc về cửa hàng của bạn (Store_id = %d)', 16, 1, @Store_id);
        RETURN;
    END
    
    -- ========== RESULT SET 1: THÔNG TIN CƠ BẢN SẢN PHẨM ==========
    SELECT 
        p.Product_id,
        p.Store_id,
        s.Ten_gian_hang,
        p.Ten_san_pham,
        p.Mo_ta_chi_tiet,
        p.Tinh_trang,
        p.Trong_luong,
        p.Trang_thai_dang,
        p.Ngay_dang,
        
        -- Thông tin tổng hợp
        COUNT(DISTINCT v.SKU) AS Tong_so_variant,
        MIN(v.Gia_ban) AS Gia_thap_nhat,
        MAX(v.Gia_ban) AS Gia_cao_nhat,
        SUM(v.So_luong_ton_kho) AS Tong_ton_kho,
        
        -- Thông tin đánh giá
        AVG(CAST(dg.So_sao AS FLOAT)) AS Diem_danh_gia_TB,
        COUNT(DISTINCT dg.Order_id) AS So_luot_danh_gia,
        
        -- Số lượt đã bán
        SUM(DISTINCT oi.So_luong) AS Tong_da_ban
        
    FROM Product p
    INNER JOIN Store s ON p.Store_id = s.Store_id
    LEFT JOIN Variant v ON p.Product_id = v.Product_id
    LEFT JOIN Danh_gia dg ON p.Product_id = dg.Product_id
    LEFT JOIN Order_item oi ON p.Product_id = oi.Product_id
    LEFT JOIN [Order] o ON oi.Order_id = o.Order_id AND o.Trang_thai_don = N'Đã Giao'
    
    WHERE p.Product_id = @Product_id
    GROUP BY 
        p.Product_id, p.Store_id, s.Ten_gian_hang, p.Ten_san_pham, 
        p.Mo_ta_chi_tiet, p.Tinh_trang, p.Trong_luong, 
        p.Trang_thai_dang, p.Ngay_dang;
    
    
    -- ========== RESULT SET 2: TẤT CẢ HÌNH ẢNH CỦA SẢN PHẨM ==========
    SELECT 
        Image_id,
        Duong_dan_anh
    FROM [Image]
    WHERE Product_id = @Product_id
    ORDER BY Image_id;
    
    
    -- ========== RESULT SET 3: DANH SÁCH CÁC VARIANT (MÀU SẮC, KÍCH THƯỚC, GIÁ, TỒN KHO) ==========
    -- Bao gồm aggregate function để tính số lượng đã bán cho từng variant
    SELECT 
        v.SKU,
        v.Mau_sac,
        v.Kich_thuoc,
        v.Gia_ban,
        v.So_luong_ton_kho,
        
        -- Tính số lượng đã bán của variant này
        ISNULL(SUM(CASE WHEN o.Trang_thai_don = N'Đã Giao' THEN oi.So_luong ELSE 0 END), 0) AS So_luong_da_ban,
        
        -- Tính số lượng đang trong đơn hàng chưa giao
        ISNULL(SUM(CASE WHEN o.Trang_thai_don IN (N'Chờ Xác Nhận', N'Chờ Lấy Hàng', N'Đang Vận Chuyển') 
                        THEN oi.So_luong ELSE 0 END), 0) AS So_luong_dang_xu_ly
        
    FROM Variant v
    LEFT JOIN Order_item oi ON v.Product_id = oi.Product_id AND v.SKU = oi.SKU
    LEFT JOIN [Order] o ON oi.Order_id = o.Order_id
    
    WHERE v.Product_id = @Product_id
    GROUP BY v.SKU, v.Mau_sac, v.Kich_thuoc, v.Gia_ban, v.So_luong_ton_kho
    ORDER BY v.Mau_sac, v.Kich_thuoc;
    
    
    -- ========== RESULT SET 4: DANH MỤC SẢN PHẨM THUỘC VỀ ==========
    SELECT 
        c.Category_id,
        c.Ten AS Ten_danh_muc,
        c.Super_Category_id,
        sc.Ten AS Ten_danh_muc_cha
    FROM Thuoc_ve tv
    INNER JOIN Category c ON tv.Category_id = c.Category_id
    LEFT JOIN Category sc ON c.Super_Category_id = sc.Category_id
    WHERE tv.Product_id = @Product_id
    ORDER BY c.Category_id;
    
    
    -- ========== RESULT SET 5: ĐÁNH GIÁ CỦA KHÁCH HÀNG ==========
    SELECT TOP 10
        dg.Order_id,
        dg.Ngay_danh_gia,
        dg.So_sao,
        dg.Noi_dung_binh_luan,
        dg.Phan_hoi_cua_nguoi_ban,
        
        -- Thông tin người mua
        u.Ho + ' ' + ISNULL(u.Ten_lot + ' ', '') + u.Ten AS Ten_nguoi_mua,
        
        -- Thông tin variant đã mua
        oi.SKU,
        v.Mau_sac,
        v.Kich_thuoc
        
    FROM Danh_gia dg
    INNER JOIN [Order] o ON dg.Order_id = o.Order_id
    INNER JOIN [User] u ON o.Buyer_id = u.User_id
    LEFT JOIN Order_item oi ON dg.Order_id = oi.Order_id AND dg.Product_id = oi.Product_id
    LEFT JOIN Variant v ON oi.Product_id = v.Product_id AND oi.SKU = v.SKU
    
    WHERE dg.Product_id = @Product_id
    ORDER BY dg.Ngay_danh_gia DESC;
END;
GO





-- ============================================================
-- PHẦN 2: TEST CÁC THỦ TỤC
-- ============================================================

PRINT N'========================================';
PRINT N'TEST THỦ TỤC sp_TimKiemSanPham_CuaHang';
PRINT N'========================================';

-- Test 1: Tìm tất cả sản phẩm của Store 1 (Samsung)
PRINT N'';
PRINT N'--- Test 1: Tất cả sản phẩm của Samsung (Store 1) ---';
EXEC sp_TimKiemSanPham_CuaHang @Store_id = 1;
GO

-- Test 2: Tìm sản phẩm theo tên (chứa từ "Galaxy")
PRINT N'';
PRINT N'--- Test 2: Tìm sản phẩm Samsung có từ "Galaxy" ---';
EXEC sp_TimKiemSanPham_CuaHang 
    @Store_id = 1, 
    @Ten_san_pham = N'Galaxy';
GO

-- Test 3: Tìm sản phẩm Coolmate có từ "Áo"
PRINT N'';
PRINT N'--- Test 3: Tìm sản phẩm Coolmate có từ "Áo" ---';
EXEC sp_TimKiemSanPham_CuaHang 
    @Store_id = 2, 
    @Ten_san_pham = N'Áo';
GO

-- Test 4: Lọc theo khoảng giá 100k-500k
PRINT N'';
PRINT N'--- Test 4: Sản phẩm Coolmate giá từ 100k đến 500k ---';
EXEC sp_TimKiemSanPham_CuaHang 
    @Store_id = 2,
    @Gia_tu = 100000,
    @Gia_den = 500000,
    @Sap_xep = 'Gia_ASC';
GO

-- Test 5: Lọc theo tên danh mục (tìm "Thun" sẽ ra "Áo Thun")
PRINT N'';
PRINT N'--- Test 5: Lọc sản phẩm Coolmate theo danh mục có từ "Thun" ---';
EXEC sp_TimKiemSanPham_CuaHang 
    @Store_id = 2,
    @Ten_danh_muc = N'Thun';
GO

-- Test 6: Lọc theo danh mục "Điện thoại"
PRINT N'';
PRINT N'--- Test 6: Lọc sản phẩm Samsung theo danh mục "Điện thoại" ---';
EXEC sp_TimKiemSanPham_CuaHang 
    @Store_id = 1,
    @Ten_danh_muc = N'Điện thoại';
GO

-- Test 7: Lọc sách văn học
PRINT N'';
PRINT N'--- Test 7: Lọc sách theo danh mục "Văn học" ---';
EXEC sp_TimKiemSanPham_CuaHang 
    @Store_id = 3,
    @Ten_danh_muc = N'Văn học';
GO

-- Test 8: Tìm kiếm kết hợp (tên + danh mục + giá)
PRINT N'';
PRINT N'--- Test 8: Tìm sách có từ "Sách", danh mục "Văn", giá < 100k ---';
EXEC sp_TimKiemSanPham_CuaHang 
    @Store_id = 3,
    @Ten_san_pham = N'Sách',
    @Ten_danh_muc = N'Văn',
    @Gia_den = 100000,
    @Sap_xep = 'Gia_DESC';
GO

-- Test 9: Sắp xếp theo tên A-Z
PRINT N'';
PRINT N'--- Test 9: Tất cả sản phẩm Samsung sắp xếp theo tên A-Z ---';
EXEC sp_TimKiemSanPham_CuaHang 
    @Store_id = 1,
    @Sap_xep = 'Ten_ASC';
GO

-- Test 10: Sắp xếp theo giá cao nhất
PRINT N'';
PRINT N'--- Test 10: Sản phẩm Samsung sắp xếp giá cao xuống thấp ---';
EXEC sp_TimKiemSanPham_CuaHang 
    @Store_id = 1,
    @Sap_xep = 'Gia_DESC';
GO



-- Test 12: Lỗi - Store không tồn tại
PRINT N'';
PRINT N'--- Test 12: LỖI - Store_id không tồn tại ---';
EXEC sp_TimKiemSanPham_CuaHang @Store_id = 999;
GO

-- Test 13: Lỗi - Danh mục không tồn tại
PRINT N'';
PRINT N'--- Test 13: LỖI - Danh mục không tồn tại ---';
EXEC sp_TimKiemSanPham_CuaHang 
    @Store_id = 1,
    @Ten_danh_muc = N'XYZ Không Có';
GO

-- Test 14: Lỗi - Khoảng giá không hợp lệ
PRINT N'';
PRINT N'--- Test 14: LỖI - Giá từ > Giá đến ---';
EXEC sp_TimKiemSanPham_CuaHang 
    @Store_id = 1,
    @Gia_tu = 1000000,
    @Gia_den = 500000;
GO

-- Test 15: Tìm kiếm không có kết quả
PRINT N'';
PRINT N'--- Test 15: Tìm kiếm không có kết quả (giá quá thấp) ---';
EXEC sp_TimKiemSanPham_CuaHang 
    @Store_id = 1,
    @Gia_den = 1000;  -- Samsung không có sản phẩm dưới 1000đ
GO

PRINT N'';
PRINT N'========================================';
PRINT N'TEST THỦ TỤC sp_XemChiTiet_SanPham';
PRINT N'========================================';

-- Test 6: Xem chi tiết sản phẩm Samsung S24 Ultra
PRINT N'--- Test 6: Chi tiết Samsung S24 Ultra ---';
EXEC sp_XemChiTiet_SanPham @Product_id = 12;
GO

-- Test 7: Xem chi tiết với kiểm tra quyền cửa hàng
PRINT N'--- Test 7: Xem chi tiết sản phẩm của Store 2 ---';
EXEC sp_XemChiTiet_SanPham 
    @Product_id = 2, 
    @Store_id = 2;
GO

-- Test 8: Lỗi - Sản phẩm không thuộc cửa hàng
PRINT N'--- Test 8: Lỗi - Xem sản phẩm không thuộc cửa hàng ---';
EXEC sp_XemChiTiet_SanPham 
    @Product_id = 1,  -- Samsung S24 (Store 1)
    @Store_id = 2;     -- Coolmate (Store 2) - Không có quyền
GO

-- Test 9: Lỗi - Product_id không tồn tại
PRINT N'--- Test 9: Lỗi - Product_id không tồn tại ---';
EXEC sp_XemChiTiet_SanPham @Product_id = 999;
GO

PRINT N'';
PRINT N'========================================';
PRINT N'HOÀN TẤT TEST CÁC THỦ TỤC';
PRINT N'========================================';