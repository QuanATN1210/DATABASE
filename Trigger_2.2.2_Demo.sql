USE ShopeeDB;
GO

PRINT '=============================================================';
PRINT 'KỊCH BẢN DEMO: GIỎ HÀNG NHIỀU MÓN (MULTI-ITEMS)';
PRINT '=============================================================';

-- CHỌN ĐỐI TƯỢNG TEST: Order_id = 1
DECLARE @TargetOrder INT = 1;
DECLARE @Item_Samsung INT = 1;
-- Item cũ (Samsung S24)
DECLARE @Item_AoPolo INT = 2;
-- Item mới sẽ thêm (Áo Polo)

-- BƯỚC 1: XEM TRẠNG THÁI BAN ĐẦU
-- Xóa hết coupon cũ của đơn hàng này để đảm bảo test bắt đầu từ GIÁ GỐC
DELETE FROM Ap_dung WHERE Order_id = @TargetOrder;
PRINT '>>> 1. TRẠNG THÁI HIỆN TẠI (Order 1 đang có 1 món)';
SELECT 'Bang phu Item (B)' AS Nguon, *
FROM Shadow_Item_Price
WHERE Order_id = @TargetOrder;
SELECT 'Bang phu Total (A)' AS Nguon, *
FROM Shadow_Order_Total
WHERE Order_id = @TargetOrder;

-- BƯỚC 2: THÊM MÓN MỚI VÀO GIỎ (INSERT)
-- Mua thêm 2 cái Áo Polo (Product 2, Giá 299k/cái)
PRINT '';
PRINT '>>> 2. THAO TÁC: Mua thêm 2 cái Áo Polo (299k x 2 = 598k)';

-- Xóa trước để tránh lỗi trùng nếu chạy lại nhiều lần
DELETE FROM Order_item WHERE Order_id = @TargetOrder AND Item_id = @Item_AoPolo;

INSERT INTO Order_item
    (Order_id, Item_id, Product_id, SKU, So_luong)
VALUES
    (@TargetOrder, @Item_AoPolo, 2, 'POLO-EX-XANH-L', 2);

-- Kiểm tra: Tổng tiền phải tăng thêm 598,000
SELECT 'SAU KHI THEM AO' AS Trang_thai,
    Item_id, SKU, So_luong, Don_gia_thuc_te AS [B_Don_gia]
FROM Shadow_Item_Price
WHERE Order_id = @TargetOrder;

SELECT 'TONG DON MOI' AS Trang_thai, Tong_tien AS [A_Tong_Tien]
FROM Shadow_Order_Total
WHERE Order_id = @TargetOrder;


-- BƯỚC 3: TĂNG SỐ LƯỢNG MÓN CŨ (UPDATE)
-- Samsung S24 (Item 1) tăng lên 3 cái
PRINT '';
PRINT '>>> 3. THAO TÁC: Tăng số lượng Samsung S24 lên 3 cái';
UPDATE Order_item 
SET So_luong = 3 
WHERE Order_id = @TargetOrder AND Item_id = @Item_Samsung;

-- Kiểm tra
SELECT 'SAU UPDATE SO LUONG' AS Trang_thai, Tong_tien AS [A_Tong_Tien]
FROM Shadow_Order_Total
WHERE Order_id = @TargetOrder;


-- BƯỚC 4: ÁP DỤNG MÃ GIẢM GIÁ (CHỈ CHO SAMSUNG)
-- Áp mã giảm 50% (Coupon 2) cho Item 1. Item 2 (Áo) giữ nguyên giá.
PRINT '';
PRINT '>>> 4. THAO TÁC: Áp mã giảm 50% chỉ cho Samsung S24';

-- Gia hạn coupon tránh lỗi hết hạn
UPDATE Coupon SET Thoi_han = DATEADD(day, 7, GETDATE()) WHERE Coupon_id = 2;
DELETE FROM Ap_dung WHERE Order_id = @TargetOrder AND Item_id = @Item_Samsung;

INSERT INTO Ap_dung
    (Order_id, Item_id, Coupon_id)
VALUES
    (@TargetOrder, @Item_Samsung, 2);

-- Kiểm tra kết quả cuối cùng
-- Kỳ vọng: (Samsung đã giảm * 3) + (Áo nguyên giá * 2)
SELECT 'KET QUA CUOI CUNG' AS Trang_thai,
    sip.Item_id,
    sip.Don_gia_thuc_te AS [B_Gia_Moi_Mon],
    sip.So_luong,
    (sip.Don_gia_thuc_te * sip.So_luong) AS [Thanh_Tien_Tung_Mon]
FROM Shadow_Item_Price sip
WHERE sip.Order_id = @TargetOrder;

SELECT 'TONG TIEN PHAI TRA' AS Ket_Qua, Tong_tien AS [A_Tong_Cong]
FROM Shadow_Order_Total
WHERE Order_id = @TargetOrder;


-- BƯỚC 5: DỌN DẸP (CLEAN UP)
PRINT '';
PRINT '>>> 5. KHÔI PHỤC DỮ LIỆU GỐC...';
-- Xóa áo polo
DELETE FROM Order_item WHERE Order_id = @TargetOrder AND Item_id = @Item_AoPolo;
-- Trả Samsung về 1 cái
UPDATE Order_item SET So_luong = 1 WHERE Order_id = @TargetOrder AND Item_id = @Item_Samsung;
-- Xóa coupon
DELETE FROM Ap_dung WHERE Order_id = @TargetOrder AND Item_id = @Item_Samsung AND Coupon_id = 2;

PRINT '=============================================================';
GO