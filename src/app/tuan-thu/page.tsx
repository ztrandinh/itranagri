import { Page } from "@/components/withSession"; import TuanThu from "@/components/panels/TuanThu";
export default function P() { return <Page title="Tuân thủ tiêu chuẩn & chứng nhận — VietGAP · GlobalG.A.P. · ISO 22000/HACCP · Halal · Hữu cơ EU/USDA/JAS · ASC · thị trường TQ/Hàn">{(s) => <TuanThu sess={s} />}</Page>; }
