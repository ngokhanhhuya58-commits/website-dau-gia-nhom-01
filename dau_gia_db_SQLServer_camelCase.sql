
IF DB_ID(N'dau_gia_online') IS NOT NULL
BEGIN
    ALTER DATABASE dau_gia_online SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dau_gia_online;
END;
GO
CREATE DATABASE dau_gia_online;
GO
USE dau_gia_online;
GO


CREATE TABLE vaiTro (
    id           TINYINT IDENTITY(1,1) NOT NULL,
    tenVaiTro  NVARCHAR(30)  NOT NULL,           -- ADMIN, NGUOI_DUNG
    moTa        NVARCHAR(255) NULL,
    PRIMARY KEY (id),
    CONSTRAINT uqVaiTroTen UNIQUE (tenVaiTro)
);
GO

CREATE TABLE taiKhoan (
    id                    INT IDENTITY(1,1) NOT NULL,
    vaiTroId            TINYINT NOT NULL,
    tenDangNhap         NVARCHAR(50)  NOT NULL,
    email                 NVARCHAR(100) NOT NULL,
    matKhau              NVARCHAR(255) NOT NULL,  -- lưu HASH (PHP: password_hash), không lưu mật khẩu thô
    trangThai            NVARCHAR(50) NOT NULL DEFAULT 'hoat_dong',
    soLanDangNhapSai  TINYINT NOT NULL DEFAULT 0,   -- sai 3 lần -> khóa
    lyDoKhoa            NVARCHAR(255) NULL,
    ngayTao              DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    ngayCapNhat         DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    PRIMARY KEY (id),
    CONSTRAINT uqTaiKhoanTenDangNhap UNIQUE (tenDangNhap),
    CONSTRAINT uqTaiKhoanEmail UNIQUE (email),
    CONSTRAINT fkTaiKhoanVaiTro FOREIGN KEY (vaiTroId) REFERENCES vaiTro (id),
    CONSTRAINT ck_taiKhoan_trangThai CHECK (trangThai IN ('hoat_dong','bi_khoa'))
);
GO

CREATE TABLE nguoiDung (
    id             INT IDENTITY(1,1) NOT NULL,
    taiKhoanId   INT NOT NULL,
    hoTen         NVARCHAR(100) NOT NULL,
    soDienThoai  NVARCHAR(15)  NULL,
    diaChi        NVARCHAR(255) NULL,
    anhDaiDien   NVARCHAR(255) NULL,
    soDu          DECIMAL(15,2) NOT NULL DEFAULT 0,   -- số dư ví để đấu giá / đặt cọc
    PRIMARY KEY (id),
    CONSTRAINT uqNguoiDungTaiKhoan UNIQUE (taiKhoanId),
    CONSTRAINT fkNguoiDungTaiKhoan FOREIGN KEY (taiKhoanId) REFERENCES taiKhoan (id) ON DELETE CASCADE,
    CONSTRAINT ckNguoiDungSoDu CHECK (soDu >= 0)
);
GO

-- Yêu cầu "Lấy lại mật khẩu": lưu mã xác nhận, khóa 30 phút nếu nhập sai quá 5 lần
CREATE TABLE yeuCauDatLaiMatKhau (
    id            INT IDENTITY(1,1) NOT NULL,
    taiKhoanId  INT NOT NULL,
    maXacNhan   NVARCHAR(100) NOT NULL,            -- lưu dạng hash
    hetHan       DATETIME2 NOT NULL,
    daSuDung    BIT NOT NULL DEFAULT 0,
    soLanSai    TINYINT NOT NULL DEFAULT 0,
    khoaDen      DATETIME2 NULL,
    ngayTao      DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    PRIMARY KEY (id),
    CONSTRAINT fkDatLaiMkTaiKhoan FOREIGN KEY (taiKhoanId) REFERENCES taiKhoan (id) ON DELETE CASCADE
);
GO

