# Drv Knowledge Suite 2.0.3-complete offline bundle

This archive binds the independently deployable Skills/Worker and BookStack Governance planes.

1. Verify `SHA256SUMS.txt` before importing any artifact.
2. Read `docs/DEPLOYMENT_V2.md` and the cloud validation report.
3. Import the OCI files with `deploy/scripts/import-oci.sh . SHA256SUMS.txt`.
4. Copy `deploy/.env.example` to `.env`; change only environment configuration, secrets, certificates, RAGFlow address, and dataset mapping.
5. Back up MariaDB and BookStack `/config` before switching the immutable BookStack image. Existing articles are not initialized or overwritten by the overlay.

The `extras/` directory contains the verified five-manual RAGFlow cleaning package (A2/A3/A5/E2/M3), including the sanitizer, audit records and upload-ready Markdown parts.

Source revision: `3b09277ce77a66402fc6750caa9f9b1c59b959a7`
