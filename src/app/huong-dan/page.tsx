import { Page } from "@/components/withSession"; import HuongDan from "@/components/panels/HuongDan";
export default function P() { return <Page title="Hướng dẫn sử dụng theo vai">{(s) => <HuongDan sess={s} />}</Page>; }
