# 

#PHAN 1.2
Cấp 1 (Không phụ thuộc ai): User, Category, Shipper.

Cấp 2 (Phụ thuộc Cấp 1): Seller, Buyer, Store.

Cấp 3 (Phụ thuộc Cấp 2): Product.

Cấp 4 (Phụ thuộc Cấp 3): Variant, Image, Thuoc_ve.

Cấp 5 (Giao dịch): Order, Order_item, Payment...

#Phần 2.1
- Ví dụ thêm hàng mới:
EXEC Insert_Product
	  @Store_id = 1, 
    @Ten_san_pham = N'Mũ phù thủy',
    @Mo_ta_chi_tiet = N'+100Ap', 
    @Tinh_trang = 'New',
    @Trong_luong = 1;

- Ví dụ cập nhật hàng mới:
EXEC Update_Product
	  @Product_id = 2,
    @Ten_san_pham = N'Mũ phù thủy',
    @Mo_ta_chi_tiet = N'+100Ap', 
    @Tinh_trang = 'New',
    @Trong_luong = 1,
    @Trang_thai_dang = Hidden;

  - Ví dụ xóa 1 hàng:
  EXEC Delete_Product
    @Product_id = 2;
