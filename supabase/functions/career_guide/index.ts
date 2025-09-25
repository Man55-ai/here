// supabase/functions/career_guide/index.ts
// Simple heuristic career recommender (returns JSON your app expects)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const { context = "" } = await req.json().catch(() => ({ context: "" }));

    // --- Heuristic: ให้คะแนนจากคีย์เวิร์ดง่าย ๆ ---
    const lc = String(context || "").toLowerCase();
    const hit = (w: string) =>
      (lc.match(new RegExp(`\\b${w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`, "g")) || []).length;

    const buckets: Record<string, number> = {
      "นักพัฒนาแอปมือถือ (Flutter)": hit("flutter") + hit("dart") + hit("app") + hit("mobile") + hit("supabase"),
      "นักวิเคราะห์ข้อมูล (Data Analyst)": hit("data") + hit("sql") + hit("excel") + hit("analysis") + hit("chart"),
      "นักออกแบบ UX/UI": hit("ui") + hit("ux") + hit("design") + hit("figma") + hit("prototype"),
      "นักพัฒนาซอฟต์แวร์ (Full-stack)": hit("code") + hit("program") + hit("backend") + hit("api") + hit("database"),
      "นักการตลาดดิจิทัล": hit("marketing") + hit("campaign") + hit("tiktok") + hit("facebook") + hit("seo"),
      "นักพัฒนาเว็บ Front-end": hit("javascript") + hit("react") + hit("vue") + hit("html") + hit("css"),
    };

    const sorted = Object.entries(buckets).sort((a, b) => b[1] - a[1]);
    const top = sorted.filter(([, v]) => v > 0).slice(0, 3);

    const recs = (top.length ? top : [["สำรวจตัวเองเพิ่มเติม", 1]]).map(([title, score], i) => {
      const fit = Math.max(55, Math.min(95, Number(score) * 8 + 55 - i * 5));
      const reason =
        title === "สำรวจตัวเองเพิ่มเติม"
          ? "ยังไม่พบสัญญาณชัดเจนจากบริบทที่ให้มา ลองเล่าเรื่องสิ่งที่ชอบ/ทักษะ/โปรเจ็กต์ที่อยากทำเพิ่ม"
          : `พบบริบทและคำหลักที่สอดคล้องกับสายงาน "${title}" ในข้อความของคุณ`;
      const next_steps = [
        "เลือกคอร์สระยะสั้นที่เกี่ยวข้อง 1 คอร์สและลงมือเรียน",
        "ทำโปรเจ็กต์พอร์ตอย่างน้อย 1 ชิ้นภายใน 2–4 สัปดาห์",
        "เข้ากลุ่ม/คอมมูนิตี้ในไทยเพื่อถาม-ตอบและอัปเดตเทรนด์",
      ];
      return { title, reason, fit_score: fit, next_steps };
    });

    return new Response(JSON.stringify(recs), {
      headers: { "Content-Type": "application/json", ...cors },
	"Content-Type": "application/json; charset=utf-8", // 👈 เพิ่ม charset
      status: 200,
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e?.message ?? e) }), {
      headers: { "Content-Type": "application/json", ...cors },
      status: 400,
    });
  }
});
