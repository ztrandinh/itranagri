import { Page } from "@/components/withSession"; import SoLieuPanel from "@/components/panels/SoLieuPanel";
export default async function P({ searchParams }: { searchParams: Promise<{ m?: string }> }) { const { m } = await searchParams; return <Page title="Số liệu — mọi chỉ số đều vẽ được">{(s) => <SoLieuPanel sess={s} initialMetric={m} />}</Page>; }
