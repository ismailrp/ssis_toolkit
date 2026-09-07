# Active SQL Agent Job / SSIS Anti-Pattern Priority Report

Scope: only SQL Agent jobs with `job_enabled = 1`. Mapping uses the SSIS `Execution ID` embedded in SQL Agent history messages, then joins to `04_ssis_executions.csv` and `DTSX_ANTIPATTERN_PACKAGE_FINDINGS.csv`. `TIME_OVERLAP_ONLY` candidates are excluded.

Generated: 2026-09-07 14:55:30
Mapped active job-step/package groups: 165

| Rank | Priority | Job | Step | Package | Executions | Avg min | Max min | Total hours | Failed | Anti-patterns |
|---:|---|---|---|---|---:|---:|---:|---:|---:|---:|
| 1 | P1 | SEQUENCE_TABLE_SIGAP | 1: Staging | Seq_Staging_SIGAP.dtsx | 1 | 105.6 | 105.6 | 1.8 | 0 | 8 |
| 2 | P1 | LAPORAN KEUANGAN KEBUN (LKK) | 4: Fact | FACT_LKK.dtsx | 1 | 70.3 | 70.3 | 1.2 | 0 | 3044 |
| 3 | P1 | INVESTOR RELATION | 5: Production Summary dan Areal Statement | PS_AS.dtsx | 1 | 67.4 | 67.4 | 1.1 | 1 | 890 |
| 4 | P1 | AI Grading | 2: Fact | Fact.dtsx | 3 | 63.4 | 70 | 3.2 | 0 | 0 |
| 5 | P1 | Tax - Annually | 3: Annually Split | FACT_PPH_ANNUAL_SPLIT.dtsx | 2 | 37.8 | 38.5 | 1.3 | 0 | 28 |
| 6 | P1 | Internal Audit | 1: Internal Audit | FACT_INTERNAL_AUDIT.dtsx | 2 | 36.8 | 37.1 | 1.2 | 0 | 109 |
| 7 | P1 | LAPORAN KEUANGAN KEBUN (LKK) | 10: Fact Plasma Gapoktan | Fact.dtsx | 2 | 34.5 | 35.4 | 1.2 | 0 | 1495 |
| 8 | P1 | SPARTA FACT 4T | 4: Fact Sparta LHA | FACT_SPARTA_LHA_NEW.dtsx | 7 | 34 | 41.8 | 4 | 0 | 1212 |
| 9 | P1 | Ranking Payroll | 3: Ranking Payroll | FACT_RANKING_PAYROLL.dtsx | 2 | 32.9 | 39.3 | 1.1 | 0 | 1429 |
| 10 | P2 | SPARTA FACT | 4: Fact Sparta Jurnal Payroll | FACT_JOURNAL_PAYROLL.dtsx | 3 | 26.6 | 29.9 | 1.3 | 0 | 424 |
| 11 | P2 | Segregation | 2: Segregation | Segregation.dtsx | 2 | 24.4 | 24.9 | 0.8 | 0 | 387 |
| 12 | P2 | Komparasi Overhead Metro | 1: DWH_STG to DWH_DM | DWH_STG_to_DWH_DM.dtsx | 1 | 21.9 | 21.9 | 0.4 | 0 | 53 |
| 13 | P2 | LAPORAN KEUANGAN KEBUN (LKK) | 12: Fact LKK Dashboard | FACT_LKK_DASHBOARD.dtsx | 2 | 21.3 | 22.1 | 0.7 | 0 | 173 |
| 14 | P2 | SEQUENCE_TABLE_SPARTA | 1: SEQ_STAGING_SPARTA | Seq_Staging_SPARTA.dtsx | 3 | 17.2 | 20 | 0.9 | 0 | 112 |
| 15 | P2 | SEQUENCE_TABLE_SAP | 1: SEQ_STAGING | Seq_Staging_SAP.dtsx | 3 | 16.7 | 24.4 | 0.8 | 0 | 191 |
| 16 | P2 | REALISASI BUDGET HO | 4: Fact | FACT_REALISASI_VS_ANGGARAN_HO.dtsx | 1 | 16.6 | 16.6 | 0.3 | 0 | 1360 |
| 17 | P2 | ESTIMATION_COST_ELEMENT | 2: Cost Element Weekly | FACT_COST_ELEMENT.dtsx | 2 | 16.2 | 18.9 | 0.5 | 0 | 267 |
| 18 | P2 | Daily Opr - Produksi TBS | 5: Fact Monitoring TBS | FACT_DD_TBS.dtsx | 6 | 16 | 17.8 | 1.6 | 0 | 340 |
| 19 | P2 | SPARTA FACT | 3: Fact Sparta Payroll | FACT_SPARTA_PAYROLL.dtsx | 3 | 15.9 | 18.1 | 0.8 | 0 | 110 |
| 20 | P2 | SPARTA FACT 4T | 7: Fact Sparta Fisik Premi | FACT_SPARTA_FISIK_PREMI.dtsx | 7 | 15.3 | 26.2 | 1.8 | 0 | 6 |
| 21 | P2 | SEQUENCE_TABLE_SPARTA_4T | 1: SEQ_STAGING_SPARTA_4T | Seq_Staging_SPARTA_4T.dtsx | 6 | 14.7 | 18.5 | 1.5 | 0 | 99 |
| 22 | P2 | TBS External | 2: Fact TBS External | FACT_DD_TBS.dtsx | 4 | 13.6 | 17.3 | 0.9 | 0 | 340 |
| 23 | P2 | Alokasi Absensi HK | 3: Alokasi & Absensi | FACT_ALOKASI_DAN_ABSENSI_HK.dtsx | 2 | 12.6 | 16.6 | 0.4 | 0 | 295 |
| 24 | P2 | MILL_COST_and_MILL_ENGINEERING | 3: Fact Mill Cost | FACT_MILL_COST.dtsx | 1 | 12.5 | 12.5 | 0.2 | 0 | 2950 |
| 25 | P2 | LAPORAN PANEN DAN PENGENDALIAN GULMA | 1: Fact | FACT_LKK_BIAYA_UPAH_PANEN_PENGENDALIAN_GULMA.dtsx | 2 | 12.2 | 14.7 | 0.4 | 0 | 6 |
| 26 | P2 | LAPORAN KEUANGAN KEBUN (LKK) | 3: Mapping | INSERT_MAPPING_BIAYA_TANAMAN.dtsx | 1 | 11.2 | 11.2 | 0.2 | 0 | 704 |
| 27 | P2 | MONITORING_CAPEX | 3: Monitoring Capex | FACT_MONITORING_CAPEX.dtsx | 4 | 11 | 18.2 | 0.7 | 0 | 7 |
| 28 | P2 | DWH_SIGAP | 1: Fact SIGAP | FACT_SIGAP.dtsx | 1 | 10.3 | 10.3 | 0.2 | 0 | 315 |
| 29 | P2 | MILL_COST_and_MILL_ENGINEERING | 2: Dimensi | DIM_FOR_FACT_MILL_COST.dtsx | 1 | 9.9 | 9.9 | 0.2 | 0 | 218 |
| 30 | P3 | DWH_Bearer_Plant | 11: DWH_FACT_BEARER_PLANT_CONSOL | DWH_FACT_BEARER_PLANT_CONSOL.dtsx | 1 | 9 | 9 | 0.2 | 0 | 4 |
| 31 | P2 | Areal Statement | 2: DWH_STG_to_DWH_DM | DWH_STG_to_DWH_DM.dtsx | 1 | 8.4 | 8.4 | 0.1 | 0 | 108 |
| 32 | P2 | Daily Opr - Mutu Buah | 1: Mutu Buah | FACT_DAILY_OPR.dtsx | 1 | 8.1 | 8.1 | 0.1 | 0 | 1130 |
| 33 | P3 | DASHBOARD_STOCK | 1: Staging Stock Area ECC0 | STAGING_STOCK_AREA_ECC0.dtsx | 2 | 6.8 | 6.9 | 0.2 | 0 | 5 |
| 34 | P3 | DASHBOARD_STOCK | 3: Fact Stock Area (Aging) | FACT_STOCK_AREA.dtsx | 2 | 6.6 | 7.1 | 0.2 | 0 | 2 |
| 35 | P2 | SEQUENCE_TABLE_REPOSITORY | 1: DWH_RPS | Seq_Repository.dtsx | 1 | 6.2 | 6.2 | 0.1 | 0 | 601 |
| 36 | P2 | SEQUENCE_TABLE_SAP | 2: SEQ_STAGING_EHP8 | Seq_Staging_SAP_EHP8.dtsx | 3 | 6.1 | 8.7 | 0.3 | 0 | 175 |
| 37 | P2 | DASHBOARD_STOCK | 4: Fact Stock Management | FACT_STOCK_MANAGEMENT.dtsx | 2 | 5.7 | 6 | 0.2 | 0 | 11 |
| 38 | P2 | SEQUENCE_TABLE_SPARTA_QA | 1: Staging | Seq_Staging_SPARTA_QA.dtsx | 1 | 5.5 | 5.5 | 0.1 | 0 | 21 |
| 39 | P1 | AWL | 1: Staging | Staging.dtsx | 41 | 5.3 | 14.3 | 3.6 | 0 | 4 |
| 40 | P2 | SEQUENCE_TABLE_NON_SAP | 1: SEQ_STAGING | Seq_Staging_NON_SAP.dtsx | 4 | 5.3 | 7.6 | 0.4 | 0 | 118 |
| 41 | P2 | DWH_MACHINE_LEARNING | 2: Fact Analisa Produksi | FACT_AP_TBS_.dtsx | 6 | 5 | 6.8 | 0.5 | 0 | 282 |
| 42 | P2 | Analisa Low Yield | 3: Fact | Fact.dtsx | 2 | 5 | 6 | 0.2 | 0 | 31 |
| 43 | P2 | Profit TBS External | 1: Fact TBS External | Fact_TBS_External.dtsx | 2 | 4.8 | 5.3 | 0.2 | 0 | 643 |
| 44 | P3 | DWH_ZVT_MSEGPF | 2: ZVT_MSEGPF_EHP8 | Seq_Staging_SAP_EHP8_ZVT_MSEGPF.dtsx | 2 | 4.8 | 6.2 | 0.2 | 0 | 2 |
| 45 | P2 | SEQUENCE_TABLE_SAP_BSIS_BSAS_BSIK_BSAK_BSID_BSAD_BKPF | 7: Seq_BKPF | Seq_BKPF.dtsx | 7 | 4.7 | 11.3 | 0.5 | 0 | 13 |
| 46 | P2 | COGS | 1: stg_CogsReport | stg_CogsReport.dtsx | 1 | 4.5 | 4.5 | 0.1 | 0 | 59 |
| 47 | P3 | SEQUENCE_TABLE_SAP_COBK | 1: SEQ_STAGING_COBK | STG_SAP_COBK.dtsx | 1 | 4.4 | 4.4 | 0.1 | 0 | 1 |
| 48 | P2 | RELOKASI BUDGET OPEX | 2: Seq Fact | FACT_RELOCATION_BUDGET.dtsx | 1 | 4.1 | 4.1 | 0.1 | 0 | 433 |
| 49 | P3 | SEQUENCE_TABLE_SAP_BSIS_BSAS_BSIK_BSAK_BSID_BSAD_BKPF | 1: Seq BSIS_BSAS | Seq_BSIS_BSAS.dtsx | 7 | 4 | 5.9 | 0.5 | 0 | 7 |
| 50 | P2 | DWH_COEP | 1: COEP | DWH-COEP.dtsx | 3 | 3.8 | 6.2 | 0.2 | 0 | 298 |
| 51 | P2 | DWH_MR_ETC_SAP | 1: SAP FAST TABLES | DWH_SMALLERTABLES.dtsx | 2 | 3.8 | 3.9 | 0.1 | 0 | 89 |
| 52 | P3 | DWH_TRAKSI_LHT | 2: Fact Traksi LHT | FACT_TRAKSI_LHT.dtsx | 2 | 3.6 | 3.9 | 0.1 | 0 | 9 |
| 53 | P2 | DWH_Bearer_Plant | 2: DWH_FACT_BP_COEP | DWH_FACT_BP_COEP.dtsx | 1 | 3.3 | 3.3 | 0.1 | 0 | 20 |
| 54 | P3 | DWH_COEP | 2: COEP EHP 8 | Seq_Staging_SAP_EHP8_COEP.dtsx | 3 | 3.1 | 4.1 | 0.2 | 0 | 2 |
| 55 | P2 | Daily Opr - GIP | 3: Fact | Fact.dtsx | 1 | 3.1 | 3.1 | 0.1 | 0 | 20 |
| 56 | P2 | Alokasi Absensi HK | 4: Pusingan Panen & Rawat | FACT_PUSINGAN_PANEN_DAN_RAWAT.dtsx | 2 | 2.9 | 3.1 | 0.1 | 0 | 302 |
| 57 | P2 | LAPORAN KEUANGAN KEBUN (LKK) | 7: Fact TBS Angkut | UPLOAD_TBS_ANGKUT.dtsx | 2 | 2.9 | 3.3 | 0.1 | 0 | 503 |
| 58 | P3 | SPARTA FACT | 2: Check Query Process | CHECK_QUERY_DATA.dtsx | 3 | 2.6 | 3.1 | 0.1 | 0 | 0 |
| 59 | P2 | AWS | 1: Fact AWS | FACT_AWS.dtsx | 1 | 2.5 | 2.5 | 0 | 0 | 713 |
| 60 | P3 | COST_TO_MATURITY | 1: FACT | FACT_COST_TO_MATURITY.dtsx | 2 | 2.4 | 3.3 | 0.1 | 0 | 6 |
| 61 | P2 | Saldo Treasury | 5: Saldo Daily | FACT_SALDO_HARIAN.dtsx | 5 | 2.3 | 2.7 | 0.2 | 0 | 1408 |
| 62 | P2 | Areal Statement | 1: SOURCE_to_DWH_STG | SOURCE_to_DWH_STG.dtsx | 1 | 2.2 | 2.2 | 0 | 0 | 926 |
| 63 | P2 | Saldo Treasury | 4: Saldo Monthly | FACT_SALDO_AKHIR_BULAN.dtsx | 5 | 2.2 | 2.7 | 0.2 | 0 | 3589 |
| 64 | P2 | SQA - BHS | 1: Fact | Fact.dtsx | 1 | 2.1 | 2.1 | 0 | 0 | 454 |
| 65 | P2 | Laporan Uang Muka | 1: Fact Laporan Uang Muka | FACT_UANG_MUKA.dtsx | 2 | 2.1 | 2.8 | 0.1 | 0 | 348 |
| 66 | P2 | Pemakaian Pupuk Anorganik | 1: PEMAKAIAN_PUPUK | AKTUAL_PEMAKAIAN_PUPUK.dtsx | 2 | 2 | 2.1 | 0.1 | 0 | 481 |
| 67 | P2 | MONITORING_TICKET_WB | 2: Staging | STAGING.dtsx | 3 | 1.9 | 2.6 | 0.1 | 0 | 20 |
| 68 | P3 | Monitoring Pembangkit Listrik Mill | 1: Fact | Fact.dtsx | 2 | 1.7 | 2 | 0.1 | 0 | 5 |
| 69 | P2 | SPK_BAPP | 2: spk_bapp | FACT_CIVIL_ENGINEERING.dtsx | 2 | 1.6 | 2.3 | 0.1 | 0 | 802 |
| 70 | P3 | Tax - Monthly | 1: Daily DJP | FACT_DJP.dtsx | 1 | 1.6 | 1.6 | 0 | 0 | 8 |
| 71 | P2 | ESTIMATION_COST_ELEMENT | 1: Cost Element Weekly Rate | FACT_COST_ELEMENT_RATE.dtsx | 2 | 1.6 | 1.6 | 0.1 | 0 | 275 |
| 72 | P3 | TBS External | 1: Staging TBS External | STG_TBS_EXTERNAL.dtsx | 4 | 1.5 | 3.6 | 0.1 | 0 | 5 |
| 73 | P2 | Tax - Unifikasi | 1: Unifkasi | FACT_UNIFIKASI.dtsx | 1 | 1.5 | 1.5 | 0 | 0 | 440 |
| 74 | P3 | DWH_TRAKSI_LHT | 3: Fact Traksi AB | FACT_LHT_AB.dtsx | 2 | 1.5 | 1.9 | 0 | 0 | 5 |
| 75 | P2 | SEQUENCE_TABLE_SAP_SALDO_TREASURY | 1: STG Saldo Treasury EHP0 | Seq_Staging_SAP_SALDO_TREASURY.dtsx | 5 | 1.5 | 2 | 0.1 | 0 | 21 |
| 76 | P2 | Payment Realization | 2: Fact Payment Realization | Fact_Payment.dtsx | 1 | 1.4 | 1.4 | 0 | 0 | 185 |
| 77 | P2 | DWH_Bearer_Plant | 3: DWH_FACT_BP_ZVT_MSEGPF | DWH_FACT_BP_ZVT_MSEGPF.dtsx | 1 | 1.3 | 1.3 | 0 | 0 | 521 |
| 78 | P3 | DWH_ZVT_MSEGPF | 1: ZVT_MSEGPF | DWH_ZVT_MSEGPF.dtsx | 2 | 1.2 | 1.8 | 0 | 0 | 8 |
| 79 | P2 | MILL_COST_and_MILL_ENGINEERING | 4: Fact Mill Cost Dashboard | FACT_MILL_COST_DASHBOARD.dtsx | 1 | 1.2 | 1.2 | 0 | 0 | 367 |
| 80 | P2 | Daily Opr - Produksi TBS | 6: Fact Summary TBS | FACT_DD_SUMMARY.dtsx | 6 | 1.1 | 1.8 | 0.1 | 0 | 1813 |
| 81 | P2 | DWH_TRAKSI_LHT | 1: Staging | STG_TRAKSI_LHT.dtsx | 2 | 1 | 1.9 | 0 | 0 | 143 |
| 82 | P2 | MILL_COST_and_MILL_ENGINEERING | 5: Fact Mill Engineering | FACT_CIVIL_ENGINEERING.dtsx | 1 | 1 | 1 | 0 | 0 | 802 |
| 83 | P2 | SEQUENCE_TABLE_SAP_BSIS_BSAS_BSIK_BSAK_BSID_BSAD_BKPF | 8: Seq_BKPF_EHP8 | Seq_Staging_SAP_EHP8_BKPF.dtsx | 7 | 0.9 | 2.1 | 0.1 | 0 | 13 |
| 84 | P2 | Intercompany Loan | 1: Daily INLOAN | FACT_INLOAN.dtsx | 2 | 0.9 | 1 | 0 | 0 | 452 |
| 85 | P3 | SEQUENCE_TABLE_SAP_BSIS_BSAS_BSIK_BSAK_BSID_BSAD_BKPF | 5: Seq BSID_BSAD | Seq_BSID_BSAD.dtsx | 7 | 0.9 | 1.3 | 0.1 | 0 | 4 |
| 86 | P2 | SPK_BAPP | 3: Payment | Payment.dtsx | 2 | 0.9 | 1.1 | 0 | 0 | 33 |
| 87 | P2 | COMPARISON ESTATE vs MILL COST | 2: Fact | FACT_ESTATE_MILL_COST.dtsx | 2 | 0.8 | 1.3 | 0 | 0 | 1071 |
| 88 | P1 | SEQUENCE_TABLE_WB | 1: Seq Staging WB | Seq_Staging_WB.dtsx | 5 | 0.8 | 1.2 | 0.1 | 4 | 33 |
| 89 | P3 | SPARTA FACT | 5: Fact Sparta Monitoring Input | FACT_SPARTA_MONITORING_INPUT.dtsx | 3 | 0.8 | 1 | 0 | 0 | 2 |
| 90 | P3 | SMK3 Sustainability | 1: Fact SMK3 Sustainability | FACT_SUSTAIN_SMK3.dtsx | 1 | 0.8 | 0.8 | 0 | 0 | 4 |
| 91 | P2 | Payment Treasury | 6: Fact Performance | FACT_PERFORMANCE_PAYMENT.dtsx | 3 | 0.8 | 1 | 0 | 0 | 200 |
| 92 | P1 | AI Grading | 1: Staging | Staging.dtsx | 6 | 0.8 | 1.8 | 0.1 | 4 | 2 |
| 93 | P2 | SPK_BAPP | 1: Ijin_Prinsip | SPK_BAPP.dtsx | 2 | 0.8 | 1.2 | 0 | 0 | 40 |
| 94 | P3 | SEQUENCE_TABLE_SAP_BSIS_BSAS_BSIK_BSAK_BSID_BSAD_BKPF | 3: Seq BSIK_BSAK | Seq_BSIK_BSAK.dtsx | 7 | 0.7 | 0.9 | 0.1 | 0 | 4 |
| 95 | P2 | SEQUENCE_TABLE_POWER_MONITORING | 1: Staging | Seq_Staging_Power_Monitoring.dtsx | 2 | 0.7 | 1 | 0 | 0 | 2622 |
| 96 | P3 | DASHBOARD_STOCK | 2: StagingStock Area EHP8 | STAGING_STOCK_AREA_EHP8.dtsx | 2 | 0.6 | 0.9 | 0 | 0 | 5 |
| 97 | P2 | Tax - Pph21 | 1: Pph21 | FACT_PPH21.dtsx | 1 | 0.6 | 0.6 | 0 | 0 | 1074 |
| 98 | P2 | SPARTA FACT 4T | 3: Dimensi Sparta LHA | DIMENSI_SPARTA.dtsx | 6 | 0.5 | 0.7 | 0.1 | 0 | 172 |
| 99 | P2 | Payment Treasury | 3: Fact Summary | FACT_SUMMARY_PAYMENT.dtsx | 3 | 0.5 | 0.6 | 0 | 0 | 350 |
| 100 | P3 | REALISASI BUDGET HO | 3: Dimensi | DIMENSI_REALIASI_VS_ANGGARAN_HO.dtsx | 1 | 0.4 | 0.4 | 0 | 0 | 4 |
| 101 | P3 | DWH_MACHINE_LEARNING | 1: Fact ML Yield Prediction | FACT_ML_YP.dtsx | 6 | 0.4 | 0.6 | 0 | 0 | 9 |
| 102 | P2 | Summary PL & EBITDA | 5: Fact Ebitda | fact_ebitda.dtsx | 1 | 0.4 | 0.4 | 0 | 0 | 261 |
| 103 | P3 | Tax - Annually | 1: Initial Annually | FACT_PPH_ANNUAL.dtsx | 1 | 0.4 | 0.4 | 0 | 0 | 9 |
| 104 | P2 | SQA - BMS | 2: Fact BMS | FACT_BMS.dtsx | 1 | 0.3 | 0.3 | 0 | 0 | 18 |
| 105 | P3 | Analisa Low Yield | 2: Check Query Process | CHECK_QUERY_DATA.dtsx | 2 | 0.3 | 0.5 | 0 | 0 | 0 |
| 106 | P1 | Traffic Management System | 1: STG TMS | Seq_Staging_NON_SAP_TMS.dtsx | 1 | 0.3 | 0.3 | 0 | 1 | 12 |
| 107 | P2 | DWH_Bearer_Plant | 12: Group_Pipeline_Bearer_Plant_Consol_1 | Group_Pipeline_Bearer_Plant_Consol_1.dtsx | 1 | 0.3 | 0.3 | 0 | 0 | 10 |
| 108 | P2 | DWH_Bearer_Plant | 4: DWH_FACT_BP_FAGLFLEXT | DWH_FACT_BP_FAGLFLEXT.dtsx | 1 | 0.3 | 0.3 | 0 | 0 | 628 |
| 109 | P1 | INVESTOR RELATION | 4: PL dan BS | PL_BS.dtsx | 2 | 0.3 | 0.6 | 0 | 1 | 214 |
| 110 | P3 | Summary PL & EBITDA | 2: Dim Company | dim_company.dtsx | 1 | 0.3 | 0.3 | 0 | 0 | 2 |
| 111 | P2 | Rekapitulasi | 1: Rekapitulasi | Fact_Rekapitulasi.dtsx | 2 | 0.3 | 0.4 | 0 | 0 | 33 |
| 112 | P2 | Summary PL & EBITDA | 3: Fact Summary PL | fact_summary_pl.dtsx | 1 | 0.3 | 0.3 | 0 | 0 | 337 |
| 113 | P3 | SEQUENCE_TABLE_SAP_BSIS_BSAS_BSIK_BSAK_BSID_BSAD_BKPF | 2: Seq_BSIS_BSAS_EHP8 | Seq_Staging_SAP_EHP8_BSIS_BSAS.dtsx | 7 | 0.3 | 0.4 | 0 | 0 | 7 |
| 114 | P2 | MONITORING_TICKET_WB | 3: Fact | FACT.dtsx | 3 | 0.3 | 0.3 | 0 | 0 | 255 |
| 115 | P3 | Summary PL & EBITDA | 4: Dim Code Ebitda | dim_code_ebitda.dtsx | 1 | 0.2 | 0.2 | 0 | 0 | 9 |
| 116 | P3 | SQA - BMS | 1: Initiate BJR | FACT_BJR.dtsx | 1 | 0.2 | 0.2 | 0 | 0 | 8 |
| 117 | P2 | SEQUENCE_TABLE_SAP_SALDO_TREASURY | 2: STG Saldo Treasury EHP8 | Seq_Staging_SAP_EHP8_SALDO_TREASURY.dtsx | 5 | 0.2 | 0.4 | 0 | 0 | 17 |
| 118 | P2 | Vehicle Registration | 1: Daily VR | FACT_VR.dtsx | 4 | 0.2 | 0.4 | 0 | 0 | 12 |
| 119 | P2 | Payment Treasury | 4: Fact Detail | FACT_DETAIL_PAYMENT.dtsx | 3 | 0.2 | 0.2 | 0 | 0 | 236 |
| 120 | P3 | DWH_Bearer_Plant | 13: Group_Pipeline_Bearer_Plant_Consol_2 | Group_Pipeline_Bearer_Plant_Consol_2.dtsx | 1 | 0.2 | 0.2 | 0 | 0 | 4 |
| 121 | P3 | MONITORING_CAPEX | 2: Check Query Process | CHECK_QUERY_DATA.dtsx | 4 | 0.2 | 0.5 | 0 | 0 | 0 |
| 122 | P2 | Payment Treasury | 5: Fact Outstanding | FACT_OUTSTANDING_PAYMENT.dtsx | 3 | 0.2 | 0.3 | 0 | 0 | 215 |
| 123 | P3 | Summary PL & EBITDA | 1: Dim Coa | dim_coa.dtsx | 1 | 0.2 | 0.2 | 0 | 0 | 1 |
| 124 | P3 | Ranking Payroll | 2: Check Query Data | CHECK_QUERY_DATA.dtsx | 1 | 0.2 | 0.2 | 0 | 0 | 0 |
| 125 | P2 | DWH_Bearer_Plant | 8: DWH_FACT_BEARER_PLANT_SUMMARIZE | DWH_FACT_BEARER_PLANT_SUMMARIZE.dtsx | 1 | 0.2 | 0.2 | 0 | 0 | 158 |
| 126 | P3 | SEQUENCE_TABLE_SAP_COBK | 2: SEQ_STAGING_COBK_EHP8 | Seq_Staging_SAP_EHP8_COBK.dtsx | 1 | 0.2 | 0.2 | 0 | 0 | 1 |
| 127 | P3 | AWL | 2: Fact | Fact.dtsx | 41 | 0.1 | 1.3 | 0.1 | 0 | 3 |
| 128 | P3 | REALISASI BUDGET HO | 2: Manual Upload | UPLOAD_PTAB_RELOKASI_COP.dtsx | 1 | 0.1 | 0.1 | 0 | 0 | 7 |
| 129 | P2 | DWH_Bearer_Plant | 14: DWH_FACT_BGA_CONSOL | DWH_FACT_BGA_CONSOL.dtsx | 1 | 0.1 | 0.1 | 0 | 0 | 626 |
| 130 | P3 | SEQUENCE_TABLE_SAP_BSIS_BSAS_BSIK_BSAK_BSID_BSAD_BKPF | 4: Seq_BSIK_BSAK_EHP8 | Seq_Staging_SAP_EHP8_BSIK_BSAK.dtsx | 7 | 0.1 | 0.3 | 0 | 0 | 4 |
| 131 | P3 | AP Aging | 1: fact_ap_aging | Ap_Aging.dtsx | 1 | 0.1 | 0.1 | 0 | 0 | 1 |
| 132 | P3 | Controllable Profit | 2: Check Query Process | CHECK_QUERY_DATA.dtsx | 2 | 0.1 | 0.1 | 0 | 0 | 0 |
| 133 | P3 | SEQUENCE_TABLE_SAP_BSIS_BSAS_BSIK_BSAK_BSID_BSAD_BKPF | 6: Seq_BSID_BSAD_EHP8 | Seq_Staging_SAP_EHP8_BSID_BSAD.dtsx | 7 | 0.1 | 0.2 | 0 | 0 | 4 |
| 134 | P3 | Alokasi Absensi HK | 2: Query Check Data | CHECK_QUERY_DATA.dtsx | 2 | 0.1 | 0.1 | 0 | 0 | 0 |
| 135 | P3 | LAPORAN KEUANGAN KEBUN (LKK) | 2: Query Check Data | CHECK_QUERY_DATA.dtsx | 1 | 0.1 | 0.1 | 0 | 0 | 0 |
| 136 | P3 | Payment Treasury | 1: Dim | DIM_PAYMENT.dtsx | 3 | 0.1 | 0.1 | 0 | 0 | 4 |
| 137 | P3 | COGS | 2: dim_cogs_measure | dim_cogs_measure.dtsx | 1 | 0.1 | 0.1 | 0 | 0 | 1 |
| 138 | P2 | Uang Masuk Collection | 1: Fact Uang Masuk Collection | Fact_DP_Collection.dtsx | 1 | 0.1 | 0.1 | 0 | 0 | 92 |
| 139 | P3 | SQA - BGS | 1: Fact | Fact.dtsx | 1 | 0.1 | 0.1 | 0 | 0 | 2 |
| 140 | P2 | DWH_Bearer_Plant | 9: DWH_FACT_BEARER_PLANT_SUMMARIZE_Excel | DWH_FACT_BEARER_PLANT_SUMMARIZE_Excel.dtsx | 1 | 0.1 | 0.1 | 0 | 0 | 449 |
| 141 | P3 | Payment Treasury | 2: Mapping | MAPPING_GROUP_PAYMENT.dtsx | 3 | 0.1 | 0.2 | 0 | 0 | 3 |
| 142 | P3 | DWH_Bearer_Plant | 10: Group_Pipeline_Dim_Bearer_Plant_Consol | Group_Pipeline_Dim_Bearer_Plant_Consol.dtsx | 1 | 0.1 | 0.1 | 0 | 0 | 4 |
| 143 | P3 | INVESTOR RELATION | 2: Check Query Process | CHECK_QUERY_DATA.dtsx | 1 | 0.1 | 0.1 | 0 | 0 | 0 |
| 144 | P3 | COMPARISON ESTATE vs MILL COST | 1: Insert Mapping | INSERT_REPORT_LEVEL_ESTATE_MILL.dtsx | 2 | 0.1 | 0.1 | 0 | 0 | 2 |
| 145 | P3 | COGS | 3: dim_company | dim_company.dtsx | 1 | 0.1 | 0.1 | 0 | 0 | 1 |
| 146 | P3 | Payment Realization | 1: Dim Mapping | Dim_Payment_Mapping.dtsx | 1 | 0.1 | 0.1 | 0 | 0 | 2 |
| 147 | P3 | COGS | 5: fact_cogs | fact_cogs.dtsx | 1 | 0.1 | 0.1 | 0 | 0 | 6 |
| 148 | P3 | Daily Opr - Produksi TBS | 4: Staging Mapping | STG_DAILY_DASHBOARD.dtsx | 6 | 0.1 | 0.1 | 0 | 0 | 2 |
| 149 | P2 | DWH_Bearer_Plant | 15: DWH_FACT_BAL_CONSOL | DWH_FACT_BAL_CONSOL.dtsx | 1 | 0.1 | 0.1 | 0 | 0 | 187 |
| 150 | P3 | Daily Opr - Produksi TBS | 2: Check Query Process | CHECK_QUERY_DATA.dtsx | 6 | 0.1 | 0.1 | 0 | 0 | 0 |
| 151 | P3 | SPARTA FACT 4T | 2: Check Query Process | CHECK_QUERY_DATA.dtsx | 6 | 0.1 | 0.1 | 0 | 0 | 0 |
| 152 | P3 | RELOKASI BUDGET OPEX | 1: Seq_Staging | Staging_Relocation_Budget.dtsx | 1 | 0.1 | 0.1 | 0 | 0 | 4 |
| 153 | P3 | Saldo Treasury | 3: Mapping | MAPPING_SALDO.dtsx | 5 | 0 | 0.1 | 0 | 0 | 4 |
| 154 | P2 | DWH_Bearer_Plant | 5: DWH_FACT_BP_Excel_Manual_Upload | DWH_FACT_BP_Excel_Manual_Upload.dtsx | 1 | 0 | 0 | 0 | 0 | 865 |
| 155 | P3 | INVESTOR RELATION | 3: Upload IR | Upload_IR.dtsx | 1 | 0 | 0 | 0 | 0 | 4 |
| 156 | P2 | Tax - Payment | 1: Tax Payment | FACT_TAX_PAYMENT.dtsx | 1 | 0 | 0 | 0 | 0 | 227 |
| 157 | P3 | Docket Jangkos | 1: Daily Docket | FACT_DOCKET.dtsx | 1 | 0 | 0 | 0 | 0 | 9 |
| 158 | P2 | DWH_Bearer_Plant | 1: DWH_DIM_BEARER_PLANT | DWH_DIM_BEARER_PLANT.dtsx | 1 | 0 | 0 | 0 | 0 | 10 |
| 159 | P2 | AWL | 3: AWL Warning | AWL_Warning.dtsx | 41 | 0 | 0.4 | 0 | 0 | 13 |
| 160 | P3 | Daily Opr - GIP | 2: Dimensi | Dimensi.dtsx | 1 | 0 | 0 | 0 | 0 | 5 |
| 161 | P3 | COGS | 4: dim_report_cogs | dim_report_cogs.dtsx | 1 | 0 | 0 | 0 | 0 | 2 |
| 162 | P2 | Payment Treasury | 7: Fact Balance Perform | FACT_BALANCE_PAYMENT.dtsx | 3 | 0 | 0 | 0 | 0 | 377 |
| 163 | P3 | Daily Opr - Produksi TBS | 3: Staging Operational Holiday | STG_OPERATIONAL_HOLIDAY.dtsx | 6 | 0 | 0 | 0 | 0 | 2 |
| 164 | P3 | Pemakaian Solar | 1: STG Proporsi | AREAL_STATEMENT_PROPORSI_MANUAL_LOAD.dtsx | 1 | 0 | 0 | 0 | 0 | 8 |
| 165 | P3 | Daily Opr - GIP | 1: Staging | Staging.dtsx | 1 | 0 | 0 | 0 | 0 | 2 |

## Interpretation

- Prioritize by average package duration first, then execution frequency and anti-pattern count.
- Priority rule: P1 = any failure, average duration >= 30 minutes, or mapped cumulative duration >= 2 hours; P2 = average duration >= 10 minutes or at least 10 static findings; P3 = otherwise. P0 is not assigned automatically.
- Job/step mapping is high confidence where the SQL Agent history message contains the matching SSIS `Execution ID`.
- Package duration is SSIS execution duration; job-step duration includes SQL Agent overhead and should be used for end-to-end validation.
- This report does not include disabled jobs and does not treat time-overlap-only candidates as confirmed mappings.
