import { Page } from "@/components/withSession";
import CaPanel from "@/components/CaPanel";
export default function Ca() { return <Page title="Ca của tôi">{(s) => <CaPanel sess={s} />}</Page>; }
