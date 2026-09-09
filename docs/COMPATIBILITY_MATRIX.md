# Drv Knowledge Suite V2 compatibility matrix

| Component | V2 baseline | Compatible range | Patch policy |
|---|---:|---:|---|
| Contracts | 2.0.0 | 2.0.x | Shared release artifact |
| Skills/CLI | 2.0.0 | Contracts `>=2.0.0 <2.1.0` | Independent patch |
| Worker | 2.0.0 | Governance `>=2.0.0 <2.1.0` | Independent patch |
| Governance | 2.0.0 | Contracts `>=2.0.0 <2.1.0` | Independent patch |
| BookStack | v26.03.3 | `>=26.03.3 <27.0` | Probe before promotion |
| PHP | 8.5.5 cloud baseline | `>=8.2 <8.6` | Must run PHP tests in target image |
| MariaDB | 11.4.9 cloud baseline | 11.4.x | Backup before migration |
| RAGFlow | v0.27.1 reference | Version probe required | External in cloud RC; official offline bundle in intranet |

Current cross-plane patch: Skills/CLI, Worker, Governance packaging and release bundle are `2.0.3`; frozen Contracts V2 schemas remain compatible with `>=2.0.0 <2.1.0`.

`knowledge_bundle` (V3 legacy shape) is retained with a deprecation warning during
the 2.0.x line. New consumers must use `knowledge_bundle_v2` with schema version
`drvknowledge.knowledge-bundle.v2`.
