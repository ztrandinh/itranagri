import { Page } from "@/components/withSession"; import GiamSat from "@/components/panels/GiamSat";
export default function P() { return <Page title="Giám sát — tiêu chí theo vị trí · chấm điểm tuần · lỗi & khắc phục">{(s) => <GiamSat sess={s} />}</Page>; }
