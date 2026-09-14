import type { Metadata } from "next";
import { Inter, Manrope } from "next/font/google";
import "@fortawesome/fontawesome-free/css/all.min.css";
import "./globals.css";

const inter = Inter({ subsets: ["latin"], variable: "--font-body" });
const manrope = Manrope({ subsets: ["latin"], variable: "--font-display" });

export const metadata: Metadata = {
  title: "SSIS Performance Assessment",
  description: "Evidence-led SSIS assessment dashboard for EVSET-45D-COMPLETE",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="id"><body className={`${inter.variable} ${manrope.variable}`}>{children}</body></html>;
}
