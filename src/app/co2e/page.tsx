import { Page } from "@/components/withSession"; import { GhgPanel } from "@/components/panels/More";
export default function P() { return <Page title="Phát thải & tuần hoàn — CO2e (IPCC Tier 1) · vòng dinh dưỡng khu D">{() => <GhgPanel />}</Page>; }
