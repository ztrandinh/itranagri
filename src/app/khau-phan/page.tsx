import { Page } from "@/components/withSession"; import { RationPanel } from "@/components/panels/More";
export default function P() { return <Page title="Tối ưu khẩu phần giá rẻ nhất">{(s) => <RationPanel sess={s} />}</Page>; }
