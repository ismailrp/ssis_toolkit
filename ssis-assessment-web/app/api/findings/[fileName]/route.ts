import { promises as fs } from "node:fs";
import path from "node:path";
import { findingsDirectory } from "@/lib/finding-documents";

export async function GET(_: Request, context: { params: Promise<{ fileName: string }> }) {
  const { fileName } = await context.params;
  const safeName = path.basename(fileName);
  if (safeName !== fileName || !safeName.toLowerCase().endsWith(".docx")) return new Response("Invalid document", { status: 400 });
  const target = path.join(findingsDirectory, safeName);
  try {
    const bytes = await fs.readFile(target);
    return new Response(bytes, { headers: { "Content-Type": "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "Content-Disposition": `attachment; filename*=UTF-8''${encodeURIComponent(safeName)}` } });
  } catch { return new Response("Document not found", { status: 404 }); }
}