-- ---------------------------------------------------------------------
-- 2. DANH MỤC, KHU VỰC, SẢN PHẨM
-- ---------------------------------------------------------------------
CREATE TABLE danhMuc (
    id         INT IDENTITY(1,1) NOT NULL,
    tenDanhMuc NVARCHAR(100) NOT NULL,
    moTa      NVARCHAR(255) NULL,
    PRIMARY KEY (id),
    CONSTRAINT uqDanhMucTen UNIQUE (tenDanhMuc)
);
GO

CREATE TABLE khuVuc (
                               -- phục vụ "Tìm kiếm theo khu vực"
    id         INT IDENTITY(1,1) NOT NULL,
    tenKhuVuc NVARCHAR(100) NOT NULL,               -- tỉnh/thành phố
    PRIMARY KEY (id),
    CONSTRAINT uqKhuVucTen UNIQUE (tenKhuVuc)
);
GO

CREATE TABLE sanPham (
    id             INT IDENTITY(1,1) NOT NULL,
    nguoiBanId   INT NOT NULL,
    danhMucId    INT NOT NULL,
    khuVucId     INT NULL,
    tenSanPham   NVARCHAR(200) NOT NULL,
    moTa          NVARCHAR(MAX) NULL,
    daXoa         BIT NOT NULL DEFAULT 0,    -- admin xóa mềm sản phẩm vi phạm
    ngayTao       DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    ngayCapNhat  DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    PRIMARY KEY (id),
    CONSTRAINT fkSanPhamNguoiBan FOREIGN KEY (nguoiBanId) REFERENCES nguoiDung (id),
    CONSTRAINT fkSanPhamDanhMuc  FOREIGN KEY (danhMucId)  REFERENCES danhMuc (id),
    CONSTRAINT fkSanPhamKhuVuc   FOREIGN KEY (khuVucId)   REFERENCES khuVuc (id)
);
GO

CREATE TABLE hinhAnhSanPham (
    id          INT IDENTITY(1,1) NOT NULL,
    sanPhamId INT NOT NULL,
    duongDan   NVARCHAR(255) NOT NULL,
    loai        NVARCHAR(50) NOT NULL DEFAULT 'hinh_anh',  -- ảnh hoặc giấy tờ liên quan
    laAnhChinh BIT NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CONSTRAINT fkHinhAnhSanPham FOREIGN KEY (sanPhamId) REFERENCES sanPham (id) ON DELETE CASCADE,
    CONSTRAINT ck_hinhAnhSanPham_loai CHECK (loai IN ('hinh_anh','giay_to'))
);
GO

CREATE TABLE yeuThich (
    nguoiDungId INT NOT NULL,
    sanPhamId   INT NOT NULL,
    ngayThem     DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    PRIMARY KEY (nguoiDungId, sanPhamId),
    CONSTRAINT fkYeuThichNguoiDung FOREIGN KEY (nguoiDungId) REFERENCES nguoiDung (id) ON DELETE CASCADE,
    CONSTRAINT fkYeuThichSanPham   FOREIGN KEY (sanPhamId)   REFERENCES sanPham (id)   ON DELETE CASCADE
);
GO

