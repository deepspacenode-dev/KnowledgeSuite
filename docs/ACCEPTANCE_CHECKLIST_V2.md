# V2.0 acceptance checklist

- [x] Clean disposable install on Linux x86_64 Docker Compose with external RAGFlow left empty.
- [ ] Upgrade A 1.0.8 sessions without losing drafts or local manuals.
- [ ] Upgrade B 1.9.1 without losing BookStack pages or `drv_kb_*` history.
- [ ] Draft → page → Intake → Worker → pending review → reviewed/verified → RAG → recall.
- [x] Repeated Intake and Worker result are idempotent.
- [ ] Page text/image change yields `need_recheck` and `stale`.
- [ ] B outage leaves Intake in SQLite outbox and recovery acknowledges it once.
- [x] Empty/unavailable RAGFlow does not block drafting, cached reading or review.
- [ ] Ordinary users cannot administer governance; page permissions apply to Intake/status.
- [x] Worker cannot claim or submit with a wrong signature, identity, lease or source version.
- [x] Automated policy and PHP domain tests reject non-Wiki assets and pages outside `【AI】` shelves from formal RAG.
- [ ] RAG delete failure blocks replacement; state-write failure cleans newly uploaded documents.
- [x] Python, PHP/Laravel, MariaDB and frontend tests execute; source assertions are packaging checks only.
- [x] Secret scan, external URL scan, SPDX inventory, licenses and SHA-256 checks pass.
- [ ] Rollback restores prior images while preserving BookStack and governance data.
