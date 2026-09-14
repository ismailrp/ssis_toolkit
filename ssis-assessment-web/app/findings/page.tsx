import FindingLibrary from "@/components/FindingLibrary";
import { getFindingDocuments } from "@/lib/finding-documents";

export const dynamic = "force-dynamic";

export default async function FindingsPage() {
  return <FindingLibrary documents={await getFindingDocuments()} />;
}
