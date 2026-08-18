import { Page } from "@/components/withSession"; import { ThuYPanel } from "@/components/panels/Depts";
export default function P() { return <Page title="Thú y & sức khỏe đàn — theo dõi · ngưng thuốc · vaccine · phác đồ · dịch tễ">{(s) => <ThuYPanel sess={s} />}</Page>; }