-- ---------------------------------------------------------------------
-- 3. PHIÊN ĐẤU GIÁ & LƯỢT ĐẤU GIÁ
-- ---------------------------------------------------------------------
CREATE TABLE phienDauGia (
    id                 INT IDENTITY(1,1) NOT NULL,
    sanPhamId        INT NOT NULL,
    giaKhoiDiem      DECIMAL(15,2) NOT NULL,
    buocGiaToiThieu DECIMAL(15,2) NOT NULL,
    giaHienTai       DECIMAL(15,2) NOT NULL,        -- = gia_khoi_diem khi chưa có lượt đặt
    thoiGianBatDau  DATETIME2 NOT NULL,
    thoiGianKetThuc DATETIME2 NOT NULL,
    trangThai         NVARCHAR(50)
                       NOT NULL DEFAULT 'cho_duyet',
    lyDoTuChoi      NVARCHAR(500) NULL,
    quanTriDuyetId  INT NULL,             -- admin duyệt/từ chối (tài khoản)
    ngayDuyet         DATETIME2 NULL,
    nguoiThangId     INT NULL,             -- người thắng cuộc khi kết thúc
    giaTrung          DECIMAL(15,2) NULL,
    ngayTao           DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    PRIMARY KEY (id),
    CONSTRAINT uqPhienSanPham UNIQUE (sanPhamId),
    CONSTRAINT fkPhienSanPham   FOREIGN KEY (sanPhamId)       REFERENCES sanPham (id) ON DELETE CASCADE,
    CONSTRAINT fkPhienQuanTri   FOREIGN KEY (quanTriDuyetId) REFERENCES taiKhoan (id),
    CONSTRAINT fkPhienNguoiThang FOREIGN KEY (nguoiThangId)   REFERENCES nguoiDung (id),
    CONSTRAINT ckPhienGia      CHECK (giaKhoiDiem > 0 AND buocGiaToiThieu > 0 AND giaHienTai >= giaKhoiDiem),
    CONSTRAINT ckPhienThoiGian CHECK (thoiGianKetThuc > thoiGianBatDau),
    CONSTRAINT ck_phienDauGia_trangThai CHECK (trangThai IN ('cho_duyet','bi_tu_choi','sap_dien_ra','dang_dien_ra','ket_thuc','da_huy'))
);
GO

CREATE TABLE luotDauGia (
    id             BIGINT IDENTITY(1,1) NOT NULL,
    phienDauGiaId INT NOT NULL,
    nguoiDungId  INT NOT NULL,
    soTien        DECIMAL(15,2) NOT NULL,
    thoiGianDat  DATETIME2(3) NOT NULL DEFAULT SYSDATETIME(),
    laGiaDanDau BIT NOT NULL DEFAULT 0,     -- lượt đang dẫn đầu / thắng
    PRIMARY KEY (id),
    CONSTRAINT fkLuotPhien      FOREIGN KEY (phienDauGiaId) REFERENCES phienDauGia (id) ON DELETE CASCADE,
    CONSTRAINT fkLuotNguoiDung FOREIGN KEY (nguoiDungId)    REFERENCES nguoiDung (id),
    CONSTRAINT ckLuotSoTien CHECK (soTien > 0)
);
GO

-- ---------------------------------------------------------------------
-- 4. VÍ, NẠP TIỀN, ĐƠN HÀNG, THANH TOÁN
-- ---------------------------------------------------------------------
CREATE TABLE napTien (
    id            INT IDENTITY(1,1) NOT NULL,
    nguoiDungId INT NOT NULL,
    soTien       DECIMAL(15,2) NOT NULL,
    phuongThuc   NVARCHAR(50) NOT NULL,               -- ví dụ: chuyển khoản, QR, ví điện tử
    maGiaoDich  NVARCHAR(100) NULL,
    trangThai    NVARCHAR(50) NOT NULL DEFAULT 'cho_xu_ly',
    thoiGian     DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    PRIMARY KEY (id),
    CONSTRAINT fkNapTienNguoiDung FOREIGN KEY (nguoiDungId) REFERENCES nguoiDung (id),
    CONSTRAINT ckNapTienSoTien CHECK (soTien > 0),
    CONSTRAINT ck_napTien_trangThai CHECK (trangThai IN ('cho_xu_ly','thanh_cong','that_bai'))
);
GO

