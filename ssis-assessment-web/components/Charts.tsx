"use client";
import dynamic from "next/dynamic";
import type { ApexOptions } from "apexcharts";
import {
  activeJobPriorityDistribution,
  cumulativeLeaders,
  durationLeaders,
} from "@/data/assessment";
const Chart = dynamic(() => import("react-apexcharts"), { ssr: false });

const common: ApexOptions = { chart: { toolbar: { show: false }, fontFamily: "Arial, sans-serif", animations: { enabled: false } }, dataLabels: { enabled: false }, grid: { borderColor: "#e8e4db", strokeDashArray: 4 }, tooltip: { theme: "light" } };

export function AverageDurationChart({ accent }: { accent: string }) {
  const options: ApexOptions = { ...common, colors: [accent], plotOptions: { bar: { borderRadius: 4, horizontal: true, barHeight: "58%" } }, xaxis: { categories: durationLeaders.map(x => x.package), title: { text: "Rata-rata durasi (detik)" } }, legend: { show: false }, tooltip: { y: { formatter: value => `${value.toLocaleString("id-ID", { maximumFractionDigits: 2 })} detik` } } };
  return <Chart type="bar" height={390} options={options} series={[{ name: "Rata-rata", data: durationLeaders.map(x => x.avg) }]} />;
}

export function CumulativeRuntimeChart({ accent }: { accent: string }) {
  const options: ApexOptions = { ...common, colors: [accent], plotOptions: { bar: { borderRadius: 4, horizontal: true, barHeight: "58%" } }, xaxis: { categories: cumulativeLeaders.map(x => x.package), title: { text: "Akumulasi durasi terhitung (jam)" } }, tooltip: { y: { formatter: value => `${value.toFixed(2)} jam` } }, legend: { show: false } };
  return <Chart type="bar" height={340} options={options} series={[{ name: "Cumulative runtime", data: cumulativeLeaders.map(x => x.totalHours) }]} />;
}

export function ActiveJobPriorityChart() {
  const options: ApexOptions = {
    ...common,
    colors: ["#a63d2f", "#7150c8", "#d9a441", "#7d8793"],
    plotOptions: { bar: { borderRadius: 5, columnWidth: "52%", distributed: true } },
    xaxis: {
      categories: activeJobPriorityDistribution.map((item) => item.priority),
      title: { text: "Level prioritas" },
    },
    yaxis: { title: { text: "Relasi job-step-package" }, min: 0 },
    legend: { show: false },
    tooltip: {
      y: { formatter: (value) => `${value.toLocaleString("id-ID")} relasi job-step-package` },
    },
  };
  return <Chart type="bar" height={280} options={options} series={[{ name: "Jumlah", data: activeJobPriorityDistribution.map((item) => item.count) }]} />;
}

export function ReliabilityChart({ accent }: { accent: string }) {
  const options: ApexOptions = { ...common, colors: [accent, "#d05b45", "#d9a441", "#7d8793"], labels: ["Succeeded", "Failed", "Unexpected", "Canceled"], legend: { position: "bottom" }, stroke: { width: 3, colors: ["#fff"] }, plotOptions: { pie: { donut: { size: "70%", labels: { show: true, total: { show: true, label: "Executions", formatter: () => "16.480" } } } } } };
  return <Chart type="donut" height={290} options={options} series={[16204, 237, 38, 1]} />;
}
