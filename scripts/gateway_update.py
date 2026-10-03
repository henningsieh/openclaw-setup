#!/usr/bin/env python3
"""Native-host update lifecycle. No database access, credentials or auto-repair.

Public commands: plan, start, status, finish. Tests inject command execution at
an internal seam; the production CLI has no executable/path overrides.
"""
import argparse
import dataclasses
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import pwd
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid


class UpdateError(Exception):
    pass


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def load(path):
    return json.loads(Path(path).read_text())


def save(path, value):
    path = Path(path)
    temp = path.with_name(path.name + ".new")
    with temp.open("w") as handle:
        os.chmod(temp, 0o600)
        json.dump(value, handle, indent=2)
        handle.write("\n")
    os.replace(temp, path)


@dataclasses.dataclass
class Host:
    home: Path
    repo: Path
    executables: dict
    unit: str = "openclaw-gateway.service"
    watchdog: str = "openclaw-gateway-watchdog.timer"
    local_url: str = "http://127.0.0.1:18789/"
    public_url: str = "https://ai.sieh.org/"
    system_tmp: Path = Path("/tmp")

    @property
    def runs(self):
        return self.repo / "logs/gateway-updates"

    @property
    def guard(self):
        return self.repo / ".maintenance"

    @property
    def alias(self):
        return self.repo / ".maintainance"

    @property
    def broker(self):
        return self.repo / "plugins/vault-access-broker"

    @classmethod
    def discover(cls):
        if os.getuid() == 0:
            raise UpdateError("Run as the native gateway owner, never root.")
        home = Path(pwd.getpwuid(os.getuid()).pw_dir)
        repo = Path(__file__).resolve().parent.parent
        if repo != home / ".openclaw" or repo.stat().st_uid != os.getuid():
            raise UpdateError("Run the tracked script from the owner's ~/.openclaw repository.")
        search = os.pathsep.join([str(home / ".npm-global/bin"), "/usr/local/bin", "/usr/bin", "/bin"])
        names = ["openclaw", "sudo", "systemctl", "curl", "pnpm", "npm", "ps", "du", "journalctl"]
        exes = {name: shutil.which(name, path=search) for name in names}
        missing = [name for name, value in exes.items() if not value]
        if missing:
            raise UpdateError("Missing commands: " + ", ".join(missing))
        return cls(home, repo, exes)


