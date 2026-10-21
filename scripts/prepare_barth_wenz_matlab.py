#!/usr/bin/env python3
"""Build a provenance-complete MATLAB/SC-Toolbox upload bundle."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request
import zipfile


ROOT = Path(__file__).resolve().parents[1]
MATLAB_INPUT = (
    ROOT / "data/derived/m23_8a_barth_wenz_class1_matlab_input.m"
)
MATLAB_DRIVER = ROOT / "barth_wenz/matlab/run_class1.m"
MATLAB_INSTRUCTIONS = ROOT / "barth_wenz/matlab/README_MATLAB_ONLINE.txt"

CODE_URL = (
    "https://ars.els-cdn.com/content/image/"
    "1-s2.0-S0021869320305810-mmc1.zip"
)
CODE_SHA256 = (
    "0e3202564229dfad668622f77c5d3c5011deac4b83d5ef10c700c3b9ced080c3"
)
CODE_FILES = (
    "CreateHyperbolicKite.m",
    "CreatePolygonAndGluingData.m",
    "Step2_DrawDessin.m",
    "Welding.m",
    "readme.txt",
)

SC_VERSION = "3.1.3"
SC_COMMIT = "6eb3a8abcda4b2185655b782053cf64e9d90665a"
SC_URL = (
    "https://github.com/tobydriscoll/sc-toolbox/"
    "archive/refs/tags/v3.1.3.tar.gz"
)
SC_SHA256 = (
    "dae0bf5b3c5d6dfb70b7076e79f27c9197c27224ec491b9dcad271ad2dbc2b1a"
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def require_sha256(path: Path, expected: str) -> None:
    observed = sha256(path)
    if observed != expected:
        raise RuntimeError(
            f"SHA-256 mismatch for {path}: expected {expected}, got {observed}"
        )


def download(url: str, destination: Path) -> None:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "m23-galois-project/Barth-Wenz-bundle"},
    )
    with urllib.request.urlopen(request) as response:
        with destination.open("wb") as output:
            shutil.copyfileobj(response, output)


def patch_domain_index(source: str, domain_index: int) -> str:
    marker = "index = 1;"
    if source.count(marker) != 1:
        raise RuntimeError("upstream Step2 domain-index marker changed")
    return source.replace(
        marker,
        f"index = {domain_index}; % pinned by M23 bundle builder",
    )


def extract_code(
    archive: Path,
    destination: Path,
    domain_index: int,
) -> dict[str, str]:
    hashes = {}
    with zipfile.ZipFile(archive) as source:
        names = set(source.namelist())
        missing = set(CODE_FILES) - names
        if missing:
            raise RuntimeError(
                f"Barth--Wenz archive is missing {sorted(missing)}"
            )
        for name in CODE_FILES:
            data = source.read(name)
            if name == "Step2_DrawDessin.m":
                data = patch_domain_index(
                    data.decode("utf-8"),
                    domain_index,
                ).encode("utf-8")
            target = destination / name
            target.write_bytes(data)
            hashes[name] = hashlib.sha256(data).hexdigest()
    return hashes


def safe_relative_tar_path(name: str) -> Path | None:
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts:
        raise RuntimeError(f"unsafe tar member {name!r}")
    if len(path.parts) <= 1:
        return None
    return Path(*path.parts[1:])


def extract_sc_toolbox(archive: Path, destination: Path) -> None:
    destination.mkdir()
    with tarfile.open(archive, "r:gz") as source:
        for member in source.getmembers():
            relative = safe_relative_tar_path(member.name)
            if relative is None:
                continue
            target = destination / relative
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            if not member.isfile():
                raise RuntimeError(
                    f"unsupported SC Toolbox archive member {member.name!r}"
                )
            target.parent.mkdir(parents=True, exist_ok=True)
            extracted = source.extractfile(member)
            if extracted is None:
                raise RuntimeError(f"cannot read tar member {member.name!r}")
            with target.open("wb") as output:
                shutil.copyfileobj(extracted, output)


def git_revision() -> str:
    return subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
    ).stdout.strip()


def write_manifest(
    destination: Path,
    domain_index: int,
    code_hashes: dict[str, str],
) -> None:
    rows = [
        ("format", "m23-barth-wenz-matlab-bundle-v1"),
        ("project_revision", git_revision()),
        ("target_class", "1"),
        ("domain_index", str(domain_index)),
        ("matlab_input_sha256", sha256(MATLAB_INPUT)),
        ("project_driver_sha256", sha256(MATLAB_DRIVER)),
        ("barth_wenz_code_url", CODE_URL),
        ("barth_wenz_code_sha256", CODE_SHA256),
        ("sc_toolbox_version", SC_VERSION),
        ("sc_toolbox_commit", SC_COMMIT),
        ("sc_toolbox_url", SC_URL),
        ("sc_toolbox_archive_sha256", SC_SHA256),
    ]
    rows.extend(
        (f"patched_{name}_sha256", digest)
        for name, digest in sorted(code_hashes.items())
    )
    destination.write_text(
        "key\tvalue\n"
        + "".join(f"{key}\t{value}\n" for key, value in rows),
        encoding="utf-8",
    )


def write_zip(source: Path, destination: Path) -> None:
    with zipfile.ZipFile(
        destination,
        mode="x",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
    ) as archive:
        for path in sorted(source.rglob("*")):
            if path.is_file():
                archive_path = str(
                    Path(source.name) / path.relative_to(source)
                )
                info = zipfile.ZipInfo(
                    archive_path,
                    date_time=(1980, 1, 1, 0, 0, 0),
                )
                mode = 0o755 if path.stat().st_mode & 0o111 else 0o644
                info.external_attr = mode << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(info, path.read_bytes(), compresslevel=9)


def build_bundle(
    output_dir: Path,
    zip_output: Path,
    domain_index: int,
    code_archive: Path,
    sc_archive: Path,
) -> None:
    require_sha256(code_archive, CODE_SHA256)
    require_sha256(sc_archive, SC_SHA256)
    if output_dir.exists():
        raise FileExistsError(f"output directory already exists: {output_dir}")
    if zip_output.exists():
        raise FileExistsError(f"zip output already exists: {zip_output}")
    output_dir.mkdir(parents=True)

    code_hashes = extract_code(code_archive, output_dir, domain_index)
    extract_sc_toolbox(
        sc_archive,
        output_dir / f"sc-toolbox-{SC_VERSION}",
    )
    shutil.copy2(MATLAB_INPUT, output_dir / "matlab_input.m")
    shutil.copy2(MATLAB_DRIVER, output_dir / "run_class1.m")
    shutil.copy2(
        MATLAB_INSTRUCTIONS,
        output_dir / "README_MATLAB_ONLINE.txt",
    )
    write_manifest(
        output_dir / "bundle_manifest.tsv",
        domain_index,
        code_hashes,
    )
    write_zip(output_dir, zip_output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--zip-output", type=Path)
    parser.add_argument("--domain-index", type=int, choices=(1, 2), default=1)
    parser.add_argument("--code-archive", type=Path)
    parser.add_argument("--sc-archive", type=Path)
    args = parser.parse_args()
    zip_output = args.zip_output or args.output_dir.with_suffix(".zip")

    with tempfile.TemporaryDirectory(prefix="m23-barth-wenz-") as temporary:
        temporary_dir = Path(temporary)
        code_archive = args.code_archive
        if code_archive is None:
            code_archive = temporary_dir / "barth-wenz-mmc1.zip"
            download(CODE_URL, code_archive)
        sc_archive = args.sc_archive
        if sc_archive is None:
            sc_archive = temporary_dir / "sc-toolbox-v3.1.3.tar.gz"
            download(SC_URL, sc_archive)
        build_bundle(
            args.output_dir,
            zip_output,
            args.domain_index,
            code_archive,
            sc_archive,
        )

    print(f"bundle_dir={args.output_dir}")
    print(f"bundle_zip={zip_output}")
    print(f"bundle_zip_sha256={sha256(zip_output)}")


if __name__ == "__main__":
    main()
