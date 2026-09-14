"use client";
import dynamic from "next/dynamic";
import type { ApexOptions } from "apexcharts";
import { durationLeaders } from "@/data/assessment";
const Chart = dynamic(() => import("react-apexcharts"), { ssr: false });

const common: ApexOptions = { chart: { toolbar: { show: false }, fontFamily: "Arial, sans-serif", animations: { enabled: false } }, dataLabels: { enabled: false }, grid: { borderColor: "#e8e4db", strokeDashArray: 4 }, tooltip: { theme: "light" } };

export function DurationChart({ accent }: { accent: string }) {
  const options: ApexOptions = { ...common, colors: [accent, "#d9a441"], plotOptions: { bar: { borderRadius: 4, horizontal: true, barHeight: "58%" } }, xaxis: { categories: durationLeaders.map(x => x.package), title: { text: "Detik" } }, legend: { position: "top", horizontalAlign: "right" } };
  return <Chart type="bar" height={290} options={options} series={[{ name: "Rata-rata", data: durationLeaders.map(x => x.avg) }, { name: "Maksimum", data: durationLeaders.map(x => x.max) }]} />;
}

export function ReliabilityChart({ accent }: { accent: string }) {
  const options: ApexOptions = { ...common, colors: [accent, "#d05b45", "#d9a441", "#7d8793"], labels: ["Succeeded", "Failed", "Unexpected", "Canceled"], legend: { position: "bottom" }, stroke: { width: 3, colors: ["#fff"] }, plotOptions: { pie: { donut: { size: "70%", labels: { show: true, total: { show: true, label: "Executions", formatter: () => "16.480" } } } } } };
  return <Chart type="donut" height={290} options={options} series={[16204, 237, 38, 1]} />;
}
