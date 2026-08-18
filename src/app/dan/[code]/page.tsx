import { Page } from "@/components/withSession"; import AnimalDetail from "@/components/panels/AnimalDetail";
export default async function P({ params }: { params: Promise<{ code: string }> }) { const { code } = await params; return <Page title={`Hồ sơ ${decodeURIComponent(code)}`}>{(s) => <AnimalDetail sess={s} code={decodeURIComponent(code)} />}</Page>; }
