import { Page } from "@/components/withSession"; import { KeHoachPanel } from "@/components/panels/Depts";
export default function P() { return <Page title="Kế hoạch — vụ · cho ăn (KH vs thực)">{(s) => <KeHoachPanel sess={s} />}</Page>; }
