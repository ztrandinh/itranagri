import io
R="F:/ITRAN FARM/itran-os/"
def rw(p, fn): s=io.open(R+p,encoding="utf-8").read(); n=fn(s); assert n!=s, p; io.open(R+p,"w",encoding="utf-8",newline="\n").write(n); print("ok",p)
STD='onChange={(k) => setTab(k as typeof tab)} />'

# 1) Ops.tsx BanHangPanel → OrderMarginPanel (tab "margin")
def ops(s):
    s=s.replace('import { useData, act, fmt } from "@/lib/client";','import { useData, act, fmt } from "@/lib/client";\nimport { OrderMarginPanel } from "@/components/panels/CloseoutBits";',1)
    s=s.replace('"gia" | "bg" | "ct" | "diem" | "no" | "lich">','"gia" | "bg" | "ct" | "diem" | "no" | "lich" | "margin">',1)
    s=s.replace('["no", "Bán hàng · Công nợ KH & nhắc nợ"]','["no", "Bán hàng · Công nợ KH & nhắc nợ"], ["margin", "💰 Lãi gộp theo đơn (giá vốn)"]',1)
    s=s.replace('      <Tabs items={[["ban", "Bán hàng · Bán / giao"], ["don"', '      {/*margin-tab*/}\n      <Tabs items={[["ban", "Bán hàng · Bán / giao"], ["don"',1)  # marker no-op safeguard
    s=s.replace(STD, STD+'\n      {tab === "margin" && <OrderMarginPanel sess={sess} />}',1)
    return s
rw("src/components/panels/Ops.tsx", ops)

# 2) FinanceMore → BankReconPanel (tab "bank")
def fin(s):
    s=s.replace('import { useData, act, fmt } from "@/lib/client";','import { useData, act, fmt } from "@/lib/client";\nimport { BankReconPanel } from "@/components/panels/CloseoutBits";',1)
    s=s.replace('"thue" | "lich" | "hopnhat">','"thue" | "lich" | "hopnhat" | "bank">',1)
    s=s.replace('["lich", "📆 Lịch thanh toán 13 tuần"]','["lich", "📆 Lịch thanh toán 13 tuần"], ["bank", "🏦 Sao kê & đối chiếu"]',1)
    s=s.replace(STD, STD+'\n    {tab === "bank" && <BankReconPanel sess={sess} />}',1)
    return s
rw("src/components/panels/FinanceMore.tsx", fin)

# 3) CheBien → QcHoldPanel (tab "qc")
def cb(s):
    s=s.replace('import { useData, act, fmt } from "@/lib/client";','import { useData, act, fmt } from "@/lib/client";\nimport { QcHoldPanel } from "@/components/panels/CloseoutBits";',1)
    s=s.replace('"baobi" | "nhan" | "tem" | "me">','"baobi" | "nhan" | "tem" | "me" | "qc">',1)
    s=s.replace('["me", ','["qc", "🔬 Giữ lô QC"], ["me", ',1)
    s=s.replace(STD, STD+'\n      {tab === "qc" && <QcHoldPanel sess={sess} />}',1)
    return s
rw("src/components/panels/CheBien.tsx", cb)

# 4) MuaHang → SupplierReturnPanel (tab "tra")
def mh(s):
    s=s.replace('import { useData, act, fmt } from "@/lib/client";','import { useData, act, fmt } from "@/lib/client";\nimport { SupplierReturnPanel } from "@/components/panels/CloseoutBits";',1)
    s=s.replace('"goiy" | "tao" | "ds" | "nhan" | "bieudo">','"goiy" | "tao" | "ds" | "nhan" | "bieudo" | "tra">',1)
    s=s.replace('["bieudo", ','["tra", "↩ Trả nhà cung cấp"], ["bieudo", ',1)
    s=s.replace(STD, STD+'\n    {tab === "tra" && <SupplierReturnPanel sess={sess} />}',1)
    return s
rw("src/components/panels/MuaHang.tsx", mh)

# 5) KeHoachNam → LaborBudgetPanel (tab "luong")
def kh(s):
    s=s.replace('import { useData, act, fmt } from "@/lib/client";','import { useData, act, fmt } from "@/lib/client";\nimport { LaborBudgetPanel } from "@/components/panels/CloseoutBits";',1)
    s=s.replace('"dan" | "vu" | "cungcau" | "khtt">','"dan" | "vu" | "cungcau" | "khtt" | "luong">',1)
    s=s.replace('["khtt", ','["luong", "👥 Quỹ lương KH vs thực"], ["khtt", ',1)
    s=s.replace('    {tab === "cungcau" && <SupplyPlan sess={sess} />}','    {tab === "cungcau" && <SupplyPlan sess={sess} />}\n    {tab === "luong" && <LaborBudgetPanel sess={sess} />}',1)
    return s
rw("src/components/panels/KeHoachNam.tsx", kh)
