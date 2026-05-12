Họ Tên: Nguyễn Xuân Hiếu

MSSV: K235480106027

Lớp: K59KMT.K01

Nội Dung 03:  THIẾT KẾ VÀ CÀI ĐẶT CSDL QUẢN LÝ CẦM ĐỒ 

 # Nhiệm vụ 1: Thiết kế CSDL
```
-- 1. Tạo Database mới
CREATE DATABASE QuanLyCamDo;
GO
USE QuanLyCamDo;
GO

-- 2. Bảng Khách hàng (KhachHang)
CREATE TABLE KhachHang (
    MaKH INT PRIMARY KEY IDENTITY(1,1), -- Khóa chính tự tăng
    HoTen NVARCHAR(100) NOT NULL,
    SoDienThoai VARCHAR(15),
    CCCD VARCHAR(12) UNIQUE,
    DiaChi NVARCHAR(255)
);

-- 3. Bảng Nhân viên (NhanVien) - Để ghi nhận người thu tiền trong Log
CREATE TABLE NhanVien (
    MaNV INT PRIMARY KEY IDENTITY(1,1),
    HoTen NVARCHAR(100) NOT NULL,
    ChucVu NVARCHAR(50)
);

-- 4. Bảng Hợp đồng (HopDong)
CREATE TABLE HopDong (
    MaHD INT PRIMARY KEY IDENTITY(1,1),
    MaKH INT NOT NULL, -- Khóa ngoại nối tới KhachHang
    NgayVay DATETIME DEFAULT GETDATE(),
    SoTienGoc DECIMAL(18,2) NOT NULL,
    Deadline1 DATE NOT NULL, -- Mốc tính lãi kép
    Deadline2 DATE NOT NULL, -- Mốc thanh lý tài sản
    TrangThai NVARCHAR(50) DEFAULT N'Đang vay',
    CONSTRAINT FK_HopDong_KhachHang FOREIGN KEY (MaKH) REFERENCES KhachHang(MaKH)
);

-- 5. Bảng Tài sản (TaiSan)
CREATE TABLE TaiSan (
    MaTS INT PRIMARY KEY IDENTITY(1,1),
    MaHD INT NOT NULL, -- Khóa ngoại nối tới HopDong
    TenTaiSan NVARCHAR(100) NOT NULL,
    GiaTriDinhGia DECIMAL(18,2),
    TrangThaiTS NVARCHAR(50) DEFAULT N'Đang cầm cố',
    CONSTRAINT FK_TaiSan_HopDong FOREIGN KEY (MaHD) REFERENCES HopDong(MaHD)
);

-- 6. Bảng Nhật ký (LogBienDong)
CREATE TABLE LogBienDong (
    MaLog INT PRIMARY KEY IDENTITY(1,1),
    MaHD INT NOT NULL, -- Khóa ngoại nối tới HopDong
    MaNV INT NOT NULL, -- Khóa ngoại nối tới NhanVien
    NgayGiaoDich DATETIME DEFAULT GETDATE(),
    SoTienTra DECIMAL(18,2),
    NoiDung NVARCHAR(255),
    CONSTRAINT FK_Log_HopDong FOREIGN KEY (MaHD) REFERENCES HopDong(MaHD),
    CONSTRAINT FK_Log_NhanVien FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV)
);
```
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/b04f5b2b-f9c1-4f0e-8dd8-d4713cffe8d4" />
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/f996691a-796d-448e-a660-0f8b369eba66" />
Để thực hiện Nhiệm vụ 1, em đã khởi tạo cơ sở dữ liệu QuanLyCamDo và thiết lập 5 bảng dữ liệu chuẩn hóa 3NF gồm: Khách hàng, Nhân viên, Hợp đồng, Tài sản và Log biến động.
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/cecedfb6-9b3e-48bc-9591-bf53c507da64" />
Sau khi khởi tạo cơ sở dữ liệu QuanLyCamDo, em đã thiết lập 5 bảng chuẩn hóa 3NF và kết nối chúng qua sơ đồ Diagram

