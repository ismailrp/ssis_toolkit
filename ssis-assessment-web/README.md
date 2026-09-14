# SSIS Assessment Web

Interactive documentation for assessment `EVSET-45D-COMPLETE`, built with Next.js 16, React 19, Tailwind CSS 4, and ApexCharts.

## Run

```powershell
cd ssis-assessment-web
npm install
npm run dev
```

Open `http://localhost:3000`. Use the sliders button to customize report title, client, accent color, and section visibility. Preferences are saved to browser local storage.

## Export PDF

Select **Export PDF**, choose **Save as PDF**, paper **A4**, scale **Default/100%**, margins **Default**, and enable **Background graphics**. The print stylesheet hides controls and prevents cards/tables from splitting where possible.

## Update assessment data

Edit `data/assessment.ts`. Content deliberately separates confirmed observations, hypotheses, validation, and guardrails. Do not promote static clues to runtime root causes without supporting evidence.
