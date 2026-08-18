import { Page } from "@/components/withSession"; import DoiTuong from "@/components/panels/DoiTuong";
export default function P() { return <Page title="Đối tượng — con người · vật nuôi · cây trồng · sản phẩm/vật tư">{(s) => <DoiTuong sess={s} />}</Page>; }