# Nhiệm vụ 2: Cài đặt SQL (Yêu cầu viết Scripts)
* Event 1: Đăng ký hợp đồng mới (Vay tiền)
```
CREATE PROCEDURE sp_InsertContract
    @CustomerID INT,
    @LoanAmount DECIMAL(18,2),
    @Deadline1 DATE,
    @Deadline2 DATE,
    @AssetList XML -- Danh sách tài sản dạng XML để xử lý nhiều tài sản một lúc
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ContractID INT;

    -- 1. Tạo hợp đồng mới
    INSERT INTO HopDong (KhachHangID, SoTienVayGoc, NgayVay, Deadline1, Deadline2, TrangThai)
    VALUES (@CustomerID, @LoanAmount, GETDATE(), @Deadline1, @Deadline2, N'Đang vay');
    
    SET @ContractID = SCOPE_IDENTITY();

    -- 2. Thêm danh sách tài sản từ XML
    INSERT INTO TaiSan (ContractID, TenTaiSan, GiaTriDinhGia, TrangThai)
    SELECT 
        @ContractID,
        T.c.value('@Ten', 'NVARCHAR(100)'),
        T.c.value('@GiaTri', 'DECIMAL(18,2)'),
        N'Đang cầm cố'
    FROM @AssetList.nodes('/Assets/Item') AS T(c);
END;
```
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/9de74137-d488-4e35-ad88-f3fe0623830a" />
Sử dụng XML giúp tiếp nhận danh sách nhiều tài sản trong một lần gọi Procedure duy nhất, đảm bảo tính toàn vẹn dữ liệu.

*Event 2: Tính toán công nợ thời gian thực
```
-- Xóa hàm cũ nếu đã tồn tại để tránh lỗi trùng tên
IF OBJECT_ID('fn_CalcMoneyContract', 'FN') IS NOT NULL
    DROP FUNCTION fn_CalcMoneyContract;
GO

CREATE FUNCTION fn_CalcMoneyContract (@ContractID INT, @TargetDate DATE)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @Goc DECIMAL(18,2), @NgayVay DATE, @D1 DATE, @TongNo DECIMAL(18,2);
    
    -- Lấy thông tin gốc và ngày mốc từ Hợp đồng 
    SELECT @Goc = TienGoc, @NgayVay = NgayVay, @D1 = Deadline1 
    FROM HopDong WHERE MaHD = @ContractID;

    -- 1. Tính Lãi Đơn (5.000đ/1tr/ngày = 0.5%/ngày) [cite: 11]
    DECLARE @NgayKetThucLaiDon DATE = CASE WHEN @TargetDate < @D1 THEN @TargetDate ELSE @D1 END;
    DECLARE @SoNgayLaiDon INT = DATEDIFF(DAY, @NgayVay, @NgayKetThucLaiDon);
    IF @SoNgayLaiDon < 0 SET @SoNgayLaiDon = 0;
    
    DECLARE @GiaTriLaiDon DECIMAL(18,2) = @SoNgayLaiDon * (@Goc * 0.005);

    -- 2. Tính Lãi Kép (Nếu quá Deadline 1) [cite: 12, 32]
    IF (@TargetDate <= @D1)
    BEGIN
        SET @TongNo = @Goc + @GiaTriLaiDon;
    END
    ELSE
    BEGIN
        DECLARE @SoNgayLaiKep INT = DATEDIFF(DAY, @D1, @TargetDate);
        -- Công thức lãi kép: (Gốc + Lãi đơn) * (1 + 0.5%)^n [cite: 12, 32]
        SET @TongNo = (@Goc + @GiaTriLaiDon) * POWER(1.005, @SoNgayLaiKep);
    END

    -- 3. Trừ đi số tiền đã trả trong Log để ra dư nợ hiện tại [cite: 14, 51]
    DECLARE @DaTra DECIMAL(18,2) = (SELECT ISNULL(SUM(SoTienTra), 0) FROM LogThanhToan WHERE MaHD = @ContractID);
    
    RETURN ROUND(@TongNo - @DaTra, 0);
END;
GO
```
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/f615a174-01ff-4a42-8a3e-e6e09f813dbd" />
Hàm sử dụng POWER để tính lũy thừa cho lãi kép theo đúng gợi ý của đề bài. Việc trừ đi SUM(SoTienTra) giúp quản lý nợ theo thời gian thực chính xác.

