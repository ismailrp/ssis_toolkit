import { promises as fs } from "node:fs";
import path from "node:path";

export type FindingDocument = {
  fileName: string;
  findingId: string;
  packageName: string;
  subject: string;
  size: number;
  duplicateId: boolean;
};

export const findingsDirectory = path.resolve(process.cwd(), "..", "results", "package_findings_detail");

export async function getFindingDocuments(): Promise<FindingDocument[]> {
  const names = (await fs.readdir(findingsDirectory)).filter((name) => name.toLowerCase().endsWith(".docx")).sort();
  const ids = names.map((name) => name.match(/Finding-(\d+)/i)?.[1] ?? "—");
  const counts = new Map(ids.map((id) => [id, ids.filter((candidate) => candidate === id).length]));
  return Promise.all(names.map(async (fileName, index) => {
    const match = fileName.match(/^SSIS Finding-(\d+)-(.+?)-(.+?) v[\d.]+[a-z]?\.docx$/i);
    const stat = await fs.stat(path.join(findingsDirectory, fileName));
    return {
      fileName,
      findingId: ids[index],
      packageName: (match?.[2] ?? "Unknown package").replace(/_dtsx$/i, ".dtsx").replaceAll("_", " "),
      subject: match?.[3] ?? "Assessment finding",
      size: stat.size,
      duplicateId: (counts.get(ids[index]) ?? 0) > 1,
    };
  }));
}
