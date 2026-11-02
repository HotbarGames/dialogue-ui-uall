"""Repo guard: a size ratchet for tracked text files and a leak guard for claude-config files.

python3 tools/check_repo.py            check (exit 0 = ok, 1 = problems)
python3 tools/check_repo.py --update   lower the numbers in size-budget.json / drop entries (never raises or adds)
python3 tools/check_repo.py --init     create size-budget.json from today's oversized files (once)

size-budget.json: {"files": {"<path>": {"lines": n, "bytes": n, "maxLine": n}}, "ignore": [{"glob": "data/*.csv",
"reason": "why this is not hand-written code"}]}. Only the numbers over the limits are recorded.

Standard library only. Reads tracked files only (`git ls-files -z`), from the git repo in the current folder.
Tests: python3 -m unittest discover -s tools
"""
import fnmatch
import json
import os
import subprocess
import sys

BUDGET = "size-budget.json"
LIMITS = {"lines": 300, "bytes": 25000, "maxLine": 400}
WHAT = {"lines": "lines", "bytes": "bytes", "maxLine": "longest line (chars)"}

# never committed to these public repos, at any folder level
LEAK_DIRS = {".claude"}
LEAK_FILES = {".mcp.json", "CLAUDE.local.md"}

LOCKFILES = {
    "package-lock.json", "npm-shrinkwrap.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "poetry.lock",
    "Pipfile.lock", "uv.lock", "Cargo.lock", "Gemfile.lock", "composer.lock", "go.sum",
}
BINARY_EXT = {
    ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".ico", ".webp", ".avif", ".tga", ".blp", ".psd", ".tif", ".tiff",
    ".mp3", ".mp4", ".ogg", ".wav", ".flac", ".m4a", ".webm", ".mov", ".avi", ".mkv",
    ".zip", ".gz", ".tgz", ".7z", ".rar", ".bz2", ".xz", ".jar",
    ".pdf", ".ttf", ".otf", ".woff", ".woff2", ".eot",
    ".exe", ".dll", ".so", ".dylib", ".bin", ".pyc", ".wasm", ".db", ".sqlite",
}
# vendored / third-party code and generated or built output (folder names, any level, case-insensitive)
SKIP_DIRS = {
    "vendor", "vendored", "third_party", "third-party", "thirdparty", "node_modules", "bower_components", "libs",
    "dist", "build", "__pycache__", "coverage",
}
HINT = ("Fix: split the file by topic (one feature or section per file) instead of raising its numbers. "
        "Recorded a shrink? `python3 tools/check_repo.py --update` lowers the budget.")


def git_root():
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit("check_repo: not inside a git repository")
    return out.stdout.strip()


def tracked(root):
    out = subprocess.run(["git", "ls-files", "-z"], cwd=root, capture_output=True, check=True)
    return [p for p in out.stdout.decode("utf-8", "surrogateescape").split("\0") if p]


def is_leak(path):
    parts = path.split("/")
    return any(p in LEAK_DIRS for p in parts) or parts[-1] in LEAK_FILES


def ignore_globs(budget):
    globs = []
    for entry in budget.get("ignore", []):
        globs.append(entry if isinstance(entry, str) else entry.get("glob", ""))
    return [g for g in globs if g]


def matches(path, glob):
    if glob.endswith("/"):
        return path.startswith(glob)
    return fnmatch.fnmatchcase(path, glob)


def skip_reason(path, globs):
    """Why a path is not size-checked (None = checked). Content-free checks only."""
    parts = path.split("/")
    name = parts[-1]
    if name in LOCKFILES:
        return "lockfile"
    if os.path.splitext(name)[1].lower() in BINARY_EXT:
        return "binary"
    if any(p.lower() in SKIP_DIRS for p in parts[:-1]):
        return "vendored or generated"
    if ".min." in name or name.endswith(".map"):
        return "generated"
    if any(matches(path, g) for g in globs):
        return "ignored in " + BUDGET
    return None


