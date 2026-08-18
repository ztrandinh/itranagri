import { Page } from "@/components/withSession"; import { GdPanel } from "@/components/panels/Dashboards";
export default function P() { return <Page title="Giám đốc — 15 phút sáng · 1 trang thứ 6">{(s) => <GdPanel sess={s} />}</Page>; }
