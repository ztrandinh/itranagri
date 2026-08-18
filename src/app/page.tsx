import { redirect } from "next/navigation";
import { getSession, ROLE_HOME } from "@/lib/auth";
export default async function Home() { const s = await getSession(); redirect(s ? (ROLE_HOME[s.role] ?? "/ca") : "/login"); }
