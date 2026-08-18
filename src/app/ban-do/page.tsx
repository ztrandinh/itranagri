import { Page } from "@/components/withSession"; import { MapPanel } from "@/components/panels/More";
export default function P() { return <Page title="Bản đồ trại — ô thửa · khu · trạng thái">{(s) => <MapPanel sess={s} />}</Page>; }
