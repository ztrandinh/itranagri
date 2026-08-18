import { Page } from "@/components/withSession"; import { GhgPanel } from "@/components/panels/More";
export default function P() { return <Page title="Phát thải CO2e & tuần hoàn">{() => <GhgPanel />}</Page>; }
