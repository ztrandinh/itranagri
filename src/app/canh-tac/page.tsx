import { Page } from "@/components/withSession"; import CanhTac from "@/components/panels/CanhTac";
export default function P() { return <Page title="Canh tác — hồ sơ mùa vụ · vật tư & PHI · thu hoạch">{(s) => <CanhTac sess={s} />}</Page>; }