*Event 3: Xử lý trả nợ và hoàn trả tài sản
```
CREATE PROCEDURE sp_ProcessPayment
    @ContractID INT,
    @AmountPaid DECIMAL(18,2),
    @StaffName NVARCHAR(50)
AS
BEGIN
    -- Kiểm tra tài sản đã thanh lý chưa
    IF EXISTS (SELECT 1 FROM TaiSan WHERE ContractID = @ContractID AND TrangThai = N'Đã bán thanh lý')
    BEGIN
        PRINT N'Tài sản đã bị thanh lý, không thu tiền.';
        RETURN;
    END

    -- Ghi Log giao dịch
    INSERT INTO Log (ContractID, NgayTra, SoTienTra, NguoiThu)
    VALUES (@ContractID, GETDATE(), @AmountPaid, @StaffName);

    -- Tính dư nợ và cập nhật trạng thái
    DECLARE @TongNo DECIMAL(18,2) = dbo.fn_CalcMoneyContract(@ContractID, GETDATE());
    
    IF @AmountPaid >= @TongNo
        UPDATE HopDong SET TrangThai = N'Đã thanh toán đủ' WHERE ContractID = @ContractID;
    ELSE
        UPDATE HopDong SET TrangThai = N'Đang trả góp' WHERE ContractID = @ContractID;

    -- Gợi ý trả đồ: Tổng giá trị tài sản còn lại >= Dư nợ [cite: 40]
    SELECT TenTaiSan, GiaTriDinhGia 
    FROM TaiSan 
    WHERE ContractID = @ContractID AND TrangThai = N'Đang cầm cố'
    ORDER BY GiaTriDinhGia ASC; 
END;
```
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/dedf734a-2ff1-4f3e-abf5-98e786ebe575" />
Procedure này tuân thủ nghiêm ngặt quy tắc không thu tiền khi đồ đã bán thanh lý và đảm bảo mọi biến động số tiền đều được lưu vết.

* Event 4: Truy vấn danh sách nợ xấu (Nợ khó đòi)
```
-- Tạo bảng Khách hàng
CREATE TABLE KháchHàng (
    KhachHangID INT PRIMARY KEY IDENTITY(1,1),
    TenKH NVARCHAR(100),
    SoDienThoai VARCHAR(15)
);

-- Tạo bảng Hợp đồng
CREATE TABLE HợpĐồng (
    ContractID INT PRIMARY KEY IDENTITY(1,1),
    KhachHangID INT FOREIGN KEY REFERENCES KháchHàng(KhachHangID),
    SoTienVayGoc DECIMAL(18,2),
    NgayVay DATE,
    Deadline1 DATE,
    Deadline2 DATE,
    TrangThai NVARCHAR(50) -- Đang vay, Quá hạn, Đã thanh toán, Đã thanh lý
);

-- Tạo bảng Tài sản
CREATE TABLE TàiSản (
    TaiSanID INT PRIMARY KEY IDENTITY(1,1),
    ContractID INT FOREIGN KEY REFERENCES HợpĐồng(ContractID),
    TenTaiSan NVARCHAR(100),
    GiaTriDinhGia DECIMAL(18,2),
    TrangThai NVARCHAR(50), -- Đang cầm cố, Đã trả khách, Sẵn sàng thanh lý, Đã bán thanh lý
    IsSold BIT DEFAULT 0
);

-- Tạo bảng Log lịch sử
CREATE TABLE Log (
    LogID INT PRIMARY KEY IDENTITY(1,1),
    ContractID INT FOREIGN KEY REFERENCES HợpĐồng(ContractID),
    NgayTra DATETIME,
    SoTienTra DECIMAL(18,2),
    NguoiThu NVARCHAR(50)
);
```
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/e628814e-8b82-4cfe-b966-402f83e4604f" />
Thiết lập khóa ngoại đầy đủ để đảm bảo tính tham chiếu giữa Khách hàng, Hợp đồng và Tài sản.

