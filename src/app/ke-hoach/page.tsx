import { Page } from "@/components/withSession"; import { KeHoachPanel } from "@/components/panels/Depts";
export default function P() { return <Page title="Kế hoạch — Năm · S&OP 12 tháng · đàn theo lứa · lịch vụ · ban hành việc · KH–TT">{(s) => <KeHoachPanel sess={s} />}</Page>; }
