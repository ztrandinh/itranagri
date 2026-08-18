import { Page } from "@/components/withSession"; import DuTru from "@/components/panels/DuTru";
export default function P() { return <Page title="Dự trữ — kho đầu vào · kho đầu ra · kho công cụ theo khu vực">{(s) => <DuTru sess={s} />}</Page>; }