-- Đơn hàng (lớp HoaDon trong sơ đồ lớp của nhóm): sinh ra khi phiên đấu giá có người thắng
CREATE TABLE donHang (
    id               INT IDENTITY(1,1) NOT NULL,
    phienDauGiaId INT NOT NULL,
    nguoiMuaId     INT NOT NULL,
    nguoiBanId     INT NOT NULL,
    giaTrung        DECIMAL(15,2) NOT NULL,
    tienCoc         DECIMAL(15,2) NOT NULL,          -- 70% giá trúng
    tienConLai     DECIMAL(15,2) NOT NULL,          -- 30% giá trúng
    tenNguoiNhan   NVARCHAR(100) NULL,
    sdtNguoiNhan   NVARCHAR(15)  NULL,
    diaChiGiaoHang NVARCHAR(255) NULL,
    trangThaiThanhToan NVARCHAR(50)
                          NOT NULL DEFAULT 'chua_coc',
    trangThaiGiaoHang  NVARCHAR(50)
                          NOT NULL DEFAULT 'chua_giao',
    ngayTao         DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    ngayCapNhat    DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    PRIMARY KEY (id),
    CONSTRAINT uqDonHangPhien UNIQUE (phienDauGiaId),
    CONSTRAINT fkDonHangPhien      FOREIGN KEY (phienDauGiaId) REFERENCES phienDauGia (id),
    CONSTRAINT fkDonHangNguoiMua  FOREIGN KEY (nguoiMuaId)     REFERENCES nguoiDung (id),
    CONSTRAINT fkDonHangNguoiBan  FOREIGN KEY (nguoiBanId)     REFERENCES nguoiDung (id),
    CONSTRAINT ckDonHangTien CHECK (giaTrung > 0 AND tienCoc >= 0 AND tienConLai >= 0
                                       AND tienCoc + tienConLai = giaTrung),
    CONSTRAINT ck_donHang_trangThaiThanhToan CHECK (trangThaiThanhToan IN ('chua_coc','da_coc','da_thanh_toan_du','da_hoan_tien')),
    CONSTRAINT ck_donHang_trangThaiGiaoHang CHECK (trangThaiGiaoHang IN ('chua_giao','dang_giao','da_nhan_hang','da_hoan_tra'))
);
GO

CREATE TABLE thanhToan (
    id            INT IDENTITY(1,1) NOT NULL,
    donHangId   INT NOT NULL,
    nguoiDungId INT NOT NULL,
    loaiThanhToan NVARCHAR(50) NOT NULL,
    soTien       DECIMAL(15,2) NOT NULL,
    trangThai    NVARCHAR(50) NOT NULL DEFAULT 'thanh_cong',
    thoiGian     DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    PRIMARY KEY (id),
    CONSTRAINT fkThanhToanDonHang  FOREIGN KEY (donHangId)   REFERENCES donHang (id),
    CONSTRAINT fkThanhToanNguoiDung FOREIGN KEY (nguoiDungId) REFERENCES nguoiDung (id),
    CONSTRAINT ckThanhToanSoTien CHECK (soTien > 0),
    CONSTRAINT ck_thanhToan_loaiThanhToan CHECK (loaiThanhToan IN ('dat_coc','thanh_toan_con_lai','hoan_tien')),
    CONSTRAINT ck_thanhToan_trangThai CHECK (trangThai IN ('thanh_cong','that_bai'))
);
GO

