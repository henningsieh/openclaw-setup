#!/usr/bin/env python3
"""Poll openclaw@ai.sieh.org INBOX and send allowlisted threaded replies.

Subcommands:
  list   -> JSON summary of processable allowlisted mail
  send   -> send one threaded reply (allowlist enforced), mark \\Seen after SMTP ok

State: state.json beside this script (uidvalidity + last_uid watermark).
Password: env IMAP_SMTP_OPENCLAW_AI_SIEH_ORG_PASSWORD (never printed).
"""
import argparse
import email
import imaplib
import json
import os
import smtplib
import sys
from email.header import decode_header, make_header
from email.message import EmailMessage
from email.utils import formatdate, make_msgid, parseaddr
from pathlib import Path

HOST = "mail.sieh.org"
IMAP_PORT = 993
SMTP_PORT = 587
USER = "openclaw@ai.sieh.org"
PASSWORD_ENV = "IMAP_SMTP_OPENCLAW_AI_SIEH_ORG_PASSWORD"
ALLOWED_SENDERS = {"henning@sieh.org", "kontakt@henningsieh.de"}
ALLOWED_FROM_NAMES = {"Shelldon"}
LOOP_HEADER = "X-Openclaw-Autoreply"
BASE_DIR = Path(__file__).resolve().parent
STATE_FILE = BASE_DIR / "state.json"


def password():
    pw = os.environ.get(PASSWORD_ENV)
    if not pw:
        raise SystemExit(json.dumps({"ok": False, "error": f"missing env {PASSWORD_ENV}"}))
    return pw


def dec(value):
    if not value:
        return ""
    try:
        return str(make_header(decode_header(str(value))))
    except Exception:
        return str(value)


def load_state():
    try:
        return json.loads(STATE_FILE.read_text())
    except Exception:
        return {"uidvalidity": None, "last_uid": 0}


def save_state(state):
    STATE_FILE.write_text(json.dumps(state, indent=2) + "\n")
    try:
        os.chmod(STATE_FILE, 0o600)
    except OSError:
        pass


def connect():
    m = imaplib.IMAP4_SSL(HOST, IMAP_PORT)
    m.login(USER, password())
    return m


def body_text(msg, limit=6000):
    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_type() == "text/plain" and not part.get_filename():
                raw = part.get_payload(decode=True) or b""
                text = raw.decode(part.get_content_charset() or "utf-8", "replace")
                return text.strip()[:limit]
        for part in msg.walk():
            if part.get_content_type() == "text/html" and not part.get_filename():
                raw = part.get_payload(decode=True) or b""
                return raw.decode(part.get_content_charset() or "utf-8", "replace").strip()[:limit]
        return ""
    raw = msg.get_payload(decode=True) or b""
    return raw.decode(msg.get_content_charset() or "utf-8", "replace").strip()[:limit]


def is_loop(msg):
    if msg.get(LOOP_HEADER):
        return True
    if (msg.get("Auto-Submitted") or "").lower().startswith("auto"):
        return True
    return False


def replied_message_ids(m):
    """Message-IDs this mailbox already replied to (header scan, PEEK only)."""
    ids = set()
    try:
        typ, data = m.uid("search", None, "ALL")
        uids = (data[0].split() if typ == "OK" and data and data[0] else [])[-300:]
        if not uids:
            return ids
        typ, data = m.uid(
            "fetch", b",".join(uids),
            "(BODY.PEEK[HEADER.FIELDS (IN-REPLY-TO " + LOOP_HEADER + ")])",
        )
        for item in data:
            if isinstance(item, tuple):
                msg = email.message_from_bytes(item[1])
                if msg.get(LOOP_HEADER):
                    inreply = msg.get("In-Reply-To", "")
                    for token in inreply.replace(",", " ").split():
                        ids.add(token.strip().strip("<>"))
    except Exception:
        pass
    return ids