def measure(full):
    with open(full, "rb") as f:
        data = f.read()
    if b"\0" in data[:8192]:
        return None  # binary
    lines = data.count(b"\n") + (1 if data and not data.endswith(b"\n") else 0)
    text = data.decode("utf-8", "replace")
    longest = max((len(line.rstrip("\r")) for line in text.split("\n")), default=0)
    return {"lines": lines, "bytes": len(data), "maxLine": longest}


def load_budget(root):
    path = os.path.join(root, BUDGET)
    if not os.path.exists(path):
        return None
    try:
        with open(path, encoding="utf-8") as f:
            budget = json.load(f)
    except ValueError as e:
        sys.exit(f"{BUDGET}: not valid JSON ({e})")
    budget.setdefault("files", {})
    budget.setdefault("ignore", [])
    return budget


def save_budget(root, budget):
    budget["files"] = {k: budget["files"][k] for k in sorted(budget["files"])}
    with open(os.path.join(root, BUDGET), "w", encoding="utf-8", newline="\n") as f:
        json.dump(budget, f, indent=2, ensure_ascii=False)
        f.write("\n")


def scan(root, budget):
    """Returns (leaks, sizes): leak paths and {path: metrics} for every size-checked tracked file."""
    globs = ignore_globs(budget)
    leaks, sizes = [], {}
    for path in tracked(root):
        if is_leak(path):
            leaks.append(path)
        full = os.path.join(root, path)
        if skip_reason(path, globs) or os.path.islink(full) or not os.path.isfile(full):
            continue
        m = measure(full)
        if m is not None:
            sizes[path] = m
    return leaks, sizes


def over_limits(m):
    return {k: m[k] for k in LIMITS if m[k] > LIMITS[k]}


def check(root, budget):
    """Returns (problems, notes) as printable lines."""
    leaks, sizes = scan(root, budget)
    problems = [f"{p}: claude-config file must never be committed (git rm --cached '{p}')" for p in leaks]
    notes = []
    files = budget["files"]
    for path, m in sizes.items():
        rec = files.get(path, {})
        for k in LIMITS:
            limit = rec.get(k, LIMITS[k])
            if m[k] > limit:
                tag = " over its budget" if k in rec else ""
                problems.append(f"{path}: {WHAT[k]}{tag} ({m[k]} > {limit})")
        if path in files and not over_limits(m):
            problems.append(f"{path}: now under all limits; remove its entry from {BUDGET} (--update does it)")
        elif any(k in LIMITS and m[k] < v for k, v in rec.items()):
            notes.append(f"{path}: shrank; --update locks in the smaller numbers")
    for path in files:
        if path not in sizes:
            problems.append(f"{path}: in {BUDGET} but not a tracked, size-checked file; remove its entry "
                            "(--update does it)")
    return problems, notes


def update(root, budget):
    """Lowers numbers and removes entries only. Never raises a number, never adds a file."""
    _, sizes = scan(root, budget)
    new = {}
    for path, rec in budget["files"].items():
        m = sizes.get(path)
        if m is None:
            continue
        kept = {k: min(v, m[k]) for k, v in rec.items() if k in LIMITS and m[k] > LIMITS[k]}
        if kept:
            new[path] = kept
    budget["files"] = new
    save_budget(root, budget)


def init(root):
    budget = {"files": {}, "ignore": []}
    _, sizes = scan(root, budget)
    budget["files"] = {p: over_limits(m) for p, m in sizes.items() if over_limits(m)}
    save_budget(root, budget)
    return budget


def main(argv):
    root = git_root()
    budget = load_budget(root)
    if "--init" in argv:
        if budget is not None:
            sys.exit(f"{BUDGET} already exists; --init runs once. Use --update to lower it.")
        budget = init(root)
        print(f"{BUDGET}: recorded {len(budget['files'])} file(s)")
    elif "--update" in argv:
        if budget is None:
            sys.exit(f"no {BUDGET} to update")
        update(root, budget)
    if budget is None:
        budget = {"files": {}, "ignore": []}
    problems, notes = check(root, budget)
    for line in notes:
        print(line)
    for line in problems:
        print(line)
    if problems:
        print(HINT)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
