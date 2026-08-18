import { Page } from "@/components/withSession"; import DuLich from "@/components/panels/DuLich";
export default function P() { return <Page title="Du lịch — lưu trú · ẩm thực · tiệc/MICE · tour">{(s) => <DuLich sess={s} />}</Page>; }
