import { Page } from "@/components/withSession"; import { SopPanel } from "@/components/panels/Ops";
export default async function P({ params }: { params: Promise<{ code: string }> }) { const { code } = await params; return <Page>{() => <SopPanel code={decodeURIComponent(code)} />}</Page>; }