* Event 5: Quản lý thanh lý tài sản
```
CREATE TRIGGER trg_AutoUpdateBadDebt
ON HopDong
AFTER UPDATE
AS
BEGIN
    -- Chặn đệ quy (Nếu Trigger tự gọi chính nó thì dừng)
    IF TRIGGER_NESTLEVEL() > 1 RETURN;

    -- Chỉ cập nhật những hợp đồng 'Đang vay' mà quá Deadline 1
    UPDATE HopDong
    SET TrangThai = N'Quá hạn (nợ xấu)'
    FROM HopDong H
    INNER JOIN inserted i ON H.ContractID = i.ContractID
    WHERE GETDATE() > i.Deadline1 
      AND H.TrangThai = N'Đang vay'; 
END;
```
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/58db6666-cf23-406e-ae62-284329c32bd0" />
Việc kiểm tra H.TrangThai = N'Đang vay' là điều kiện dừng cực kỳ quan trọng để SQL không bị treo khi cập nhật trạng thái.

# 4. Các sự kiện bổ sung
* Yêu cầu: Khách đóng hết lãi cũ để dời ngày trả nợ (Deadline) sang kỳ hạn mới, tránh bị tính lãi kép.
```
IF OBJECT_ID('sp_GiaHanHopDong', 'P') IS NOT NULL DROP PROCEDURE sp_GiaHanHopDong;
GO

CREATE PROCEDURE sp_GiaHanHopDong
    @MaHD INT,
    @SoThangGiaHan INT, -- Số tháng muốn gia hạn thêm
    @NguoiThucHien NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- 1. Tính số lãi khách đang nợ đến ngày hôm nay
        DECLARE @TienGoc DECIMAL(18,2), @TongNoHienTai DECIMAL(18,2);
        SELECT @TienGoc = TienGoc FROM HopDong WHERE MaHD = @MaHD;
        
        -- Gọi function đã viết ở Event 2 để tính nợ
        SET @TongNoHienTai = dbo.fn_CalcMoneyContract(@MaHD, CAST(GETDATE() AS DATE));
        
        DECLARE @TienLaiPhaiDong DECIMAL(18,2) = @TongNoHienTai - @TienGoc;

        -- 2. Ghi nhận việc đóng lãi vào bảng Log (Audit Log)
        IF (@TienLaiPhaiDong > 0)
        BEGIN
            INSERT INTO LogThanhToan (MaHD, SoTienTra, GhiChu)
            VALUES (@MaHD, @TienLaiPhaiDong, N'Đóng lãi gia hạn - NV: ' + @NguoiThucHien);
        END

        -- 3. Cập nhật các mốc thời gian mới
        -- Deadline 1 mới tính từ ngày hôm nay + số tháng gia hạn
        UPDATE HopDong
        SET Deadline1 = DATEADD(MONTH, @SoThangGiaHan, GETDATE()),
            Deadline2 = DATEADD(MONTH, @SoThangGiaHan + 1, GETDATE()), -- Deadline 2 thường sau 1 tháng
            NgayVay = GETDATE(), -- Reset ngày vay về hiện tại để bắt đầu tính lãi đơn mới trên gốc cũ
            TrangThai = N'Đang vay'
        WHERE MaHD = @MaHD;

        COMMIT TRANSACTION;
        PRINT N'Gia hạn thành công cho HĐ ' + CAST(@MaHD AS NVARCHAR(10));
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT N'Lỗi gia hạn: ' + ERROR_MESSAGE();
    END CATCH
END;
GO
```
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/5565806e-7b34-4d0c-b692-d1e89ebfc37a" />
kết quả

*Yêu cầu: Lưu vết mọi lần trả tiền để không mất dấu dòng tiền. Phần này mình tạo một View báo cáo để Hằng dễ dàng trình bày trong báo cáo PDF.
```
CREATE TRIGGER trg_AssetReadyToSell
ON HopDong
AFTER UPDATE
AS
BEGIN
    -- Cập nhật bảng TaiSan dựa trên trạng thái của bảng HopDong
    UPDATE TaiSan
    SET TrangThai = N'Sẵn sàng thanh lý'
    FROM TaiSan T
    INNER JOIN inserted i ON T.ContractID = i.ContractID
    WHERE GETDATE() > i.Deadline2 
      AND i.TrangThai = N'Quá hạn (nợ xấu)';
END;
```
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/a94cbc0d-7d36-41fd-bc0f-4314b4b43dde" />
Kết quả
