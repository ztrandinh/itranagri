import { Page } from "@/components/withSession"; import SinhHoc from "@/components/panels/SinhHoc";
export default function P() { return <Page title="Sinh học tuần hoàn (khu D) — trùn · BSF · biogas · compost/biochar · IMO/EM · anolyte">{(s) => <SinhHoc sess={s} />}</Page>; }
