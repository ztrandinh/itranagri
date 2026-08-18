import { Page } from "@/components/withSession"; import PheDuyet from "@/components/panels/PheDuyet";
export default function P() { return <Page title="Phê duyệt — mọi thứ đang chờ tôi">{(s) => <PheDuyet sess={s} />}</Page>; }
