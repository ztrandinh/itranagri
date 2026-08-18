import { Page } from "@/components/withSession"; import Home from "@/components/panels/Home";
export default function P() { return <Page title="Trang chủ — chọn khu vực">{(s) => <Home sess={s} />}</Page>; }
