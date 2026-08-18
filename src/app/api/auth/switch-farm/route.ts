import { NextResponse } from "next/server";
import { getSession, setSessionCookie } from "@/lib/auth";
export async function POST(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const { farm_id } = await req.json();
  if (!s.farmIds.includes(farm_id) && s.role !== "owner") return NextResponse.json({ error: "ERR_FORBIDDEN_FARM" }, { status: 403 });
  await setSessionCookie({ ...s, farmId: farm_id });
  return NextResponse.json({ ok: true, farmId: farm_id });
}
