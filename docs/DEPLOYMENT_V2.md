# Drv Knowledge Suite V2 deployment

RAGFlow v0.27.1 的 P0 参数、并行数据集迁移、Chat 创建与回滚步骤见 [RAGFLOW_V027_P0_DEPLOYMENT.md](RAGFLOW_V027_P0_DEPLOYMENT.md)。

## Cloud RC: external RAGFlow

1. Copy `deploy/.env.example` to `deploy/.env` outside source control.
2. Generate new values for both MariaDB passwords and `AI_GOVERNANCE_WORKER_KEY`.
3. Keep every RAGFlow value empty and keep `WORKER_COMPILER=offline` until the API is available.
4. Run `docker compose --env-file deploy/.env -f deploy/compose.yaml --profile external-ragflow config`.
5. Back up the existing BookStack database and `/config` volume.
6. Build the immutable governance and Worker images, then start the profile.
7. Run `deploy/scripts/smoke.sh` and the authenticated V2 intake/status checks.

Before building the Skills release, generate hashed wheelhouses without installing
anything from the network on the target host:

```text
python tools/release/build_wheelhouse.py --target-name windows-x86_64-cp312
python tools/release/build_wheelhouse.py --target-name linux-x86_64-cp312 --platform manylinux_2_28_x86_64 --platform manylinux2014_x86_64 --python-version 312 --abi cp312
python tools/release/build_v2_release.py --source-only
```

The Skills ZIP contains both wheelhouse directories and their `SHA256SUMS.json`
manifests. The intranet installer remains check-only; administrators use
`pip install --no-index --find-links <wheelhouse> -r requirements/full.txt` before
running a full-profile installation.

After the Linux release host exports the immutable Worker, BookStack and Fake
RAGFlow validation images, bind the source ZIPs, all three OCI files, SBOM,
deployment documents, the verified cleaned-manual package and the exact Git
revision into one offline archive:

```text
python tools/release/build_offline_bundle.py \
  --release-label 2.0.3-complete \
  --worker-oci <path>/drv-knowledge-worker-v2.0.3.oci.tar.zst \
  --bookstack-oci <path>/drv-knowledge-bookstack-v2.0.3.oci.tar.zst \
  --fake-ragflow-oci <path>/drv-knowledge-fake-ragflow-v2.0.3.oci.tar.zst \
  --cleaned-manuals <path>/ragflow-manuals-cleaned-v1.1.0-20260904.zip
```

The builder creates an internal `RELEASE-MANIFEST.json`, `SHA256SUMS.txt`, a full
tracked-source archive and an external `.zip.sha256` sidecar. It never packages
runtime `.env` files or server credentials.

The validation target is supplied through `BOOKSTACK_APP_URL` and `BOOKSTACK_PUBLIC_URL`. Credentials
must remain only in the server-side `.env` or secret store.

## Intranet: full stack

Put the unmodified official RAGFlow v0.27.1 source bundle under
`deploy/vendor/ragflow-v0.27.1`, import all verified OCI archives, then run the
combined `deploy/compose.full-stack.yaml`. The official RAGFlow dependency stack
is kept intact; Drv Knowledge only supplies addresses, credentials, certificates,
workflow IDs and dataset mappings.

No business source file may differ between cloud and intranet. Promotion changes
only `.env`, secrets, certificates and dataset/workflow identifiers.

## Upgrade and rollback

- `deploy/scripts/backup.sh` captures MariaDB and BookStack `/config` before change.
- `deploy/scripts/upgrade.sh` builds without pulling and performs a health smoke test.
- `deploy/scripts/rollback.sh` restores the previous immutable image references and preserves data.
- V2 migrations only add `drv_kb_*` structures; never drop or rewrite BookStack core tables.
