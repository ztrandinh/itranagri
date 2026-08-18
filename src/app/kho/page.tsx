import { Page } from "@/components/withSession"; import KhoPanel from "@/components/panels/KhoPanel";
export default function P() { return <Page title="Kho & vận tải — 9 kho + kho công cụ · bin · FEFO · kiểm kê · ROP · kho lạnh · chuyến xe · NCC">{(s) => <KhoPanel sess={s} />}</Page>; }
