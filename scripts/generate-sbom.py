#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
from datetime import UTC, datetime
from pathlib import Path


def tracked_files(root: Path) -> list[Path]:
    output = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=root
    ).decode("utf-8")
    return [root / name for name in sorted(output.split("\0")) if name]


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate a deterministic SPDX file inventory")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    files = []
    for index, path in enumerate(tracked_files(root), start=1):
        if not path.is_file():
            continue
        files.append(
            {
                "SPDXID": f"SPDXRef-File-{index}",
                "fileName": path.relative_to(root).as_posix(),
                "checksums": [{"algorithm": "SHA256", "checksumValue": digest(path)}],
                "licenseConcluded": "NOASSERTION",
                "copyrightText": "NOASSERTION",
            }
        )
    epoch = int(
        os.environ.get(
            "SOURCE_DATE_EPOCH",
            subprocess.check_output(
                ["git", "log", "-1", "--format=%ct"], cwd=root, text=True
            ).strip(),
        )
    )
    created = datetime.fromtimestamp(epoch, UTC)
    document = {
        "spdxVersion": "SPDX-2.3",
        "dataLicense": "CC0-1.0",
        "SPDXID": "SPDXRef-DOCUMENT",
        "name": "fedora-glow-kit-source",
        "documentNamespace": "https://github.com/daredoole/fedora-glow-kit/sbom/1.0.0",
        "creationInfo": {
            "created": created.replace(microsecond=0).isoformat().replace("+00:00", "Z"),
            "creators": ["Tool: fedora-glow-kit-generate-sbom"],
        },
        "packages": [
            {
                "name": "fedora-glow-kit",
                "SPDXID": "SPDXRef-Package",
                "versionInfo": "1.0.0",
                "downloadLocation": "NOASSERTION",
                "filesAnalyzed": True,
                "licenseConcluded": "MIT",
                "licenseDeclared": "MIT",
                "copyrightText": "NOASSERTION",
            }
        ],
        "files": files,
        "relationships": [
            {
                "spdxElementId": "SPDXRef-Package",
                "relationshipType": "CONTAINS",
                "relatedSpdxElement": item["SPDXID"],
            }
            for item in files
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
