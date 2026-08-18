import { Page } from "@/components/withSession"; import { MapPanel } from "@/components/panels/More";
export default function P() { return <Page title="Bản đồ ô thửa ruộng — cây trồng · mùa vụ · trạng thái">{(s) => <MapPanel sess={s} />}</Page>; }
