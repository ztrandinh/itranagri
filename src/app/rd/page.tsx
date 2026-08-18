import { Page } from "@/components/withSession"; import { ModuleByKey } from "@/components/ModuleRegistry";
export default function P() { return <Page title="R&D — đề tài · nhánh đối chứng · quan sát · mẫu lab · tri thức">{() => <ModuleByKey k="rd" />}</Page>; }
