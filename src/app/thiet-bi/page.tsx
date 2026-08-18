import { Page } from "@/components/withSession"; import { ThietBiPanel } from "@/components/panels/Depts";
export default function P() { return <Page title="Thiết bị – máy móc – IoT — giờ máy · bảo dưỡng · hiệu chuẩn · cảm biến">{(s) => <ThietBiPanel sess={s} />}</Page>; }