-- ---------------------------------------------------------------------
-- 5. KHIẾU NẠI, ĐÁNH GIÁ WEBSITE, THÔNG BÁO, CẤU HÌNH
-- ---------------------------------------------------------------------
CREATE TABLE khieuNai (
    id              INT IDENTITY(1,1) NOT NULL,
    donHangId     INT NOT NULL,
    nguoiGuiId    INT NOT NULL,
    lyDo           NVARCHAR(255) NOT NULL,
    noiDung        NVARCHAR(MAX) NOT NULL,
    minhChung      NVARCHAR(255) NULL,                -- đường dẫn ảnh/tệp minh chứng
    trangThai      NVARCHAR(50) NOT NULL DEFAULT 'cho_xu_ly',
    lyDoGiaiQuyet NVARCHAR(500) NULL,
    quanTriXuLyId INT NULL,
    ngayGui        DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    ngayXuLy      DATETIME2 NULL,
    PRIMARY KEY (id),
    CONSTRAINT fkKhieuNaiDonHang  FOREIGN KEY (donHangId)       REFERENCES donHang (id),
    CONSTRAINT fkKhieuNaiNguoiGui FOREIGN KEY (nguoiGuiId)      REFERENCES nguoiDung (id),
    CONSTRAINT fkKhieuNaiQuanTri  FOREIGN KEY (quanTriXuLyId) REFERENCES taiKhoan (id),
    CONSTRAINT ck_khieuNai_trangThai CHECK (trangThai IN ('cho_xu_ly','hoan_tien','hoan_tra_san_pham','tu_choi'))
);
GO

CREATE TABLE danhGia (
                               -- đánh giá trang web (admin có thể ẩn)
    id            INT IDENTITY(1,1) NOT NULL,
    nguoiDungId INT NOT NULL,
    donHangId   INT NULL,                  -- tùy chọn: gắn với đơn hàng (0..1 như sơ đồ lớp)
    diem          TINYINT NOT NULL,
    nhanXet      NVARCHAR(1000) NULL,
    daAn         BIT NOT NULL DEFAULT 0,      -- 1 = bị ẩn do vi phạm
    ngayTao      DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    PRIMARY KEY (id),
    CONSTRAINT fkDanhGiaNguoiDung FOREIGN KEY (nguoiDungId) REFERENCES nguoiDung (id),
    CONSTRAINT fkDanhGiaDonHang   FOREIGN KEY (donHangId)   REFERENCES donHang (id),
    CONSTRAINT ckDanhGiaDiem CHECK (diem BETWEEN 1 AND 5)
);
GO

CREATE TABLE thongBao (
    id            BIGINT IDENTITY(1,1) NOT NULL,
    nguoiDungId INT NOT NULL,
    tieuDe       NVARCHAR(200) NOT NULL,
    noiDung      NVARCHAR(1000) NOT NULL,
    daDoc        BIT NOT NULL DEFAULT 0,
    ngayTao      DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    PRIMARY KEY (id),
    CONSTRAINT fkThongBaoNguoiDung FOREIGN KEY (nguoiDungId) REFERENCES nguoiDung (id) ON DELETE CASCADE
);
GO

-- Lớp HeThong: tham số cấu hình (tỷ lệ cọc, giới thiệu website...)
CREATE TABLE cauHinhHeThong (
    khoa      NVARCHAR(50)  NOT NULL,
    giaTri   NVARCHAR(1000) NOT NULL,
    moTa     NVARCHAR(255) NULL,
    PRIMARY KEY (khoa)
);
GO


-- ---------------------------------------------------------------------
GO
-- CAC INDEX PHU (SQL SERVER)
-- ---------------------------------------------------------------------
CREATE INDEX idxDatLaiMkTaiKhoan ON yeuCauDatLaiMatKhau (taiKhoanId);
CREATE INDEX idxSanPhamNguoiBan ON sanPham (nguoiBanId);
CREATE INDEX idxSanPhamDanhMuc ON sanPham (danhMucId);
CREATE INDEX idxSanPhamKhuVuc ON sanPham (khuVucId);
CREATE INDEX idxHinhAnhSanPham ON hinhAnhSanPham (sanPhamId);
CREATE INDEX idxPhienTrangThaiKetThuc ON phienDauGia (trangThai, thoiGianKetThuc);
CREATE INDEX idxLuotPhienGia ON luotDauGia (phienDauGiaId, soTien);
CREATE INDEX idxLuotNguoiDung ON luotDauGia (nguoiDungId, thoiGianDat);
CREATE INDEX idxNapTienNguoiDung ON napTien (nguoiDungId, thoiGian);
CREATE INDEX idxDonHangNguoiMua ON donHang (nguoiMuaId);
CREATE INDEX idxDonHangNguoiBan ON donHang (nguoiBanId);
CREATE INDEX idxThanhToanDonHang ON thanhToan (donHangId);
CREATE INDEX idxThanhToanNguoiDung ON thanhToan (nguoiDungId);
CREATE INDEX idxKhieuNaiDonHang ON khieuNai (donHangId);
CREATE INDEX idxKhieuNaiNguoiGui ON khieuNai (nguoiGuiId);
CREATE INDEX idxDanhGiaNguoiDung ON danhGia (nguoiDungId);
CREATE UNIQUE INDEX uqDanhGiaDonHang ON danhGia (donHangId) WHERE donHangId IS NOT NULL;
CREATE INDEX idxThongBaoNguoiDung ON thongBao (nguoiDungId, daDoc);

