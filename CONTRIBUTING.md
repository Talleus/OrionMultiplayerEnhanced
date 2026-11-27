# Contributing

Keep changes focused. Describe behavior, source/binary correspondence, and actual validation. Keep AS3 as UTF-8 without BOM; avoid legacy PowerShell encoding round trips.

New mod classes belong in `src/`; original-dependent changes belong in `patches/` and `source-manifest.json`. Never commit a full original decompilation, original binaries/assets/runtime, saves, crash logs, credentials, or machine-specific paths.

For networking, resolve identity from the connection, validate payloads, enforce roles on the host, and rate-limit requests. Explain compatibility changes.

Run `python -m unittest discover -s tests -v`, round-trip binary/source patches, and perform appropriate real-client tests. Original contributions use MIT. Original game context/assets and external components retain their own licenses.
