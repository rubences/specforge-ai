# Phase 18.8 — Lightweighting Lab Implementation

## Origin

This module is born from the paper:

> **"Structural optimization principles for edge AI in motorsport telemetry"**
> Ruben Juarez Cadiz, Fernando Rodriguez-Sela (2026)
> Scientific Reports. DOI: 10.1038/s41598-026-49736-0

## Audit

Before implementation, the entire specforge-ai monorepo was audited for:

- lightweighting, BESO, FoSdig, IPW, K <-> H bridge, Hessian, stiffness matrix
- GPTQ, AWQ, INT4, MARLIN, Formula Student upright, topology optimization

**Result: zero hits.** No prior implementation existed.

## Route Implemented

`/lightweighting-lab` in `specforge-web` (specforge-ai monorepo)

## Concepts Included

| Concept | Status |
|---------|--------|
| K <-> H Bridge (physical/digital correspondence) | Visible |
| BESO topology optimization | Visible |
| GPTQ / AWQ / PTQ | Visible |
| FoSdig (Digital Factor of Safety) | Visible |
| IPW (Intelligence-per-Watt) | Visible |
| Formula Student upright case study (Al 7075-T6, 2.45 kg) | Visible |
| INT4 32B-class operating point (61 -> 18 GB) | Visible |
| Digital Lightweighting Pipeline (9 steps) | Visible |
| Research -> Product CTA | Visible |

## Files Created

| File | Size | Description |
|------|------|-------------|
| `data/lightweighting-lab-data.ts` | 6104 B | Shared dataset (paper metadata, bridge map, case studies, formulas, operating point, pipeline) |
| `components/lightweighting/BridgeMap.tsx` | - | Dual-column K <-> H comparison |
| `components/lightweighting/MetricFormulaCard.tsx` | - | Formula display card |
| `components/lightweighting/OperatingPointCard.tsx` | - | Before/after comparison table |
| `components/lightweighting/PipelineSteps.tsx` | - | Numbered pipeline steps |
| `components/lightweighting/CaseStudyCard.tsx` | - | Reusable case study wrapper |
| `app/lightweighting-lab/page.tsx` | 10571 B | Main page (hero, TOC, 7 sections) |

## Files Modified

| File | Change |
|------|--------|
| `app/layout.tsx` | Added "Lightweighting" nav link |

## Build

`npm run build` — **OK**. 7 static pages generated, 0 errors.

## Deploy

InsForge project `a4800d19-59da-4d69-bb6a-c74421dcf2ac`
URL: https://ep3nru4k.insforge.site/lightweighting-lab/
Deployment ID: b0a1784a-fcfb-476b-8910-b2a11cc42146

## Smoke

- `/` — 200 OK (9333 B)
- `/dashboard/` — 200 OK (8470 B)
- `/projects/new/` — 200 OK (9312 B)
- `/lightweighting-lab/` — 200 OK (61797 B)

Content verification: 18/18 concepts confirmed present.

## Commit

- `feat(specforge): add structural and digital lightweighting lab`

## Limitations

- Static page only (no interactive metric calculator)
- No link from/to RCC yet (deferred to Phase 18.9)
- Formulas displayed as plain text (no LaTeX rendering)

## Next Steps

Phase 18.9 — Research-to-Product Bridge: connect SpecForge Lightweighting Lab
-> RCC Engineering modules -> AI Copilot explanation -> executive demo story.
