# 

#PHAN 1.2
Cấp 1 (Không phụ thuộc ai): User, Category, Shipper.

Cấp 2 (Phụ thuộc Cấp 1): Seller, Buyer, Store.

Cấp 3 (Phụ thuộc Cấp 2): Product.

Cấp 4 (Phụ thuộc Cấp 3): Variant, Image, Thuoc_ve.

Cấp 5 (Giao dịch): Order, Order_item, Payment...


## 2.1. Ví dụ Minh Họa (Usage Examples)

Dưới đây là các câu lệnh mẫu để test các thủ tục đã tạo.

### a. Thêm hàng mới (INSERT)
Lưu ý: 
- Sản phẩm mới tạo sẽ có trạng thái mặc định là `Hidden`.
- Báo lỗi khi dữ liệu bị rỗng, sai khoảng dữ liệu hợp lệ.
- Báo lỗi khi đã có sản phẩm cùng tên cùng cửa hàng.

```sql
EXEC Insert_Product
    @Store_id = 1,            
    @Ten_san_pham = N'Mũ phù thủy',
    @Mo_ta_chi_tiet = N'Tăng +100 Sức mạnh phép thuật (AP)',
    @Tinh_trang = 'New',
    @Trong_luong = 1;
```

### b. Thay đổi hàng đã có (UPDATE)
Lưu ý: 
- Chỉ thay đổi trạng thái thành `Active` khi đã gán ảnh và danh mục.
- Báo lỗi khi dữ liệu bị rỗng, sai khoảng dữ liệu hợp lệ.
- Báo lỗi khi đã có sản phẩm cùng tên cùng cửa hàng.

```sql
EXEC Update_Product
    @Product_id = 2,
    @Ten_san_pham = N'Mũ phù thủy',
    @Mo_ta_chi_tiet = N'Tăng +100 Sức mạnh phép thuật (AP)',
    @Tinh_trang = 'New',
    @Trong_luong = 1
    @Trang_thai_dang = Hidden;
```

### c. Xóa hàng (DELETE)
Lưu ý:
- Xóa hẳn khi sản phẩm chưa có đơn nào.
- Chuyển trạng thái về `Deleted` khi đã có đơn.
- Báo lỗi khi sản phẩm chưa tồn tại.

```sql
 EXEC Delete_Product
    @Product_id = 2;
```