GO
-- ---------------------------------------------------------------------
-- 6. DỮ LIỆU KHỞI TẠO
-- ---------------------------------------------------------------------

GO
-- Trigger cap nhat ngayCapNhat tuong duong ON UPDATE CURRENT_TIMESTAMP cua MySQL
CREATE OR ALTER TRIGGER trg_taiKhoan_ngayCapNhat ON taiKhoan
AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    UPDATE tk SET ngayCapNhat = SYSDATETIME()
    FROM taiKhoan tk INNER JOIN inserted i ON tk.id = i.id;
END;
GO
CREATE OR ALTER TRIGGER trg_sanPham_ngayCapNhat ON sanPham
AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    UPDATE sp SET ngayCapNhat = SYSDATETIME()
    FROM sanPham sp INNER JOIN inserted i ON sp.id = i.id;
END;
GO
CREATE OR ALTER TRIGGER trg_donHang_ngayCapNhat ON donHang
AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dh SET ngayCapNhat = SYSDATETIME()
    FROM donHang dh INNER JOIN inserted i ON dh.id = i.id;
END;
GO

INSERT INTO vaiTro (tenVaiTro, moTa) VALUES
    ('ADMIN',      N'Người quản trị hệ thống'),
    ('NGUOI_DUNG', N'Người dùng có tài khoản (mua/bán/đấu giá)');
GO

INSERT INTO danhMuc (tenDanhMuc) VALUES
    (N'Điện thoại & Máy tính bảng'), (N'Laptop & Máy tính'), (N'Đồ điện tử'),
    (N'Thời trang & Phụ kiện'), (N'Đồ gia dụng'), (N'Xe cộ'),
    (N'Đồ sưu tầm & Nghệ thuật'), (N'Khác');
GO

INSERT INTO khuVuc (tenKhuVuc) VALUES
    (N'Hà Nội'), (N'TP. Hồ Chí Minh'), (N'Đà Nẵng'), (N'Bình Định'),
    (N'Hải Phòng'), (N'Cần Thơ'), (N'Khánh Hòa'), (N'Khác');
GO

INSERT INTO cauHinhHeThong (khoa, giaTri, moTa) VALUES
    ('ty_le_coc',             '70', N'Phần trăm tiền cọc người thắng phải trả sau khi thắng'),
    ('so_lan_dang_nhap_sai',  '3',  N'Số lần đăng nhập sai tối đa trước khi khóa tài khoản'),
    ('gioi_thieu_website',    N'Hệ thống đấu giá sản phẩm trực tuyến - Nhóm 01, Đại học Quy Nhơn', N'Nội dung trang giới thiệu');
GO

-- Tài khoản admin: tạo bằng PHP để có mật khẩu đã băm, ví dụ:
--   INSERT INTO tai_khoan (vai_tro_id, ten_dang_nhap, email, mat_khau)
--   VALUES (1, 'admin', 'admin@daugia.local', N'<kết quả password_hash()>');
GO
