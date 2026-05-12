
<div id="erd"></div>
<style>
#erd { padding: 8px 0; }
#erd svg { width: 100%; }
</style>
<script type="module">
import mermaid from 'https://esm.sh/mermaid@11/dist/mermaid.esm.min.mjs';
const dark = matchMedia('(prefers-color-scheme: dark)').matches;
await document.fonts.ready;
mermaid.initialize({
  startOnLoad: false,
  theme: 'base',
  fontFamily: '"Anthropic Sans", sans-serif',
  themeVariables: {
    darkMode: dark,
    fontSize: '13px',
    fontFamily: '"Anthropic Sans", sans-serif',
    lineColor: dark ? '#9c9a92' : '#73726c',
    textColor: dark ? '#c2c0b6' : '#3d3d3a',
    primaryColor: dark ? '#2a2a3a' : '#e8e6fb',
    primaryBorderColor: dark ? '#534AB7' : '#7F77DD',
    primaryTextColor: dark ? '#c2c0b6' : '#26215C',
    secondaryColor: dark ? '#1a2a2a' : '#e1f5ee',
    secondaryBorderColor: dark ? '#0F6E56' : '#1D9E75',
    tertiaryColor: dark ? '#2a1a1a' : '#faeeda',
    tertiaryBorderColor: dark ? '#854F0B' : '#BA7517',
  },
});

const diagram = `erDiagram
  KhachHang {
    int MaKH PK
    nvarchar HoTen
    varchar SoDienThoai
    varchar CCCD
    nvarchar DiaChi
  }
  HopDong {
    int MaHD PK
    int MaKH FK
    datetime NgayVay
    decimal SoTienGoc
    date Deadline1
    date Deadline2
    nvarchar TrangThai
  }
  TaiSan {
    int MaTS PK
    int MaHD FK
    nvarchar TenTaiSan
    decimal GiaTriDinhGia
    nvarchar TrangThaiTS
    nvarchar MoTa
  }
  NhanVien {
    int MaNV PK
    nvarchar HoTen
    varchar SoDienThoai
    nvarchar ChucVu
  }
  LogBienDong {
    int MaLog PK
    int MaHD FK
    int MaNV FK
    datetime NgayGiaoDich
    decimal SoTienTra
    decimal DuNoSauKhiTra
    nvarchar NoiDung
  }

  KhachHang ||--o{ HopDong : "co"
  HopDong ||--o{ TaiSan : "cam_co"
  HopDong ||--o{ LogBienDong : "phat_sinh"
  NhanVien ||--o{ LogBienDong : "thu_tien"
`;

const { svg } = await mermaid.render('erd-svg', diagram);
document.getElementById('erd').innerHTML = svg;

document.querySelectorAll('#erd svg .node').forEach(node => {
  const firstPath = node.querySelector('path[d]');
  if (!firstPath) return;
  const d = firstPath.getAttribute('d');
  const nums = d.match(/-?[\d.]+/g)?.map(Number);
  if (!nums || nums.length < 8) return;
  const xs = [nums[0], nums[2], nums[4], nums[6]];
  const ys = [nums[1], nums[3], nums[5], nums[7]];
  const x = Math.min(...xs), y = Math.min(...ys);
  const w = Math.max(...xs) - x, h = Math.max(...ys) - y;
  const rect = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
  rect.setAttribute('x', x); rect.setAttribute('y', y);
  rect.setAttribute('width', w); rect.setAttribute('height', h);
  rect.setAttribute('rx', '8');
  for (const a of ['fill', 'stroke', 'stroke-width', 'class', 'style']) {
    if (firstPath.hasAttribute(a)) rect.setAttribute(a, firstPath.getAttribute(a));
  }
  firstPath.replaceWith(rect);
});

document.querySelectorAll('#erd svg .row-rect-odd path, #erd svg .row-rect-even path').forEach(p => {
  p.setAttribute('stroke', 'none');
});
</script>
