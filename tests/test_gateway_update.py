"""Isolated lifecycle tests. All service/package/network commands are fakes."""
import contextlib
import io
import json
import os
import pwd
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import gateway_update as update


class FakeCommands:
    def __init__(self, host):
        self.host = host
        self.calls = []
        self.fail = None
        self.installed = "2026.9.8"
        self.target = "2026.9.9"
        self.available = True
        self.service = "active"
        self.pid = "111"
        self.service_user = pwd.getpwuid(os.getuid()).pw_name
        self.clients = []
        self.journal = True
        self.channel_error = False
        self.missing_hook = False
        self.missing_tool = False
        self.shrink_plugins = False
        self.skip_boot_cleanup = False
        self.http_code = "200"
        self.doctor_output = "Doctor complete.\n"
        self.core = host.home / "sdk"
        self.core.mkdir()
        (self.core / "package.json").write_text(json.dumps({"version": self.installed}))

    def active_clients(self):
        return self.clients

    def status(self):
        return {"update": {"root": str(self.core), "registry": {"latestVersion": self.target}},
                "availability": {"available": self.available, "latestVersion": self.target},
                "lastRun": {"status": "succeeded", "runId": "fixture-core-run", "after": {"version": self.installed}}}

    def health(self):
        loaded = ["codex", "vault-access-broker", "discord", "telegram", "google"]
        if self.shrink_plugins:
            loaded.remove("google")
        return {"runtimeVersion": self.installed, "gateway": {"reachable": True},
                "updateRunStatus": {"lastRun": {"status": "succeeded", "runId": "fixture-core-run"}},
                "degradedPlugins": [],
                "health": {"ok": True, "plugins": {"loaded": loaded, "errors": [], "unavailable": []},
                           "channels": {c: {"connected": True, "lifecycle": "ready",
                                            "lastError": "oops" if self.channel_error else None}
                                        for c in ["discord", "telegram"]}}}

    def run(self, name, *args, cwd=None, check=True):
        args = tuple(map(str, args))
        self.calls.append((name, args))
        key = name + " " + " ".join(args)
        if self.fail and key.startswith(self.fail):
            if check:
                raise update.UpdateError("fake failure: " + key)
            return subprocess.CompletedProcess([], 1, "fake failure")
        output = ""
        code = 0
        if name == "systemctl":
            if args[0] == "is-active":
                output = self.service
                code = 0 if self.service == "active" else 3
            elif args[0] == "show":
                output = self.service_user if "--property=User" in args else self.pid
            elif "list-timers" in args:
                output = self.host.watchdog
            else:
                output = "active"
        elif name == "sudo":
            if "stop" in args:
                self.service = "inactive"
                self.pid = "0"
            elif "start" in args:
                if self.service != "active":
                    self.pid = "222"
                self.service = "active"
                if not self.skip_boot_cleanup:
                    for row in update.boot_temps(self.host):
                        path = Path(row["path"])
                        if path.is_dir() and not path.is_symlink():
                            shutil.rmtree(path)
                        else:
                            path.unlink()
        elif name == "curl":
            output = self.http_code
            if self.host.public_url == args[-1]:
                output = f'<html data-openclaw-control-ui-build-id="{self.installed}-build"></html>\n{self.http_code}'
        elif name == "du":
            output = "123\tcache\n"
        elif name == "journalctl":
            if self.journal:
                output = ("vault-access-runtime healthy: bw=PINNED credentials=3\n"
                          "http server listening (5 plugins: codex, vault-access-broker, discord, telegram, google; 1s)\n")
            else:
                output = "permission denied"
                code = 1
        elif name == "openclaw":
            if args == ("--version",):
                output = f"OpenClaw {self.installed} (build)"
            elif args[:2] == ("update", "status"):
                output = json.dumps(self.status())
            elif args[:2] == ("status", "--deep"):
                output = json.dumps(self.health())
            elif args[:3] == ("gateway", "call", "health"):
                output = json.dumps(self.health()["health"])
            elif args[:3] == ("gateway", "call", "plugins.inspect"):
                output = json.dumps({"ok": True, "plugin": {"enabled": True}})
            elif args[:3] == ("gateway", "call", "tools.catalog"):
                output = json.dumps({"agentId": "shelldon", "groups": [{"tools": [] if self.missing_tool else [
                    {"id": "vault_fetch", "optional": True, "pluginId": "vault-access-broker"}]}]})
            elif args[:2] == ("plugins", "inspect"):
                output = json.dumps({"plugin": {"status": "loaded", "activated": True, "enabled": True,
                                                "builtWithOpenClawVersion": self.installed},
                                     "typedHooks": [{"name": "before_tool_call"}] + ([] if self.missing_hook else [
                                         {"name": "tool_result_persist"}]),
                                     "tools": [{"names": ["vault_fetch"], "optional": True}], "diagnostics": []})
        return subprocess.CompletedProcess([], code, output + "\n")

    def stream(self, name, *args, cwd=None, output):
        # Exercise the same injected command seam as the production lifecycle.
        self.run(name, *args, cwd=cwd)
        args = tuple(map(str, args))
        text = "passed\n"
        if name == "openclaw" and args == ("update", "--yes"):
            self.installed = self.target
            (self.core / "package.json").write_text(json.dumps({"version": self.installed}))
        elif name == "openclaw" and args[0] == "doctor":
            text = self.doctor_output
        elif name == "openclaw" and args[:2] == ("plugins", "install"):
            manifest = update.load(Path(args[2]) / "package.json")
            path = self.host.repo / "extensions/vault-access-broker/package.json"
            path.write_text(json.dumps(manifest))
        Path(output).write_text(text)
        return text


