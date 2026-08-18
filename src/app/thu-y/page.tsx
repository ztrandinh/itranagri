import { Page } from "@/components/withSession"; import { ThuYPanel } from "@/components/panels/Depts";
export default function P() { return <Page title="Thú y — theo dõi · ngưng thuốc · vaccine · phác đồ">{(s) => <ThuYPanel sess={s} />}</Page>; }
