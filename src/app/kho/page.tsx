import { Page } from "@/components/withSession"; import KhoPanel from "@/components/panels/KhoPanel";
export default function P() { return <Page title="Kho K1–K9 · sổ cái tự động">{(s) => <KhoPanel sess={s} />}</Page>; }
