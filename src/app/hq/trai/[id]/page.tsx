import { Page } from "@/components/withSession"; import FarmProfile from "@/components/panels/FarmProfile";
export default async function P({ params }: { params: Promise<{ id: string }> }) { const { id } = await params; return <Page title={`Hồ sơ trại ${id}`}>{(s) => <FarmProfile sess={s} farmId={id} />}</Page>; }
