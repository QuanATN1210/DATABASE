# BÁO CÁO CHI TIẾT HIỆN THỰC VÀ KIỂM THỬ HÀM (FUNCTIONS)

**Lưu ý quan trọng:** Các hàm được hiện thực dưới đây hoạt động theo cơ chế chỉ **ĐỌC dữ liệu (SELECT)** để tính toán và trả về kết quả, hoàn toàn không thực hiện các thao tác làm thay đổi dữ liệu (INSERT, UPDATE, DELETE).

---

## I. CHI TIẾT CÁC HÀM ĐÃ HIỆN THỰC

### 1. Hàm 1: Tính doanh thu ròng của Cửa hàng (`fn_Tinh_Doanh_Thu_Rong_Store`)

#### A. Mục đích và Giải thuật
* **Mục đích:** Tính tổng doanh thu thực nhận của một cửa hàng trong một tháng cụ thể sau khi đã trừ đi phí sàn (Commission Fee). Mức phí sàn không cố định mà thay đổi tùy theo danh mục sản phẩm (Ví dụ: Điện tử 5%, Thời trang 8%, Khác 10%).
* **Giải thuật:**
    * **Validate:** Sử dụng `IF NOT EXISTS` để kiểm tra sự tồn tại của `Store_id` và tính hợp lệ của thời gian (tháng/năm). Nếu không hợp lệ trả về `NULL`.
    * **Cursor (Con trỏ):** Duyệt qua từng dòng sản phẩm trong các đơn hàng có trạng thái `Đã Giao` của tháng cần tính.
    * **Loop & IF:** Trong vòng lặp `WHILE`, hệ thống kiểm tra `Category_id` của từng sản phẩm để thiết lập biến `@Phi_San` tương ứng, sau đó cộng dồn giá trị thực nhận vào tổng doanh thu ròng.

#### B. Phân tích dữ liệu nguồn (Data Dependency)
Hàm này thực hiện truy vấn liên kết qua 6 bảng để đảm bảo tính toán chính xác:
1.  **`Store`:** Kiểm tra sự tồn tại của cửa hàng.
2.  **`Product`:** Xác định sản phẩm thuộc cửa hàng nào.
3.  **`Thuoc_ve`:** Xác định sản phẩm thuộc danh mục (`Category`) nào để tính % phí sàn.
4.  **`Order_item`:** Lấy thông tin về số lượng bán ra.
5.  **`Variant`:** **(Quan trọng)** Lấy đơn giá bán (`Gia_ban`) chính xác của sản phẩm.
6.  **`[Order]`:** Lọc đơn hàng theo trạng thái "Đã Giao" và thời gian.

---

### 2. Hàm 2: Tính điểm uy tín Người mua (`fn_Tinh_Diem_Uy_Tin_Buyer`)

#### A. Mục đích và Giải thuật
* **Mục đích:** Xây dựng hệ thống xếp hạng người dùng (Gamification). Điểm uy tín sẽ tăng khi người dùng mua hàng thành công và có tương tác đánh giá sản phẩm.
* **Giải thuật:**
    * **Validate:** Kiểm tra `Buyer_id`. Nếu không tìm thấy Buyer, hàm trả về `NULL`.
    * **Cursor (Con trỏ):** Duyệt qua toàn bộ lịch sử đơn hàng của người mua.
    * **Calculated Field:** Trong câu lệnh `SELECT` của con trỏ, thực hiện tính tổng tiền đơn hàng (SUM `Gia_ban` * `So_luong`) từ bảng `Variant` và `Order_item`.
    * **Query Nested (Truy vấn lồng):** Trong vòng lặp, sử dụng `IF EXISTS (SELECT 1 FROM Danh_gia...)` để kiểm tra xem đơn hàng đã được đánh giá chưa.
* **Logic tính điểm:**
    * Đơn hàng thành công: **+10 điểm**.
    * Đơn hàng giá trị cao (> 1 triệu VNĐ): **+5 điểm**.
    * Có thực hiện đánh giá: **+2 điểm**.
    * Đơn hàng Hủy/Hoàn trả: **-20 điểm**.