class Commands:
    def __init__(self, host):
        self.host = host

    def run(self, name, *args, cwd=None, check=True):
        # Maintenance commands deliberately have no short execution deadline.
        argv = [self.host.executables[name], *map(str, args)]
        result = subprocess.run(argv, cwd=cwd or self.host.home, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if check and result.returncode:
            raise UpdateError(f"{name} {' '.join(map(str, args))}: exit {result.returncode}\n{result.stdout}")
        return result

    def stream(self, name, *args, cwd=None, output):
        argv = [self.host.executables[name], *map(str, args)]
        print(f"COMMAND: {name} {' '.join(map(str, args))}", flush=True)
        with Path(output).open("w") as evidence:
            os.chmod(output, 0o600)
            with subprocess.Popen(argv, cwd=cwd or self.host.home, text=True,
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT) as child:
                for line in child.stdout:
                    evidence.write(line)
                    evidence.flush()
                    print(line, end="", flush=True)
                code = child.wait()
        print(f"COMMAND_EXIT={code}: {name}", flush=True)
        if code:
            raise UpdateError(f"{name} exited {code}; evidence: {output}")
        return Path(output).read_text()

    def active_clients(self):
        clients = []
        result = self.run("ps", "-eo", "pid=,comm=,args=")
        for line in result.stdout.splitlines():
            parts = line.strip().split(None, 2)
            if len(parts) != 3:
                continue
            pid, comm, args = parts
            first = args.split()[0]
            native = comm.startswith("openclaw") or (
                Path(first).name == "node" and "/openclaw/dist/" in args)
            if not native:
                continue
            try:
                cgroup = Path(f"/proc/{pid}/cgroup").read_text()
            except FileNotFoundError:
                continue
            if self.host.unit not in cgroup:
                clients.append(pid)
        return clients


def version(commands):
    output = commands.run("openclaw", "--version").stdout
    match = re.search(r"OpenClaw (\d{4}\.\d+\.\d+(?:[-+][\w.]+)?)", output)
    if not match:
        raise UpdateError("Cannot determine installed version from openclaw --version.")
    return match.group(1)


def json_command(commands, *args):
    result = commands.run("openclaw", *args)
    try:
        return json.loads(result.stdout)
    except ValueError as exc:
        raise UpdateError(f"Invalid JSON from openclaw {' '.join(args)}") from exc


def inventory(host):
    rows = []
    for path in sorted((host.repo / "extensions").glob("*/package.json")):
        data = load(path)
        oc = data.get("openclaw", {})
        rows.append({"id": path.parent.name, "name": data.get("name"),
                     "pluginApi": oc.get("compat", {}).get("pluginApi"),
                     "sourceAvailable": (host.repo / "plugins" / path.parent.name).is_dir()})
    return rows


def cache_paths(host):
    candidates = [host.repo / "cache", host.repo / "npm", host.repo / "tmp",
                  host.home / ".cache/openclaw", host.home / ".cache/node-compile-cache",
                  host.system_tmp / "openclaw"]
    candidates += sorted(host.system_tmp.glob("node-compile-cache*"))
    return [str(p) for p in dict.fromkeys(candidates) if p.exists()]


def cache_sizes(host, commands):
    paths = cache_paths(host)
    return commands.run("du", "-sk", *paths, check=False).stdout if paths else ""


def boot_temps(host):
    """Capture only metadata for owned boot-cleanup targets; never read contents."""
    local = host.repo / "tmp"
    paths = list(local.iterdir()) if local.is_dir() else []
    paths += [p for p in host.system_tmp.glob("openclaw-plugin-build-*") if not p.name.endswith(".md")]
    rows = []
    for path in paths:
        try:
            stat = path.lstat()
        except FileNotFoundError:
            continue
        if stat.st_uid == os.getuid():
            rows.append({"path": str(path), "device": stat.st_dev,
                         "inode": stat.st_ino, "ctimeNs": stat.st_ctime_ns})
    return rows


def check_api(declaration, installed):
    # Deliberately narrow: the locally supported plugin is exact-pinned and
    # the registry-managed llama-cpp declares >=. Unknown ranges fail closed.
    if declaration == installed:
        return True
    if isinstance(declaration, str) and re.fullmatch(r">=\s*\d{4}\.\d+\.\d+", declaration):
        numbers = lambda s: tuple(map(int, re.findall(r"\d+", s)))
        base = installed.split("-", 1)[0].split("+", 1)[0]
        current, floor = numbers(base), numbers(declaration)
        prerelease = "-" in installed.split("+", 1)[0]
        return current > floor or (current == floor and not prerelease)
    return False


def preflight(host, commands, expect=None):
    if host.guard.exists() or host.guard.is_symlink() or host.alias.exists() or host.alias.is_symlink():
        raise UpdateError("Existing maintenance guard: preserve it; do not launch another window.")
    clients = commands.active_clients()
    if clients:
        raise UpdateError("Other OpenClaw CLI/updater/Doctor processes are active: " + ", ".join(clients))
    commands.run("sudo", "-n", "-l")  # Permission listing only; never reads service credentials.
    owner = commands.run("systemctl", "show", host.unit, "--property=User", "--value").stdout.strip()
    if owner != pwd.getpwuid(os.getuid()).pw_name:
        raise UpdateError("Caller is not the system unit's configured service user.")
    active = commands.run("systemctl", "is-active", host.unit).stdout.strip()
    if active != "active":
        raise UpdateError(f"Gateway is {active}; recover the current window before starting another.")
    commands.run("systemctl", "--user", "is-active", host.watchdog)
    before = version(commands)
    status = json_command(commands, "update", "status", "--json")
    core_root = Path(status.get("update", {}).get("root", ""))
    if not core_root.is_absolute() or not (core_root / "package.json").is_file():
        raise UpdateError("Update status did not identify an installed core package root.")
    if load(core_root / "package.json").get("version") != before:
        raise UpdateError("Installed core package and CLI version disagree.")
    last_status = (status.get("lastRun") or {}).get("status")
    if last_status and last_status not in {"succeeded", "failed", "abandoned", "cancelled", "interrupted"}:
        raise UpdateError("CLI reports unfinished/unknown update status; follow the runbook recovery branch.")
    latest = (status.get("availability", {}).get("latestVersion") or
              status.get("update", {}).get("registry", {}).get("latestVersion"))
    if expect and latest != expect:
        raise UpdateError(f"Configured-channel candidate is {latest}, not expected {expect}.")
    plugins = inventory(host)
    for plugin in plugins:
        if plugin["sourceAvailable"] and plugin["id"] != "vault-access-broker":
            raise UpdateError(f"Unplanned local plugin {plugin['id']}; add a tested rebuild before downtime.")
    if not host.broker.is_dir():
        raise UpdateError("Vault Access Broker source is missing.")
    free = shutil.disk_usage(host.home).free
    # Capacity floor, not an estimate of updater requirements; CLI owns its preflight.
    if free < 5 * 1024 ** 3:
        raise UpdateError("Less than 5 GiB free on the home volume; resolve capacity before downtime.")
    journal = commands.run("journalctl", "-u", host.unit, "-n", "2000", "--no-pager", "-q", check=False)
    boots = re.findall(r"http server listening \(\d+ plugins: ([^;]+);", journal.stdout)
    previous_plugins = [name.strip() for name in boots[-1].split(",")] if boots else []
    return {"before": before, "candidate": latest, "expected": expect,
            "previousPlugins": previous_plugins,
            "available": bool(status.get("availability", {}).get("available")),
            "coreRoot": str(core_root), "pluginsBefore": plugins,
            "cacheBefore": cache_sizes(host, commands), "freeBytes": free,
            "updateStatusBefore": status}


def lock(host):
    host.runs.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd = os.open(host.runs / ".lock", os.O_RDWR | os.O_CREAT, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(fd)
        raise UpdateError("Another maintenance operation holds the lifecycle lock.")
    return fd


def latest_run(host):
    pointer = host.runs / "latest.json"
    if not pointer.exists():
        raise UpdateError("No maintenance run recorded.")
    run_id = load(pointer)["runId"]
    if not re.fullmatch(r"[0-9TZ-]+-[a-f0-9]{8}", run_id):
        raise UpdateError("Invalid run pointer.")
    return host.runs / run_id


def own_guard(host, run_id):
    return not host.guard.is_symlink() and host.guard.is_file() and host.guard.read_text() == run_id + "\n"


def set_phase(run, phase, **fields):
    data = load(run / "state.json")
    timestamp = now()
    if data.get("phase") != phase:
        phases = data.setdefault("phases", [])
        if phases:
            phases[-1]["endedAt"] = timestamp
            phases[-1]["durationSeconds"] = int((dt.datetime.fromisoformat(timestamp) -
                                               dt.datetime.fromisoformat(phases[-1]["startedAt"])).total_seconds())
        phases.append({"phase": phase, "startedAt": timestamp})
    data.update(phase=phase, updatedAt=timestamp, **fields)
    save(run / "state.json", data)
    print(f"PHASE={phase} {timestamp}", flush=True)


def prepare_run(host, receipt):
    run_id = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:8]
    run = host.runs / run_id
    run.mkdir(mode=0o700)
    save(run / "preflight.json", receipt)
    save(run / "state.json", {"runId": run_id, "phase": "prepared", "status": "running",
                              "startedAt": now(), "before": receipt["before"],
                              "expected": receipt["expected"], "phases": []})
    # Exclusive creation and ownership receipt protect a guard made by someone else.
    with host.guard.open("x") as handle:
        os.chmod(host.guard, 0o600)
        handle.write(run_id + "\n")
    save(host.runs / "latest.json", {"runId": run_id})
    return run


def start(host, commands, expect):
    fd = lock(host)
    try:
        receipt = preflight(host, commands, expect)
        if not receipt["available"]:
            raise UpdateError("No update available on the configured channel; no downtime started.")
        run = prepare_run(host, receipt)
        try:
            with (run / "run.log").open("w") as log:
                os.chmod(run / "run.log", 0o600)
                worker = subprocess.Popen([sys.executable, str(Path(__file__).resolve()),
                                           "_run", str(run), str(fd)], cwd=host.home,
                                          stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                                          start_new_session=True, pass_fds=(fd,))
        except Exception:
            set_phase(run, "launch-failed", status="failed")
            if own_guard(host, run.name):
                host.guard.unlink()  # Service has not been stopped.
            raise
        try:
            save(run / "worker.json", {"pid": worker.pid})
        except OSError as exc:
            # The worker is already running. Never unwind its guard as launch failure.
            print(f"Worker launched; PID receipt write failed: {exc}. Monitor {run / 'run.log'}", file=sys.stderr)
        return {"runId": run.name, "pid": worker.pid, "log": str(run / "run.log"),
                "status": "launched", "note": "No ETA. Monitor status and the log through startup."}
    finally:
        os.close(fd)  # Worker inherits the SAME locked open-file description.


def pin_broker(host, installed):
    package = host.broker / "package.json"
    data = load(package)
    data["peerDependencies"]["openclaw"] = installed
    data["devDependencies"]["openclaw"] = installed
    data["openclaw"]["compat"]["pluginApi"] = installed
    data["openclaw"]["build"].update(openclawVersion=installed, pluginSdkVersion=installed)
    # Source metadata is not a private runtime receipt; preserve its normal mode.
    package.write_text(json.dumps(data, indent=2) + "\n")
    workspace = host.broker / "pnpm-workspace.yaml"
    text = workspace.read_text()
    for name in ["@google/genai", "esbuild", "koffi", "openclaw", "protobufjs", "tree-sitter-bash"]:
        if not re.search(r"^\s+['\"]?" + re.escape(name) + r"['\"]?: true\s*$", text, re.M):
            raise UpdateError(f"Broker workspace must explicitly allow build scripts for {name}.")
    if "minimumReleaseAgeExclude:\n" not in text:
        raise UpdateError("Broker workspace lacks minimumReleaseAgeExclude list.")
    entries = [f"  - '@openclaw/ai@{installed}'\n", f"  - openclaw@{installed}\n"]
    # Insert within this block (not at EOF if other YAML sections follow).
    lines = text.splitlines(keepends=True)
    index = lines.index("minimumReleaseAgeExclude:\n") + 1
    while index < len(lines) and (lines[index].startswith(" ") or not lines[index].strip()):
        index += 1
    missing = [entry for entry in entries if entry.strip() not in {line.strip() for line in lines}]
    lines[index:index] = missing
    workspace.write_text("".join(lines))


def doctor_ok(output):
    if "Doctor complete" not in output:
        raise UpdateError("Final Doctor did not report Doctor complete.")
    if re.search(r"-\s*ERROR\s+\S+:|upgrade is unfinished|status=pending|migration[^\n]*skipped", output, re.I):
        raise UpdateError("Final Doctor left plugin errors or unfinished maintenance; inspect doctor.log.")


def rebuild(host, commands, run, installed, core_root):
    pin_broker(host, installed)
    for label, name, args in [
        ("dependencies", "pnpm", ["install"]), ("tests", "npm", ["test"]),
        ("build", "npm", ["run", "plugin:build"]),
        ("validate", "npm", ["run", "plugin:validate"]),
    ]:
        commands.stream(name, *args, cwd=host.broker, output=run / f"broker-{label}.log")
    # Only this invocation's unique lean staging directory is removed.
    with tempfile.TemporaryDirectory(prefix="vab-install-", dir=host.system_tmp) as temp:
        stage = Path(temp)
        for name in ["dist", "openclaw.plugin.json", "README.md", "package.json"]:
            source = host.broker / name
            if source.is_dir():
                shutil.copytree(source, stage / name)
            else:
                shutil.copy2(source, stage / name)
        commands.stream("npm", "install", "--omit=dev", "--legacy-peer-deps", cwd=stage,
                        output=run / "broker-production-deps.log")
        (stage / "node_modules").mkdir(exist_ok=True)
        peer = stage / "node_modules/openclaw"
        if peer.exists() or peer.is_symlink():
            raise UpdateError("Lean stage unexpectedly installed the core peer dependency.")
        peer.symlink_to(core_root, target_is_directory=True)
        commands.stream("openclaw", "plugins", "install", stage, "--force", "--accept-capabilities",
                        output=run / "broker-install.log")


def http_ready(host, commands, timeout=600):
    deadline = time.monotonic() + timeout
    while True:
        result = commands.run("curl", "--fail", "--silent", "--show-error", "--max-time", "10",
                              "--output", "/dev/null", "--write-out", "%{http_code}", host.local_url, check=False)
        if result.returncode == 0 and result.stdout.strip() == "200":
            return
        if time.monotonic() >= deadline:
            raise UpdateError("Gateway did not become HTTP ready within 10 minutes; recovery is not success.")
        time.sleep(5)


def gateway_ready(host, commands, deadline):
    """Bounded online readiness only; never retries an updater or Doctor."""
    while True:
        result = commands.run("openclaw", "gateway", "call", "health", "--json", "--timeout", "10000", check=False)
        try:
            health = json.loads(result.stdout) if result.returncode == 0 else {}
        except ValueError:
            health = {}
        channels = health.get("channels") or {}
        plugins = health.get("plugins") or {}
        if (health.get("ok") is True and not plugins.get("errors") and not plugins.get("unavailable")
                and {"codex", "vault-access-broker"}.issubset(plugins.get("loaded", []))
                and all((channels.get(c) or {}).get("connected") is True
                        and (channels.get(c) or {}).get("lifecycle") == "ready"
                        and not (channels.get(c) or {}).get("lastError") for c in ["discord", "telegram"])):
            return
        if time.monotonic() >= deadline:
            raise UpdateError("Live Gateway/plugins/channels did not become ready in the startup window.")
        print(f"STARTUP_READINESS: waiting for live Gateway/plugins/channels {now()}", flush=True)
        time.sleep(15)


def require(condition, message):
    if not condition:
        raise UpdateError(message)


def verify(host, commands, run):
    state = load(run / "state.json")
    require(state.get("doctorPassed"), "No successful final Doctor receipt.")
    installed = version(commands)
    require(installed == state["after"], "Installed version changed during this window.")
    require(commands.run("systemctl", "is-active", host.unit).stdout.strip() == "active", "Service not active.")
    pid = commands.run("systemctl", "show", host.unit, "--property=MainPID", "--value").stdout.strip()
    require(pid not in {"0", "", state["oldPid"]}, "No new Gateway PID.")
    local = commands.run("curl", "--fail", "--silent", "--show-error", "--max-time", "20",
                         "--output", "/dev/null", "--write-out", "%{http_code}", host.local_url)
    require(local.stdout.strip() == "200", "Local root did not return HTTP 200.")
    public = commands.run("curl", "--fail", "--silent", "--show-error", "--max-time", "30",
                          "--write-out", "\n%{http_code}", host.public_url).stdout.rstrip()
    html, _, code = public.rpartition("\n")
    require(code == "200" and "data-openclaw-control-ui-build-id" in html and installed in html,
            "Public root did not return HTTP 200 with current Control UI HTML.")
    status = json_command(commands, "status", "--deep", "--json")
    save(run / "status.json", status)
    require(status.get("runtimeVersion") == installed, "Live Gateway version disagrees.")
    last_run = (status.get("updateRunStatus") or {}).get("lastRun") or {}
    require(last_run.get("status") == "succeeded" and last_run.get("runId") == state["coreRunId"],
            "This window's core update is not the current terminal succeeded run.")
    health = status.get("health") or {}
    require(health.get("ok") is True and status.get("gateway", {}).get("reachable") is True,
            "Live Gateway health/RPC failed.")
    plugins = health.get("plugins", {})
    require(not plugins.get("errors") and not plugins.get("unavailable") and not status.get("degradedPlugins"),
            "Gateway has plugin errors/unavailable plugins.")
    require({"codex", "vault-access-broker"}.issubset(plugins.get("loaded", [])), "Required plugins not loaded.")
    for channel in ["discord", "telegram"]:
        channel_state = health.get("channels", {}).get(channel, {})
        require(channel_state.get("connected") is True and channel_state.get("lifecycle") == "ready"
                and not channel_state.get("lastError"), f"{channel} not connected/ready/error-free.")
    live = json_command(commands, "gateway", "call", "plugins.inspect", "--params",
                        '{"pluginId":"vault-access-broker"}', "--json", "--timeout", "60000")
    save(run / "broker-live.json", live)
    require(live.get("ok") is True and live.get("plugin", {}).get("enabled") is True,
            "Live broker inspection failed.")
    runtime = json_command(commands, "plugins", "inspect", "vault-access-broker", "--runtime", "--json")
    save(run / "broker-runtime.json", runtime)
    plugin = runtime.get("plugin", {})
    require(plugin.get("status") == "loaded" and plugin.get("activated") is True
            and plugin.get("enabled") is True and plugin.get("builtWithOpenClawVersion") == installed
            and not runtime.get("diagnostics"), "Broker runtime not healthy or built against another SDK.")
    require({h["name"] for h in runtime.get("typedHooks", [])} == {"before_tool_call", "tool_result_persist"},
            "Broker typed hooks missing or changed.")
    require(any(t.get("optional") is True and "vault_fetch" in t.get("names", [])
                for t in runtime.get("tools", [])), "Broker tool is not registered as optional.")
    catalog = json_command(commands, "gateway", "call", "tools.catalog", "--params",
                           '{"agentId":"shelldon"}', "--json", "--timeout", "60000")
    save(run / "tools.json", catalog)
    tools = [t for g in catalog.get("groups", []) for t in g.get("tools", [])]
    require(catalog.get("agentId") == "shelldon" and any(
        t.get("id") == "vault_fetch" and t.get("optional") is True
        and t.get("pluginId") == "vault-access-broker" for t in tools), "Shelldon lacks optional vault_fetch.")
    rows = inventory(host)
    require(all(check_api(p["pluginApi"], installed) for p in rows), "Installed plugin API mismatch/unsupported range.")
    save(run / "plugins-after.json", rows)
    (run / "cache-after.txt").write_text(cache_sizes(host, commands))
    surviving = []
    for item in state.get("bootTempBefore", []):
        try:
            stat = Path(item["path"]).lstat()
        except FileNotFoundError:
            continue
        if (stat.st_dev, stat.st_ino, stat.st_ctime_ns) == (item["device"], item["inode"], item["ctimeNs"]):
            surviving.append(item["path"])
    require(not surviving, "Boot cleanup left unchanged owned temporary captures: " + ", ".join(surviving))
    journal = commands.run("journalctl", "-u", host.unit, "--since", state["startRequestedAt"],
                           "--no-pager", "-q", check=False)
    (run / "startup-journal.log").write_text(journal.stdout)
    journal_ok = (journal.returncode == 0 and "http server listening" in journal.stdout
                  and "vault-access-runtime healthy:" in journal.stdout and "credentials=3" in journal.stdout)
    # Full expected plugin set is compared against the previous boot if readable.
    previous = load(run / "preflight.json").get("previousPlugins", [])
    require(set(previous).issubset(plugins.get("loaded", [])), "Plugin set shrank since the previous boot.")
    return {"version": installed, "pid": int(pid), "automaticChecks": "passed", "journalPassed": journal_ok,
            "bootTempCleared": True, "ownerUiConfirmed": False, "verifiedAt": now()}


def worker(host, commands, run):
    exit_code = 0
    stop_requested = False
    try:
        require(own_guard(host, run.name) and not host.alias.exists() and not host.alias.is_symlink(),
                "Maintenance guard ownership changed.")
        require(not commands.active_clients(), "Another CLI started after preflight; refusing downtime.")
        old_pid = commands.run("systemctl", "show", host.unit, "--property=MainPID", "--value").stdout.strip()
        set_phase(run, "stop", oldPid=old_pid)
        stop_requested = True
        commands.stream("sudo", "-n", host.executables["systemctl"], "stop", host.unit, output=run / "stop.log")
        require(commands.run("systemctl", "is-active", host.unit, check=False).stdout.strip() == "inactive",
                "Gateway did not stop.")
        set_phase(run, "update")
        commands.stream("openclaw", "update", "--yes", output=run / "update.log")
        installed = version(commands)
        state = load(run / "state.json")
        expected = state["expected"]
        require(installed != state["before"], "Updater did not apply a version change; inspect update.log.")
        require(not expected or installed == expected, f"Installed {installed}, expected {expected}.")
        set_phase(run, "broker-rebuild", after=installed)
        # Resolve again after package replacement, rather than trusting an old path.
        status = json_command(commands, "update", "status", "--json")
        core_root = Path(status["update"]["root"])
        core_run = status.get("lastRun") or {}
        require(core_run.get("runId") and core_run.get("status") == "succeeded"
                and (core_run.get("after") or {}).get("version") == installed,
                "Updater did not record terminal success for the installed core.")
        save(run / "update-status-after.json", status)
        set_phase(run, "broker-rebuild", coreRunId=core_run["runId"])
        require(core_root.is_absolute() and load(core_root / "package.json")["version"] == installed,
                "Updated SDK root/version mismatch.")
        rebuild(host, commands, run, installed, core_root)
        set_phase(run, "final-doctor")
        output = commands.stream("openclaw", "doctor", "--fix", "--non-interactive", output=run / "doctor.log")
        doctor_ok(output)
        set_phase(run, "start", doctorPassed=True, startRequestedAt=now(), bootTempBefore=boot_temps(host))
        commands.stream("sudo", "-n", host.executables["systemctl"], "start", host.unit, output=run / "start.log")
        deadline = time.monotonic() + 600
        http_ready(host, commands, timeout=max(0, deadline - time.monotonic()))
        set_phase(run, "startup-readiness")
        gateway_ready(host, commands, deadline)
        set_phase(run, "verify")
        checks = verify(host, commands, run)
        save(run / "verification.json", checks)
        set_phase(run, "awaiting-confirmation", status="awaiting-confirmation", verification=checks)
        print("AUTOMATIC CHECKS PASSED. Browser/owner confirmation required; guard still present.", flush=True)
    except Exception as exc:
        failed_phase = load(run / "state.json")["phase"]
        set_phase(run, "failed", status="failed", failedPhase=failed_phase, error=str(exc))
        print(f"FAILED: {exc}", flush=True)
        exit_code = 1
    finally:
        # Once stop is requested, recover even after a failed step or SIGTERM.
        # A refusal BEFORE service control must not interfere with another operator.
        recovery_code = 0
        if stop_requested:
            try:
                recovery = commands.run("sudo", "-n", host.executables["systemctl"], "start", host.unit, check=False)
                recovery_code = recovery.returncode
            except Exception as exc:
                recovery_code = -1
                print(f"SERVICE_RECOVERY_FAILED: {exc}", flush=True)
        state = load(run / "state.json")
        state["recoveryStartAttempted"] = stop_requested
        state["recoveryStartExit"] = recovery_code
        if recovery_code:
            state.update(status="failed", error="Service recovery start failed; inspect run.log.")
            exit_code = 1
        state["workerExitedAt"] = now()
        save(run / "state.json", state)
        print(f"RECOVERY_START_EXIT={recovery_code}; guard retained until finish.", flush=True)
    return exit_code


def finish(host, commands, owner_ui, journal_confirmed=False):
    require(owner_ui, "Explicit --owner-ui-confirmed required after rendering and signed-in connection checks.")
    fd = lock(host)
    try:
        run = latest_run(host)
        state = load(run / "state.json")
        require(state["status"] in {"awaiting-confirmation", "complete"}, "Run failed or still active; cannot finish.")
        if state["status"] == "complete":
            require(not host.guard.exists() and not host.guard.is_symlink() and
                    not host.alias.exists() and not host.alias.is_symlink(), "A new/unowned guard exists; preserve it.")
            commands.run("systemctl", "--user", "is-active", host.watchdog)
            return {"status": "complete", "runId": run.name, "guardRemoved": True}
        require(own_guard(host, run.name) and not host.alias.exists() and not host.alias.is_symlink(),
                "Guard missing/replaced or alias guard exists; preserve it.")
        checks = verify(host, commands, run)  # Fresh read-only probes, never another Doctor.
        require(checks["journalPassed"] or journal_confirmed,
                "Startup journal verification pending; owner must inspect it before --journal-confirmed.")
        checks.update(ownerUiConfirmed=True, journalConfirmed=journal_confirmed)
        commands.run("systemctl", "--user", "is-active", host.watchdog)
        timer = commands.run("systemctl", "--user", "list-timers", "--all", "--no-pager").stdout
        require(host.watchdog in timer, "Watchdog not listed; keep the guard.")
        require(own_guard(host, run.name), "Guard changed during verification; preserve it.")
        host.guard.unlink()
        try:
            commands.run("systemctl", "--user", "is-active", host.watchdog)
        except Exception:
            # Re-pause if the timer ceased to be active at the cleanup boundary.
            with host.guard.open("x") as guard:
                guard.write(run.name + "\n")
            raise
        checks["guardRemoved"] = True
        save(run / "verification.json", checks)
        set_phase(run, "complete", status="complete", verification=checks, finishedAt=now())
        return {"status": "complete", "runId": run.name, "guardRemoved": True, "watchdog": "armed"}
    finally:
        os.close(fd)


def status_view(host):
    run = latest_run(host)
    data = load(run / "state.json")
    busy = False
    fd = os.open(host.runs / ".lock", os.O_RDWR)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            busy = True
    finally:
        os.close(fd)
    data["operationActive"] = busy
    data["guardOwned"] = own_guard(host, run.name)
    data["worker"] = load(run / "worker.json") if (run / "worker.json").exists() else None
    data["aliasGuardPresent"] = host.alias.exists() or host.alias.is_symlink()
    clock = dt.datetime.now(dt.timezone.utc)
    data["elapsedSeconds"] = int((clock - dt.datetime.fromisoformat(data["startedAt"])).total_seconds())
    if data.get("phases"):
        data["phaseElapsedSeconds"] = int((clock - dt.datetime.fromisoformat(data["phases"][-1]["startedAt"])).total_seconds())
    data["log"] = str(run / "run.log")
    data["logModifiedAt"] = dt.datetime.fromtimestamp((run / "run.log").stat().st_mtime,
                                                     dt.timezone.utc).isoformat() if (run / "run.log").exists() else None
    if data["status"] == "running" and not busy:
        data["attention"] = "Worker no longer holds lock without a terminal receipt; inspect log/service. Do not claim success."
    return data


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(prog="gateway-update.sh", description=__doc__)
    subs = parser.add_subparsers(dest="command", required=True, metavar="{plan,start,status,finish}")
    subs.add_parser("plan", help="Read-only CLI preflight; no downtime, guard or run creation")
    begin = subs.add_parser("start", help="Launch one detached maintenance window")
    begin.add_argument("--expect-version", help="Validate configured-channel target; never sets --tag/channel")
    subs.add_parser("status", help="Read receipts, phase timings and lock state; no OpenClaw probe")
    end = subs.add_parser("finish", help="Verify and remove only this successful run's guard")
    end.add_argument("--owner-ui-confirmed", action="store_true")
    end.add_argument("--journal-confirmed", action="store_true", help="Owner verified startup journal when access unavailable")
    internal = subs.add_parser("_run", help=argparse.SUPPRESS)
    internal.add_argument("run")
    internal.add_argument("fd", type=int)
    subs._choices_actions = [choice for choice in subs._choices_actions if choice.dest != "_run"]
    args = parser.parse_args()
    try:
        host = Host.discover()
        commands = Commands(host)
        if args.command == "plan":
            result = preflight(host, commands)
            # The detailed upstream JSON stays private in run receipts, not chat output.
            result.pop("updateStatusBefore")
            print(json.dumps(result, indent=2))
        elif args.command == "start":
            print(json.dumps(start(host, commands, args.expect_version), indent=2))
        elif args.command == "status":
            view = status_view(host)
            # Exact errors live in private logs; status is intended for owner review.
            print(json.dumps(view, indent=2))
        elif args.command == "finish":
            print(json.dumps(finish(host, commands, args.owner_ui_confirmed, args.journal_confirmed), indent=2))
        else:
            run = Path(args.run).resolve()
            require(run.parent == host.runs.resolve() and run == latest_run(host), "Invalid worker run directory.")
            os.fstat(args.fd)
            require(os.path.samefile(f"/proc/self/fd/{args.fd}", host.runs / ".lock"),
                    "Worker did not inherit the lifecycle lock descriptor.")
            fcntl.flock(args.fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            require(own_guard(host, run.name), "Worker has no owned maintenance guard.")
            def interrupted(signum, frame):
                raise UpdateError(f"Worker interrupted by signal {signum}; recovery attempted, not success.")
            signal.signal(signal.SIGTERM, interrupted)
            signal.signal(signal.SIGINT, interrupted)
            # Lock FD remains inherited until process exit.
            return worker(host, commands, run)
        return 0
    except (UpdateError, OSError, ValueError, KeyError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
