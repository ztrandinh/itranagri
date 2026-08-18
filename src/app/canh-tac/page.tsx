import { Page } from "@/components/withSession"; import CanhTac from "@/components/panels/CanhTac";
export default function P() { return <Page title="Trồng trọt — mùa vụ · vật tư PHI · thu hoạch · tưới/ET0 · đất/IPM · luân canh · giá thành ô">{(s) => <CanhTac sess={s} />}</Page>; }