#### B. Phân tích dữ liệu nguồn (Data Dependency)
Hàm này tương tác với các bảng:
1.  **`Buyer`:** Kiểm tra user đầu vào.
2.  **`[Order]`:** Xác định trạng thái đơn (Hoàn tất/Hủy).
3.  **`Order_item` & `Variant`:** Tính toán tổng giá trị thực tế của đơn hàng để xét thưởng.
4.  **`Danh_gia`:** Kiểm tra hành vi đánh giá sản phẩm.

---

## III. NHẬN XÉT VÀ ĐÁNH GIÁ KẾT QUẢ CHẠY THỬ (TESTING)

### 1. Đánh giá Hàm 1: Tính Doanh Thu Ròng (`fn_Tinh_Doanh_Thu_Rong_Store`)

* **Tính đúng đắn của phép toán (Calculation Logic):**
    * Kết quả trả về là kiểu `DECIMAL(18,2)`, đảm bảo độ chính xác cho dữ liệu tiền tệ.
    * Hệ thống đã thực hiện phép nhân `(Gia_ban * So_luong)` từ bảng Variant và Order_item, sau đó trừ đi % phí sàn chính xác theo từng Category (Ví dụ: Category 1 trừ 5%, Category 2 trừ 8%).
* **Khả năng duyệt dữ liệu (Cursor & Loop):**
    * Con trỏ đã duyệt thành công qua nhiều sản phẩm trong cùng một đơn hàng và nhiều đơn hàng trong tháng.
    * Ví dụ: Nếu Store bán được 2 sản phẩm thuộc 2 Category khác nhau trong cùng 1 đơn, vòng lặp tính phí riêng cho từng món rồi mới cộng tổng. Điều này chính xác hơn việc áp phí sàn trung bình.
* **Kiểm tra tham số đầu vào (Validation):**
    * Khi truyền vào `Store_id` không tồn tại hoặc Tháng/Năm sai (ví dụ tháng 13), hàm trả về `NULL`. Điều này giúp ứng dụng gọi hàm nhận biết được lỗi dữ liệu đầu vào.

### 2. Đánh giá Hàm 2: Tính Điểm Uy Tín Buyer (`fn_Tinh_Diem_Uy_Tin_Buyer`)

* **Logic tính điểm (Scoring Logic):**
    * **Trường hợp cộng dồn:** Một đơn hàng thành công (>1 triệu) và đã đánh giá sẽ được cộng tổng cộng: 10 (cơ bản) + 5 (giá trị cao) + 2 (đánh giá) = **17 điểm**. Logic này đã được `IF/ELSE` trong vòng lặp xử lý đúng.
    * **Trường hợp trừ điểm:** Các đơn `Đã Hủy` bị trừ 20 điểm trực tiếp, phản ánh đúng logic phạt người dùng hủy đơn.
* **Xử lý ngoại lệ (Error Handling):**
    * Khi nhập `Buyer_id` không có trong hệ thống, kết quả là `NULL`.
    * Hàm có thêm logic `IF @Diem_Uy_Tin < 0 SET @Diem_Uy_Tin = 0` ở cuối, đảm bảo không bao giờ hiển thị điểm âm cho người dùng.

---

## IV. KẾT LUẬN CHUNG
Qua quá trình hiện thực và kiểm thử, hai hàm đã đáp ứng đầy đủ yêu cầu kỹ thuật:

1.  **Con trỏ (Cursor):** Được sử dụng hợp lý để xử lý các logic phức tạp trên từng dòng dữ liệu (tính phí từng món, xét điểm từng đơn) mà các câu lệnh `SELECT` đơn thuần khó thực hiện.
2.  **Cấu trúc điều khiển:** Kết hợp nhuần nhuyễn `LOOP` và `IF/ELSE` (bao gồm cả IF lồng nhau).
3.  **Toàn vẹn dữ liệu:** Sử dụng `JOIN` chính xác giữa các bảng `Order_item`, `Variant`, `Thuoc_ve` để lấy dữ liệu giá và danh mục đúng nhất.
4.  **Kiểm tra đầu vào:** Có validate tham số để tránh lỗi runtime.