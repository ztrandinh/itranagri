import { Page } from "@/components/withSession"; import Obj360 from "@/components/panels/Obj360";
export default async function P({ params }: { params: Promise<{ type: string; id: string }> }) { const { type, id } = await params; return <Page title={`Xem 360 · ${decodeURIComponent(id)}`}>{(s) => <Obj360 sess={s} type={type} id={decodeURIComponent(id)} />}</Page>; }