class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        repo = self.home / ".openclaw"
        repo.mkdir()
        self.host = update.Host(self.home, repo, {n: n for n in [
            "sudo", "systemctl", "openclaw", "curl", "npm", "pnpm", "ps", "du", "journalctl"]})
        self.host.system_tmp = self.home / "system-tmp"
        self.host.system_tmp.mkdir()
        self.host.broker.mkdir(parents=True)
        fixture = {"name": "openclaw-plugin-vault-access-broker", "version": "0.1.0",
                   "peerDependencies": {"openclaw": "2026.9.8"},
                   "devDependencies": {"openclaw": "2026.9.8"},
                   "openclaw": {"compat": {"pluginApi": "2026.9.8"},
                                "build": {"openclawVersion": "2026.9.8", "pluginSdkVersion": "2026.9.8"}}}
        (self.host.broker / "package.json").write_text(json.dumps(fixture))
        (self.host.broker / "dist").mkdir()
        (self.host.broker / "dist/index.js").write_text("// fake plugin")
        (self.host.broker / "openclaw.plugin.json").write_text('{}')
        (self.host.broker / "README.md").write_text("fixture")
        (self.host.broker / "pnpm-workspace.yaml").write_text(
            "allowBuilds:\n  '@google/genai': true\n  esbuild: true\n  koffi: true\n  openclaw: true\n"
            "  protobufjs: true\n  tree-sitter-bash: true\nminimumReleaseAgeExclude:\n  - openclaw@2026.9.8\n"
            "otherSetting: false\n")
        extension = repo / "extensions/vault-access-broker"
        extension.mkdir(parents=True)
        (extension / "package.json").write_text(json.dumps(fixture))
        self.commands = FakeCommands(self.host)
        capacity = patch.object(update.shutil, "disk_usage", return_value=type(
            "Capacity", (), {"free": 20 * 1024 ** 3})())
        capacity.start()
        self.addCleanup(capacity.stop)
        self.output = contextlib.redirect_stdout(io.StringIO())
        self.output.__enter__()
        self.addCleanup(self.output.__exit__, None, None, None)

    def prepare(self):
        receipt = update.preflight(self.host, self.commands, self.commands.target)
        self.host.runs.mkdir(parents=True, exist_ok=True)
        return update.prepare_run(self.host, receipt)

    def successful_run(self):
        run = self.prepare()
        self.assertEqual(update.worker(self.host, self.commands, run), 0)
        return run

    def test_plan_is_read_only_and_no_live_checks(self):
        before = (self.host.broker / "package.json").read_bytes()
        plan = update.preflight(self.host, self.commands)
        self.assertEqual(plan["candidate"], "2026.9.9")
        self.assertFalse(self.host.guard.exists())
        self.assertFalse(self.host.runs.exists())
        self.assertEqual(before, (self.host.broker / "package.json").read_bytes())
        self.assertFalse(any(n == "curl" or "stop" in a for n, a in self.commands.calls))

    def test_preexisting_guard_and_alias_preserved(self):
        for guard in [self.host.guard, self.host.alias]:
            guard.write_text("owner window")
            with self.assertRaises(update.UpdateError):
                update.preflight(self.host, self.commands)
            self.assertEqual(guard.read_text(), "owner window")
            guard.unlink()

    def test_dangling_guard_symlink_refused(self):
        self.host.guard.symlink_to(self.home / "missing")
        with self.assertRaises(update.UpdateError):
            update.preflight(self.host, self.commands)

    def test_concurrent_cli_refused(self):
        self.commands.clients = ["999"]
        with self.assertRaisesRegex(update.UpdateError, "active"):
            update.preflight(self.host, self.commands)

    def test_second_lifecycle_lock_refused(self):
        fd = update.lock(self.host)
        try:
            with self.assertRaisesRegex(update.UpdateError, "lock"):
                update.lock(self.host)
        finally:
            os.close(fd)

    def test_expectation_mismatch_before_downtime(self):
        with self.assertRaisesRegex(update.UpdateError, "not expected"):
            update.preflight(self.host, self.commands, "2026.9.10")
        self.assertFalse(self.host.guard.exists())

    def test_no_update_start_does_not_create_guard_or_spawn(self):
        self.commands.available = False
        with patch.object(update.subprocess, "Popen") as spawn:
            with self.assertRaisesRegex(update.UpdateError, "No update available"):
                update.start(self.host, self.commands, None)
            spawn.assert_not_called()
        self.assertFalse(self.host.guard.exists())

    def test_unknown_local_plugin_refused(self):
        (self.host.repo / "plugins/new-plugin").mkdir()
        extension = self.host.repo / "extensions/new-plugin"
        extension.mkdir()
        (extension / "package.json").write_text('{"name":"new-plugin"}')
        with self.assertRaisesRegex(update.UpdateError, "Unplanned"):
            update.preflight(self.host, self.commands)

    def test_native_detached_launch_inherits_lock_and_records_pid(self):
        with patch.object(update.subprocess, "Popen") as spawn:
            spawn.return_value.pid = 444
            result = update.start(self.host, self.commands, self.commands.target)
            self.assertTrue(spawn.call_args.kwargs["start_new_session"])
            self.assertEqual(len(spawn.call_args.kwargs["pass_fds"]), 1)
            self.assertEqual(spawn.call_args.kwargs["cwd"], self.host.home)
        self.assertEqual(result["pid"], 444)
        self.assertTrue(update.own_guard(self.host, result["runId"]))

    def test_launch_failure_removes_only_own_guard_before_downtime(self):
        with patch.object(update.subprocess, "Popen", side_effect=OSError("launch refused")):
            with self.assertRaises(OSError):
                update.start(self.host, self.commands, self.commands.target)
        self.assertFalse(self.host.guard.exists())
        self.assertEqual(self.commands.service, "active")

    def test_success_order_and_guard_pending_until_finish(self):
        run = self.successful_run()
        calls = self.commands.calls
        stop = next(i for i, (n, a) in enumerate(calls) if n == "sudo" and "stop" in a)
        core = calls.index(("openclaw", ("update", "--yes")))
        test = calls.index(("npm", ("test",)))
        install = next(i for i, (n, a) in enumerate(calls) if n == "openclaw" and a[:2] == ("plugins", "install"))
        doctor = calls.index(("openclaw", ("doctor", "--fix", "--non-interactive")))
        start = next(i for i, (n, a) in enumerate(calls) if n == "sudo" and "start" in a)
        self.assertTrue(stop < core < test < install < doctor < start)
        self.assertEqual(update.load(run / "state.json")["status"], "awaiting-confirmation")
        self.assertTrue(update.own_guard(self.host, run.name))
        result = update.finish(self.host, self.commands, True)
        self.assertEqual(result["status"], "complete")
        self.assertFalse(self.host.guard.exists())
        self.assertEqual(sum(a == ("doctor", "--fix", "--non-interactive") for n, a in calls), 1)
        self.assertEqual(update.finish(self.host, self.commands, True)["status"], "complete")

    def test_pins_and_workspace_exceptions_updated_idempotently(self):
        update.pin_broker(self.host, "2026.9.9")
        update.pin_broker(self.host, "2026.9.9")
        d = update.load(self.host.broker / "package.json")
        self.assertEqual(d["peerDependencies"]["openclaw"], "2026.9.9")
        self.assertEqual(d["devDependencies"]["openclaw"], "2026.9.9")
        self.assertEqual(d["openclaw"]["compat"]["pluginApi"], "2026.9.9")
        self.assertEqual(set(d["openclaw"]["build"].values()), {"2026.9.9"})
        text = (self.host.broker / "pnpm-workspace.yaml").read_text()
        self.assertEqual(text.count("  - openclaw@2026.9.9"), 1)
        self.assertIn("  - '@openclaw/ai@2026.9.9'\n  - openclaw@2026.9.9\notherSetting:", text)

    def test_update_failure_recovers_and_keeps_guard(self):
        run = self.prepare()
        self.commands.fail = "openclaw update --yes"
        self.assertEqual(update.worker(self.host, self.commands, run), 1)
        self.assertEqual(self.commands.service, "active")
        self.assertTrue(self.host.guard.exists())
        self.assertEqual(update.load(run / "state.json")["status"], "failed")
        self.assertFalse(any(a[:1] == ("doctor",) for n, a in self.commands.calls))
        with self.assertRaises(update.UpdateError):
            update.finish(self.host, self.commands, True)

    def test_rebuild_failure_does_not_run_final_doctor(self):
        run = self.prepare()
        self.commands.fail = "npm test"
        self.assertEqual(update.worker(self.host, self.commands, run), 1)
        self.assertEqual(self.commands.service, "active")
        self.assertFalse(any(a[:1] == ("doctor",) for n, a in self.commands.calls))

    def test_doctor_failure_is_not_success_even_after_recovery(self):
        for output in ["interrupted", "- ERROR vault-access-broker: broken\nDoctor complete",
                       "upgrade is unfinished\nDoctor complete", "status=pending\nDoctor complete"]:
            with self.subTest(output=output), self.assertRaises(update.UpdateError):
                update.doctor_ok(output)
        update.doctor_ok('WAL warning error="read admission closed"\nDoctor complete.')
        run = self.prepare()
        self.commands.doctor_output = "interrupted"
        self.assertEqual(update.worker(self.host, self.commands, run), 1)
        self.assertTrue(self.host.guard.exists())
        self.assertFalse(update.load(run / "state.json").get("doctorPassed"))

    def test_recovery_start_failure_explicit(self):
        run = self.prepare()
        self.commands.fail = "sudo -n systemctl start"
        self.assertEqual(update.worker(self.host, self.commands, run), 1)
        self.assertNotEqual(update.load(run / "state.json")["recoveryStartExit"], 0)
        self.assertTrue(self.host.guard.exists())

    def test_finish_requires_owner_and_fresh_channel_health(self):
        run = self.successful_run()
        with self.assertRaisesRegex(update.UpdateError, "owner"):
            update.finish(self.host, self.commands, False)
        self.commands.channel_error = True
        with self.assertRaisesRegex(update.UpdateError, "ready"):
            update.finish(self.host, self.commands, True)
        self.assertTrue(update.own_guard(self.host, run.name))

    def test_finish_never_removes_replaced_guard_or_alias(self):
        self.successful_run()
        self.host.alias.write_text("other window")
        with self.assertRaises(update.UpdateError):
            update.finish(self.host, self.commands, True)
        self.host.alias.unlink()
        self.host.guard.write_text("replacement")
        with self.assertRaises(update.UpdateError):
            update.finish(self.host, self.commands, True)
        self.assertEqual(self.host.guard.read_text(), "replacement")

    def test_missing_journal_requires_explicit_owner_attestation(self):
        self.successful_run()
        self.commands.journal = False
        with self.assertRaisesRegex(update.UpdateError, "journal verification pending"):
            update.finish(self.host, self.commands, True)
        self.assertTrue(self.host.guard.exists())
        self.assertEqual(update.finish(self.host, self.commands, True, True)["status"], "complete")

    def test_hooks_catalog_and_previous_plugins_are_required(self):
        run = self.successful_run()
        for flag in ["missing_hook", "missing_tool", "shrink_plugins"]:
            setattr(self.commands, flag, True)
            with self.subTest(flag=flag), self.assertRaises(update.UpdateError):
                update.verify(self.host, self.commands, run)
            setattr(self.commands, flag, False)

    def test_watchdog_failure_keeps_guard(self):
        run = self.successful_run()
        self.commands.fail = "systemctl --user is-active"
        with self.assertRaises(update.UpdateError):
            update.finish(self.host, self.commands, True)
        self.assertTrue(update.own_guard(self.host, run.name))

    def test_unexpected_installed_version_fails_before_rebuild(self):
        run = self.prepare()
        self.commands.target = "2026.9.10"
        self.assertEqual(update.worker(self.host, self.commands, run), 1)
        self.assertFalse(any(n == "pnpm" for n, a in self.commands.calls))
        self.assertTrue(self.host.guard.exists())

    def test_other_update_run_cannot_satisfy_finish(self):
        self.successful_run()
        health = self.commands.health()
        health["updateRunStatus"]["lastRun"]["runId"] = "another-upstream-run"
        with patch.object(self.commands, "health", return_value=health):
            with self.assertRaisesRegex(update.UpdateError, "this window|This window"):
                update.finish(self.host, self.commands, True)
        self.assertTrue(self.host.guard.exists())

    def test_pid_receipt_failure_after_launch_does_not_remove_guard(self):
        actual_save = update.save
        def save_without_worker(path, data):
            if Path(path).name == "worker.json":
                raise OSError("receipt write failed")
            return actual_save(path, data)
        with patch.object(update.subprocess, "Popen") as spawn, \
             patch.object(update, "save", side_effect=save_without_worker), \
             contextlib.redirect_stderr(io.StringIO()):
            spawn.return_value.pid = 444
            result = update.start(self.host, self.commands, self.commands.target)
        self.assertEqual(result["status"], "launched")
        self.assertTrue(update.own_guard(self.host, result["runId"]))

    def test_final_recovery_failure_returns_nonzero_even_after_verification(self):
        run = self.prepare()
        actual_run = self.commands.run
        starts = 0
        def fail_second_start(name, *args, **kwargs):
            nonlocal starts
            if name == "sudo" and "start" in args:
                starts += 1
                if starts == 2:
                    return subprocess.CompletedProcess([], 1, "recovery refused")
            return actual_run(name, *args, **kwargs)
        with patch.object(self.commands, "run", side_effect=fail_second_start):
            self.assertEqual(update.worker(self.host, self.commands, run), 1)
        self.assertEqual(update.load(run / "state.json")["status"], "failed")
        self.assertTrue(self.host.guard.exists())

    def test_boot_capture_cleanup_verified_without_reading_contents(self):
        capture = self.host.system_tmp / "openclaw-plugin-build-fixture"
        capture.mkdir()
        evidence = self.host.system_tmp / "openclaw-plugin-build-handoff.md"
        evidence.write_text("must survive")
        run = self.successful_run()
        self.assertFalse(capture.exists())
        self.assertTrue(evidence.exists())
        self.assertTrue(update.load(run / "verification.json")["bootTempCleared"])

    def test_boot_cleanup_failure_blocks_success(self):
        capture = self.host.system_tmp / "openclaw-plugin-build-fixture"
        capture.mkdir()
        self.commands.skip_boot_cleanup = True
        run = self.prepare()
        self.assertEqual(update.worker(self.host, self.commands, run), 1)
        self.assertIn("Boot cleanup", update.load(run / "state.json")["error"])
        self.assertTrue(self.host.guard.exists())

    def test_worker_late_competitor_refusal_does_not_start_service(self):
        run = self.prepare()
        self.commands.clients = ["999"]
        self.assertEqual(update.worker(self.host, self.commands, run), 1)
        self.assertFalse(any(n == "sudo" and ("start" in a or "stop" in a)
                             for n, a in self.commands.calls))
        self.assertFalse(update.load(run / "state.json")["recoveryStartAttempted"])

    def test_different_service_owner_refused(self):
        self.commands.service_user = "some-other-user"
        with self.assertRaisesRegex(update.UpdateError, "service user"):
            update.preflight(self.host, self.commands)
        self.assertFalse(self.host.guard.exists())

    def test_disk_floor_refused_before_guard(self):
        with patch.object(update.shutil, "disk_usage", return_value=type("Capacity", (), {"free": 0})()):
            with self.assertRaisesRegex(update.UpdateError, "5 GiB"):
                update.preflight(self.host, self.commands)
        self.assertFalse(self.host.guard.exists())

    def test_status_receipts_do_not_invoke_cli(self):
        run = self.successful_run()
        (run / "run.log").write_text("recorded")
        fd = update.lock(self.host)
        try:
            calls = list(self.commands.calls)
            view = update.status_view(self.host)
            self.assertTrue(view["operationActive"])
            self.assertTrue(view["guardOwned"])
            self.assertIn("durationSeconds", view["phases"][0])
            self.assertEqual(calls, self.commands.calls)
        finally:
            os.close(fd)

    def test_real_detached_child_retains_inherited_lock(self):
        fd = update.lock(self.host)
        # Real OS detachment/FD inheritance, but no live service or package commands.
        child = subprocess.Popen([sys.executable, "-c",
            "import os,sys; os.fstat(int(sys.argv[1])); print('ready',flush=True); sys.stdin.readline()", str(fd)],
            start_new_session=True, pass_fds=(fd,), stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        try:
            self.assertEqual(child.stdout.readline().strip(), "ready")
            os.close(fd)
            fd = None
            with self.assertRaises(update.UpdateError):
                update.lock(self.host)
            child.communicate("exit\n", timeout=5)
            self.assertEqual(child.returncode, 0)
            released = update.lock(self.host)
            os.close(released)
        finally:
            if fd is not None:
                os.close(fd)
            if child.poll() is None:
                child.kill()
                child.communicate()

    def test_online_readiness_waits_for_channels_without_restarting(self):
        self.commands.channel_error = True
        with self.assertRaisesRegex(update.UpdateError, "startup window"):
            update.gateway_ready(self.host, self.commands, deadline=time.monotonic())
        self.commands.channel_error = False
        update.gateway_ready(self.host, self.commands, deadline=time.monotonic())
        self.assertFalse(any(n == "sudo" for n, a in self.commands.calls))

    def test_http_redirect_does_not_count_as_readiness_or_verification(self):
        run = self.successful_run()
        self.commands.http_code = "302"
        with self.assertRaisesRegex(update.UpdateError, "HTTP ready"):
            update.http_ready(self.host, self.commands, timeout=0)
        with self.assertRaisesRegex(update.UpdateError, "HTTP 200"):
            update.verify(self.host, self.commands, run)

    def test_process_inspection_excludes_gateway_and_shell_but_refuses_other_cli(self):
        commands = update.Commands(self.host)
        processes = ("100 node /usr/bin/node /pkg/openclaw/dist/index.js gateway\n"
                     "200 openclaw openclaw doctor\n"
                     "202 MainThread /usr/bin/node /pkg/openclaw/dist/infra/worker.js\n"
                     "300 bash /bin/bash -c 'openclaw doctor'\n")
        # Bind the fake /proc metadata lookup without touching any real PID.
        with patch.object(commands, "run", return_value=subprocess.CompletedProcess([], 0, processes)), \
             patch.object(Path, "read_text", autospec=True, side_effect=lambda p:
                          self.host.unit if "/100/" in str(p) else "user.slice"):
            self.assertEqual(commands.active_clients(), ["200", "202"])

    def test_unfinished_status_refused_and_absent_history_supported(self):
        actual = self.commands.status()
        actual["lastRun"] = {"status": "running"}
        with patch.object(self.commands, "status", return_value=actual):
            with self.assertRaisesRegex(update.UpdateError, "unfinished"):
                update.preflight(self.host, self.commands)
        actual["lastRun"] = None
        with patch.object(self.commands, "status", return_value=actual):
            self.assertTrue(update.preflight(self.host, self.commands)["available"])

    def test_plugin_ranges_fail_closed(self):
        self.assertTrue(update.check_api(">=2026.9.7", "2026.9.9"))
        self.assertFalse(update.check_api(">=2026.9.10", "2026.9.9"))
        self.assertFalse(update.check_api("^2026.9.7", "2026.9.9"))
        self.assertFalse(update.check_api(">=2026.9.9", "2026.9.9-beta.1"))
        self.assertTrue(update.check_api(">=2026.9.8", "2026.9.9-beta.1"))


if __name__ == "__main__":
    unittest.main()