def cmd_list(_args):
    m = connect()
    try:
        typ, data = m.select("INBOX")
        if typ != "OK":
            raise SystemExit(json.dumps({"ok": False, "error": "select INBOX failed"}))
        uidvalidity = int((m.response("UIDVALIDITY")[1] or [b"0"])[0])
        state = load_state()
        if state.get("uidvalidity") not in (None, uidvalidity):
            typ, data = m.uid("search", None, "ALL")
            uids = data[0].split() if data and data[0] else []
            state = {"uidvalidity": uidvalidity, "last_uid": int(uids[-1]) if uids else 0}
            save_state(state)
        state["uidvalidity"] = uidvalidity
        last = int(state.get("last_uid") or 0)

        typ, data = m.uid("search", None, f"UID {last + 1}:*")
        uids = data[0].split() if data and data[0] else []
        uids = [u for u in uids if int(u) > last]

        replied = replied_message_ids(m)
        entries = []
        for u in uids:
            typ, data = m.uid(
                "fetch", u,
                "(BODY.PEEK[HEADER] BODY.PEEK[TEXT])",
            )
            if typ != "OK":
                continue
            raw = b"".join(x[1] for x in data if isinstance(x, tuple))
            if not raw:
                continue
            msg = email.message_from_bytes(raw)
            from_name, from_addr = parseaddr(dec(msg.get("From")))
            from_addr = (from_addr or "").lower()
            message_id = (msg.get("Message-ID") or "").strip()
            if from_addr not in ALLOWED_SENDERS:
                continue
            if is_loop(msg):
                continue
            if message_id.strip("<>") in replied:
                continue
            entries.append({
                "uid": int(u),
                "from_addr": from_addr,
                "from_name": from_name,
                "subject": dec(msg.get("Subject")),
                "message_id": message_id,
                "date": dec(msg.get("Date")),
                "body": body_text(msg),
            })
        typ, data = m.uid("search", None, "ALL")
        total = len(data[0].split()) if data and data[0] else 0
        print(json.dumps({
            "ok": True,
            "mailbox": {"user": USER, "total": total, "uidvalidity": uidvalidity, "last_uid": last},
            "unseen_allowlisted": entries,
        }, ensure_ascii=False))
    finally:
        try:
            m.logout()
        except Exception:
            pass


def cmd_send(args):
    to_addr = (parseaddr(args.to)[1] or "").lower()
    if to_addr not in ALLOWED_SENDERS:
        raise SystemExit(json.dumps({"ok": False, "error": "recipient not allowlisted"}))
    if args.from_name not in ALLOWED_FROM_NAMES:
        raise SystemExit(json.dumps({"ok": False, "error": "from-name not allowlisted"}))
    body_path = Path(args.body_file)
    if not body_path.is_file():
        raise SystemExit(json.dumps({"ok": False, "error": "body file missing"}))
    body = body_path.read_text(encoding="utf-8")

    source = None
    if args.uid:
        m = connect()
        try:
            m.select("INBOX")
            typ, data = m.uid("fetch", str(args.uid), "(BODY.PEEK[HEADER])")
            raw = b"".join(x[1] for x in data if isinstance(x, tuple))
            if not raw:
                raise SystemExit(json.dumps({"ok": False, "error": "source uid not found"}))
            source = email.message_from_bytes(raw)
            if (parseaddr(dec(source.get("From")))[1] or "").lower() not in ALLOWED_SENDERS:
                raise SystemExit(json.dumps({"ok": False, "error": "source sender not allowlisted"}))
            if is_loop(source):
                raise SystemExit(json.dumps({"ok": False, "error": "loop protection: source is auto-reply"}))
        finally:
            try:
                m.logout()
            except Exception:
                pass

    inreplyto = (args.inreplyto or (source.get("Message-ID") if source else "") or "").strip()
    if not inreplyto:
        raise SystemExit(json.dumps({"ok": False, "error": "missing in-reply-to"}))
    references = ""
    if source is not None and source.get("References"):
        references = dec(source.get("References")) + " " + inreplyto
    else:
        references = inreplyto

    msg = EmailMessage()
    msg["From"] = f"{args.from_name} <{USER}>"
    msg["To"] = to_addr
    msg["Subject"] = args.subject
    msg["Date"] = formatdate(localtime=True)
    msg["Message-ID"] = make_msgid(domain="ai.sieh.org")
    msg["In-Reply-To"] = inreplyto
    msg["References"] = references
    msg["Auto-Submitted"] = "auto-replied"
    msg[LOOP_HEADER] = args.from_name
    msg.set_content(body)

    with smtplib.SMTP(HOST, SMTP_PORT, timeout=30) as smtp:
        smtp.starttls()
        smtp.login(USER, password())
        smtp.send_message(msg)

    if args.uid:
        m = connect()
        try:
            m.select("INBOX")
            m.uid("store", str(args.uid), "+FLAGS", "(\\Seen)")
            state = load_state()
            state["last_uid"] = max(int(state.get("last_uid") or 0), int(args.uid))
            state["uidvalidity"] = int((m.response("UIDVALIDITY")[1] or [b"0"])[0])
            save_state(state)
        finally:
            try:
                m.logout()
            except Exception:
                pass

    print(json.dumps({"ok": True, "to": to_addr, "subject": args.subject, "uid": args.uid}))


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list")
    s = sub.add_parser("send")
    s.add_argument("--to", required=True)
    s.add_argument("--subject", required=True)
    s.add_argument("--body-file", required=True)
    s.add_argument("--uid")
    s.add_argument("--inreplyto", default="")
    s.add_argument("--from-name", default="Shelldon")
    args = p.parse_args()
    if args.cmd == "list":
        cmd_list(args)
    else:
        cmd_send(args)


if __name__ == "__main__":
    main()
