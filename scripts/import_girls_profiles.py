#!/usr/bin/env python3
"""
Bulk import profiles from CSV into Supabase.

What this script does per row:
1) create auth user (email/password)
2) upload profile photo to storage bucket `avatars`
3) upload biodata to storage bucket `documents`
4) upsert public.profiles row using login_id (unique)

Usage (PowerShell):
  $env:SUPABASE_URL="https://<project-ref>.supabase.co"
  $env:SUPABASE_SERVICE_ROLE_KEY="<service-role-key>"
  python scripts/import_girls_profiles.py --csv assets/girls_profiles.csv --gender Female --apply

Dry run (no writes):
  python scripts/import_girls_profiles.py --csv assets/girls_profiles.csv --gender Female
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import mimetypes
import os
import re
import sys
import urllib.parse
from pathlib import Path

import requests


NAME_COL = "मुलाचे/मुलीचे नाव"
OCCUPATION_COL = "मुलाचा/मुलीचा व्यवसाय"
INCOME_COL = "वार्षिक उत्पन्न"
EDUCATION_COL = "मुलाचे/मुलीचे शिक्षण"
FATHER_NAME_COL = "वडिलांचे नाव"
ADDRESS_COL = "वडिलांचा पत्ता"
FATHER_PHONE_COL = "वडिलांचा मोबाईल संपर्क क्र"
BIRTH_DATE_COL = "मुलाची/मुलीची जन्म तारीख"
BIRTH_PLACE_COL = "जन्म स्थान"
HEIGHT_COL = 'उंची(eg. 5.7")'
BLOOD_COL = "रक्त गट"
COMPLEXION_COL = "वर्ण"
WHATSAPP_COL = "Whatsapp Number"
BIODATA_PATH_COL = "Bio-Data local path"
PHOTO_PATH_COL = "Photo local path"
LOGIN_ID_COL = "login_id"
PASSWORD_COL = "password"


def clean(value: str | None) -> str:
    return (value or "").strip()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Import profiles CSV to Supabase")
    parser.add_argument("--csv", default="assets/girls_profiles.csv", help="Path to girls CSV")
    parser.add_argument(
        "--assets-base",
        default="assets",
        help="Base directory for relative file paths from CSV",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Actually write to Supabase (default is dry-run).",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Process first N rows only (0 = all rows).",
    )
    parser.add_argument(
        "--gender",
        default="Female",
        choices=["Female", "Male"],
        help="Gender value to set in imported profile rows.",
    )
    return parser.parse_args()


def require_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def parse_birth_date(raw: str) -> str | None:
    raw = clean(raw)
    if not raw:
        return None
    for fmt in ("%m/%d/%Y", "%d/%m/%Y", "%Y-%m-%d"):
        try:
            return dt.datetime.strptime(raw, fmt).date().isoformat()
        except ValueError:
            continue
    return None


def normalize_height(raw: str) -> str | None:
    raw = clean(raw)
    if not raw:
        return None
    m = re.match(r"^\s*(\d+)\s*[.\']\s*(\d+)\s*$", raw)
    if m:
        return f"{m.group(1)}' {m.group(2)}\""
    return raw


def normalize_rel_path(raw: str) -> str:
    raw = clean(raw).replace("\\", "/")
    return raw.lstrip("./")


def upload_file(
    *,
    supabase_url: str,
    service_role_key: str,
    bucket: str,
    object_path: str,
    file_path: Path,
) -> str:
    content_type = mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"
    upload_url = (
        f"{supabase_url}/storage/v1/object/{bucket}/"
        f"{urllib.parse.quote(object_path, safe='/')}"
    )
    headers = {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
        "x-upsert": "true",
        "Content-Type": content_type,
    }
    with file_path.open("rb") as fh:
        resp = requests.post(upload_url, headers=headers, data=fh.read(), timeout=120)
    if resp.status_code not in (200, 201):
        raise RuntimeError(
            f"Storage upload failed ({bucket}/{object_path}): {resp.status_code} {resp.text}"
        )
    return f"{supabase_url}/storage/v1/object/public/{bucket}/{urllib.parse.quote(object_path, safe='/')}"


def create_auth_user(
    *,
    supabase_url: str,
    service_role_key: str,
    email: str,
    password: str,
    full_name: str,
    login_id: str,
) -> str:
    url = f"{supabase_url}/auth/v1/admin/users"
    headers = {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "email": email,
        "password": password,
        "email_confirm": True,
        "user_metadata": {"full_name": full_name, "login_id": login_id},
    }
    resp = requests.post(url, headers=headers, json=payload, timeout=60)
    if resp.status_code not in (200, 201):
        raise RuntimeError(f"Auth user create failed: {resp.status_code} {resp.text}")
    data = resp.json()
    user_id = data.get("id")
    if not user_id:
        raise RuntimeError(f"Auth create response missing id: {data}")
    return user_id


def list_auth_users(*, supabase_url: str, service_role_key: str) -> dict[str, str]:
    """Return map: email(lower) -> user_id."""
    url = f"{supabase_url}/auth/v1/admin/users"
    headers = {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
    }
    page = 1
    out: dict[str, str] = {}
    while True:
        resp = requests.get(
            url, headers=headers, params={"page": page, "per_page": 1000}, timeout=60
        )
        if resp.status_code != 200:
            raise RuntimeError(f"Auth users list failed: {resp.status_code} {resp.text}")
        data = resp.json()
        users = data.get("users", [])
        if not users:
            break
        for u in users:
            email = (u.get("email") or "").strip().lower()
            uid = u.get("id")
            if email and uid:
                out[email] = uid
        page += 1
    return out


def get_existing_profile_id(
    *, supabase_url: str, service_role_key: str, login_id: str
) -> str | None:
    url = f"{supabase_url}/rest/v1/profiles"
    headers = {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
    }
    params = {"select": "id", "login_id": f"eq.{login_id}", "limit": "1"}
    resp = requests.get(url, headers=headers, params=params, timeout=30)
    if resp.status_code != 200:
        raise RuntimeError(f"Profile lookup failed: {resp.status_code} {resp.text}")
    rows = resp.json()
    if not rows:
        return None
    return rows[0]["id"]


def get_profile_columns(*, supabase_url: str, service_role_key: str) -> set[str]:
    url = f"{supabase_url}/rest/v1/profiles"
    headers = {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
    }
    resp = requests.get(url, headers=headers, params={"select": "*", "limit": "1"}, timeout=30)
    if resp.status_code != 200:
        raise RuntimeError(f"Failed to inspect profiles schema: {resp.status_code} {resp.text}")
    rows = resp.json()
    if not rows:
        # conservative fallback
        return {
            "id",
            "email",
            "full_name",
            "gender",
            "phone_number",
            "date_of_birth",
            "education",
            "occupation",
            "city",
            "height",
            "profile_photo_url",
            "biodata_url",
            "is_paid",
            "created_by_admin",
            "payment_exempt",
            "prompt_password_change",
            "updated_at",
            "login_id",
        }
    return set(rows[0].keys())


def upsert_profile(
    *,
    supabase_url: str,
    service_role_key: str,
    profile: dict,
) -> None:
    url = f"{supabase_url}/rest/v1/profiles"
    headers = {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates,return=minimal",
    }
    params = {"on_conflict": "id"}
    resp = requests.post(url, headers=headers, params=params, json=[profile], timeout=60)
    if resp.status_code not in (200, 201, 204):
        raise RuntimeError(f"Profile upsert failed: {resp.status_code} {resp.text}")


def safe_email_from_login_id(login_id: str) -> str:
    if "@" in login_id:
        return login_id
    return f"{login_id}@runanubandh.local"


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    args = parse_args()
    csv_path = Path(args.csv).resolve()
    assets_base = Path(args.assets_base).resolve()

    if not csv_path.exists():
        print(f"CSV not found: {csv_path}")
        return 1

    dry_run = not args.apply
    supabase_url = os.getenv("SUPABASE_URL", "").strip()
    service_role_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not dry_run:
        if not supabase_url:
            raise RuntimeError("Missing required environment variable: SUPABASE_URL")
        if not service_role_key:
            raise RuntimeError(
                "Missing required environment variable: SUPABASE_SERVICE_ROLE_KEY"
            )

    print(f"Mode: {'DRY RUN' if dry_run else 'APPLY'}")
    print(f"CSV: {csv_path}")
    print(f"Assets base: {assets_base}")

    successes = 0
    failures: list[dict] = []
    processed = 0
    auth_email_to_id: dict[str, str] = {}
    profile_columns: set[str] = set()

    if not dry_run:
        auth_email_to_id = list_auth_users(
            supabase_url=supabase_url, service_role_key=service_role_key
        )
        profile_columns = get_profile_columns(
            supabase_url=supabase_url, service_role_key=service_role_key
        )

    with csv_path.open("r", encoding="utf-8-sig", newline="") as fh:
        reader = csv.DictReader(fh)
        for idx, row in enumerate(reader, start=2):
            if args.limit and processed >= args.limit:
                break
            processed += 1

            try:
                login_id = clean(row.get(LOGIN_ID_COL))
                password = clean(row.get(PASSWORD_COL))
                full_name = clean(row.get(NAME_COL))
                if not login_id or not password or not full_name:
                    raise RuntimeError("Missing required login_id/password/name")

                rel_photo = normalize_rel_path(row.get(PHOTO_PATH_COL, ""))
                rel_biodata = normalize_rel_path(row.get(BIODATA_PATH_COL, ""))
                photo_file = assets_base / rel_photo
                biodata_file = assets_base / rel_biodata

                if not photo_file.exists():
                    raise RuntimeError(f"Photo file missing: {photo_file}")
                if not biodata_file.exists():
                    raise RuntimeError(f"Biodata file missing: {biodata_file}")

                email = safe_email_from_login_id(login_id)
                date_of_birth = parse_birth_date(row.get(BIRTH_DATE_COL, ""))
                height = normalize_height(row.get(HEIGHT_COL, ""))
                city = clean(row.get(BIRTH_PLACE_COL))
                phone = clean(row.get(WHATSAPP_COL)) or clean(row.get(FATHER_PHONE_COL))

                existing_id = None
                if not dry_run:
                    existing_id = get_existing_profile_id(
                        supabase_url=supabase_url,
                        service_role_key=service_role_key,
                        login_id=login_id,
                    )

                if dry_run:
                    print(f"[DRY] row {idx}: {full_name} ({login_id})")
                    successes += 1
                    continue

                user_id = existing_id
                if not user_id:
                    existing_auth_id = auth_email_to_id.get(email.lower())
                    if existing_auth_id:
                        user_id = existing_auth_id
                    else:
                        user_id = create_auth_user(
                            supabase_url=supabase_url,
                            service_role_key=service_role_key,
                            email=email,
                            password=password,
                            full_name=full_name,
                            login_id=login_id,
                        )
                        auth_email_to_id[email.lower()] = user_id

                photo_storage_path = f"import/girls/{login_id}/photo{photo_file.suffix.lower()}"
                biodata_storage_path = (
                    f"import/girls/{login_id}/biodata{biodata_file.suffix.lower()}"
                )

                photo_url = upload_file(
                    supabase_url=supabase_url,
                    service_role_key=service_role_key,
                    bucket="avatars",
                    object_path=photo_storage_path,
                    file_path=photo_file,
                )
                biodata_url = upload_file(
                    supabase_url=supabase_url,
                    service_role_key=service_role_key,
                    bucket="documents",
                    object_path=biodata_storage_path,
                    file_path=biodata_file,
                )

                profile_payload = {
                    "id": user_id,
                    "email": email,
                    "full_name": full_name,
                    "gender": args.gender,
                    "phone_number": phone or None,
                    "date_of_birth": date_of_birth,
                    "education": clean(row.get(EDUCATION_COL)) or None,
                    "occupation": clean(row.get(OCCUPATION_COL)) or None,
                    "city": city or None,
                    "height": height,
                    "profile_photo_url": photo_url,
                    "biodata_url": biodata_url,
                    "blood_group": clean(row.get(BLOOD_COL)) or None,
                    "complexion": clean(row.get(COMPLEXION_COL)) or None,
                    "father_name": clean(row.get(FATHER_NAME_COL)) or None,
                    "address": clean(row.get(ADDRESS_COL)) or None,
                    "annual_income": clean(row.get(INCOME_COL)) or None,
                    "login_id": login_id,
                    "created_by_admin": True,
                    "payment_exempt": True,
                    "is_paid": True,
                    "prompt_password_change": False,
                    "updated_at": dt.datetime.utcnow().isoformat(),
                }
                profile_payload = {
                    k: v
                    for k, v in profile_payload.items()
                    if k in profile_columns
                }
                upsert_profile(
                    supabase_url=supabase_url,
                    service_role_key=service_role_key,
                    profile=profile_payload,
                )
                print(f"[OK] row {idx}: {full_name} ({login_id})")
                successes += 1
            except Exception as exc:  # pylint: disable=broad-except
                failures.append({"row": idx, "error": str(exc), "login_id": row.get(LOGIN_ID_COL)})
                print(f"[FAIL] row {idx}: {exc}")

    print("\n=== Import Summary ===")
    print(f"Processed: {processed}")
    print(f"Succeeded: {successes}")
    print(f"Failed:    {len(failures)}")

    if failures:
        report_path = Path("scripts/import_girls_failures.json").resolve()
        report_path.write_text(json.dumps(failures, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"Failure report: {report_path}")
        return 2
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as e:
        print(f"Error: {e}")
        raise SystemExit(1)
