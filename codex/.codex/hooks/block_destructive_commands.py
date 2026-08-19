#!/usr/bin/env python3
"""Block destructive Bash commands from Codex PreToolUse hooks."""

from __future__ import annotations

import json
import os
import pathlib
import re
import shlex
import sys
import tempfile
from collections.abc import Sequence


CONTROL_CHARS = frozenset(";&|()")
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
SHELLS = {"bash", "dash", "fish", "ksh", "sh", "zsh"}
SHELL_KEYWORDS = {"!", "{", "}", "do", "elif", "else", "if", "then", "while", "until"}

DIRECTLY_DESTRUCTIVE = {
    "halt": "system halt",
    "mke2fs": "filesystem creation",
    "mkfs": "filesystem creation",
    "mkswap": "swap filesystem creation",
    "poweroff": "system power-off",
    "reboot": "system reboot",
    "rmdir": "directory deletion",
    "rm": "file deletion",
    "shred": "secure file overwrite",
    "shutdown": "system shutdown",
    "truncate": "file truncation",
    "unlink": "file deletion",
    "wipefs": "filesystem signature removal",
}

WRAPPER_OPTIONS_WITH_VALUE = {
    "doas": {"-C", "-u"},
    "exec": {"-a"},
    "env": {"-C", "-S", "--chdir", "--split-string", "--unset", "-u"},
    "ionice": {"-c", "-n", "-p", "-P", "-u"},
    "nice": {"-n", "--adjustment"},
    "sudo": {
        "-C",
        "-D",
        "-g",
        "-h",
        "-p",
        "-R",
        "-T",
        "-u",
        "--chdir",
        "--group",
        "--host",
        "--prompt",
        "--role",
        "--type",
        "--user",
    },
    "time": {"-f", "-o", "--format", "--output"},
}


def executable_name(token: str) -> str:
    return os.path.basename(token).lower()


def informational_only(args: Sequence[str]) -> bool:
    for arg in args:
        # After "--" these are filename operands, not options.
        if arg == "--":
            return False
        if arg in {"--help", "--version"}:
            return True
    return False


def is_control(token: str) -> bool:
    return bool(token) and set(token) <= CONTROL_CHARS


def separate_unquoted_newlines(command: str) -> str:
    result: list[str] = []
    single_quoted = False
    double_quoted = False
    escaped = False

    for char in command:
        if escaped:
            result.append(char)
            escaped = False
            continue
        if char == "\\" and not single_quoted:
            result.append(char)
            escaped = True
            continue
        if char == "'" and not double_quoted:
            single_quoted = not single_quoted
        elif char == '"' and not single_quoted:
            double_quoted = not double_quoted
        if char == "\n" and not single_quoted and not double_quoted:
            # Emit the newline first: shlex ends a `#` comment at end of
            # line, so a trailing ";" would be swallowed by a comment and the
            # next line would merge into the commented command.
            result.append("\n;")
        else:
            result.append(char)
    return "".join(result)


HEREDOC = re.compile(r"""<<-?[ \t]*(?![<])(['"]?)([A-Za-z_][A-Za-z0-9_]*)\1""")


def strip_heredocs(command: str, *, only_quoted: bool = False) -> str:
    """Drop heredoc bodies so their lines are not parsed as commands.

    With only_quoted, keep unquoted bodies: bash expands substitutions there, so
    they still need scanning, while a quoted delimiter makes the body literal.
    """
    if "<<" not in command:
        return command

    lines = command.split("\n")
    kept: list[str] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        kept.append(line)
        index += 1
        for match in HEREDOC.finditer(line):
            quoted = bool(match.group(1))
            delimiter = match.group(2)
            # A quoted delimiter makes the body literal; an unquoted one still
            # expands substitutions, so keep those lines when the caller only
            # wants literal bodies removed.
            drop = quoted or not only_quoted
            while index < len(lines):
                body = lines[index]
                index += 1
                if body.strip() == delimiter:
                    if not drop:
                        kept.append(body)
                    break
                if not drop:
                    kept.append(body)
    return "\n".join(kept)


def tokenize(command: str) -> list[str]:
    normalized = separate_unquoted_newlines(strip_heredocs(command))
    lexer = shlex.shlex(normalized, posix=True, punctuation_chars=";&|()<>")
    lexer.whitespace_split = True
    lexer.commenters = "#"
    return list(lexer)


def command_segments(tokens: Sequence[str]) -> list[list[str]]:
    segments: list[list[str]] = []
    current: list[str] = []
    for token in tokens:
        if is_control(token):
            if current:
                segments.append(current)
                current = []
            continue
        current.append(token)
    if current:
        segments.append(current)
    return segments


def redirection_reason(tokens: Sequence[str]) -> str | None:
    """Flag `>` onto a file that already exists; the shell truncates it."""
    for position, token in enumerate(tokens):
        if not token or not set(token) <= set("<>&|") or ">" not in token:
            continue
        if ">>" in token:  # append does not truncate
            continue
        if position + 1 >= len(tokens):
            continue
        target = tokens[position + 1]
        # Character devices are not user data.
        if target.startswith("/dev/"):
            continue
        if looks_like_path(target):
            return "output redirection over an existing file"
    return None


def skip_redirections(tokens: Sequence[str], index: int) -> int:
    while index < len(tokens):
        token = tokens[index]
        if token.isdigit() and index + 1 < len(tokens) and any(
            char in tokens[index + 1] for char in "<>"
        ):
            index += 1
            token = tokens[index]
        if not token or not all(char in "<>&" for char in token):
            break
        index += 2
    return index


def skip_wrapper(tokens: Sequence[str], index: int, wrapper: str) -> int:
    index += 1
    options_with_value = WRAPPER_OPTIONS_WITH_VALUE.get(wrapper, set())

    while index < len(tokens):
        token = tokens[index]
        if token == "--":
            return index + 1
        if wrapper == "env" and ASSIGNMENT.match(token):
            index += 1
            continue
        if not token.startswith("-") or token == "-":
            break

        option = token.split("=", 1)[0]
        index += 1
        if option in options_with_value and "=" not in token and index < len(tokens):
            index += 1

    return index


def contains_flag(args: Sequence[str], short: str, long: str) -> bool:
    for arg in args:
        if arg == long:
            return True
        if arg.startswith("-") and not arg.startswith("--") and short in arg[1:]:
            return True
    return False


def positional_operands(args: Sequence[str]) -> list[str]:
    operands: list[str] = []
    for arg in args:
        if arg == "--":
            break
        if arg.startswith("-") and arg != "-":
            continue
        operands.append(arg)
    return operands


def looks_like_path(arg: str) -> bool:
    return arg.startswith(("./", "../", "/")) or os.path.exists(arg)


def git_subcommand(args: Sequence[str]) -> tuple[str, list[str]]:
    index = 0
    global_options_with_value = {"-C", "-c", "--exec-path", "--git-dir", "--namespace", "--work-tree"}
    while index < len(args):
        token = args[index]
        if token == "--":
            index += 1
            break
        if not token.startswith("-"):
            break
        option = token.split("=", 1)[0]
        index += 1
        if option in global_options_with_value and "=" not in token and index < len(args):
            index += 1
    if index >= len(args):
        return "", []
    return args[index].lower(), list(args[index + 1 :])


def git_reason(args: Sequence[str]) -> str | None:
    if informational_only(args):
        return None
    subcommand, subargs = git_subcommand(args)
    dry_run = contains_flag(subargs, "n", "--dry-run")

    if subcommand == "rm":
        return "Git file deletion"
    if subcommand == "reset" and "--hard" in subargs:
        return "destructive Git hard reset"
    if subcommand == "clean" and not dry_run:
        return "destructive Git clean"
    if subcommand == "checkout" and (
        contains_flag(subargs, "f", "--force")
        or ("--" in subargs and subargs.index("--") < len(subargs) - 1)
        # Without "--", git treats an operand naming an existing file as a
        # pathspec and overwrites it from the index, discarding edits.
        or any(looks_like_path(arg) for arg in positional_operands(subargs))
    ):
        return "destructive Git checkout"
    # --staged alone touches only the index, but --worktree overwrites files
    # even when both are given.
    if subcommand == "switch" and (
        contains_flag(subargs, "f", "--force") or "--discard-changes" in subargs
    ):
        return "destructive Git switch"
    if (
        subcommand == "worktree"
        and positional_operands(subargs)[:1] == ["remove"]
        and contains_flag(subargs, "f", "--force")
    ):
        return "forced Git worktree removal"
    if subcommand == "restore" and (
        "--staged" not in subargs or contains_flag(subargs, "W", "--worktree")
    ):
        return "destructive Git working-tree restore"
    if subcommand == "branch" and any(
        arg in {"-d", "-D", "--delete"}
        or (arg.startswith("-") and not arg.startswith("--") and any(flag in arg[1:] for flag in "dD"))
        for arg in subargs
    ):
        return "Git branch deletion"
    if subcommand == "push" and (
        contains_flag(subargs, "f", "--force")
        or any(
            arg == "--force-with-lease" or arg.startswith("--force-with-lease=")
            for arg in subargs
        )
        or "--delete" in subargs
        or "--mirror" in subargs
        or any(arg.startswith(":") and len(arg) > 1 for arg in subargs)
    ):
        return "destructive Git push"
    if subcommand == "stash" and positional_operands(subargs)[:1] in (["drop"], ["clear"]):
        return "Git stash deletion"
    if subcommand == "prune" or (subcommand == "reflog" and "expire" in subargs):
        return "Git history pruning"
    if subcommand == "gc" and any(arg == "--prune=now" for arg in subargs):
        return "immediate Git history pruning"
    return None


def disk_reason(command: str, args: Sequence[str]) -> str | None:
    if command == "dd":
        if any(arg in {"--help", "--version"} for arg in args):
            return None
        return "raw block copy or overwrite"
    if command == "fdisk":
        return None if any(arg in {"-l", "--list", "--help", "--version"} for arg in args) else "disk partition edit"
    if command == "sfdisk":
        readonly = {"--dump", "--help", "--list", "--verify", "--version"}
        return None if any(arg in readonly for arg in args) else "disk partition edit"
    if command == "parted":
        readonly = {"-l", "--list", "--help", "--version", "print"}
        return None if any(arg in readonly for arg in args) else "disk partition edit"
    if command == "cfdisk":
        return "interactive disk partition edit"
    if command == "diskutil" and args:
        destructive = {
            "apfsdeletecontainer",
            "apfsdeletevolume",
            "apfserasecontainer",
            "erasedisk",
            "erasevolume",
            "partitiondisk",
            "randomdisk",
            "secureerase",
            "zerodisk",
        }
        if args[0].lower() in destructive:
            return "disk erase or partition operation"
    return None


def platform_reason(command: str, args: Sequence[str]) -> str | None:
    lowered = [arg.lower() for arg in args]
    dry_run = any(arg == "--dry-run" or arg.startswith("--dry-run=") for arg in lowered)
    if command in {"kubectl", "oc"} and "delete" in lowered and not dry_run:
        return "cluster resource deletion"
    if command == "helm" and any(arg in {"delete", "uninstall"} for arg in lowered):
        return "Helm release deletion"
    if command in {"terraform", "tofu"} and (
        "destroy" in lowered or ("apply" in lowered and "-destroy" in lowered)
    ):
        return "infrastructure destruction"
    if command in {"docker", "podman"} and lowered:
        destructive_subcommands = {"rm", "rmi", "prune"}
        if lowered[0] in destructive_subcommands:
            return "container resource deletion"
        if len(lowered) > 1 and lowered[1] in destructive_subcommands and lowered[0] in {
            "builder",
            "container",
            "image",
            "network",
            "system",
            "volume",
        }:
            return "container resource deletion or pruning"
        if lowered[0] == "compose" and "down" in lowered and any(
            arg in {"-v", "--volumes"} for arg in lowered
        ):
            return "container volume deletion"
    return None


def database_reason(command: str, args: Sequence[str]) -> str | None:
    if informational_only(args):
        return None
    if command in {"dropdb", "dropuser"}:
        return "database object deletion"
    joined = " ".join(args)
    destructive_sql = re.compile(
        r"\b(?:DROP\s+(?:DATABASE|SCHEMA|TABLE)|TRUNCATE(?:\s+TABLE)?|DELETE\s+FROM)\b",
        re.IGNORECASE,
    )
    if command in {"mysql", "psql", "sqlite3"} and destructive_sql.search(joined):
        return "destructive SQL statement"
    if command == "redis-cli" and re.search(r"\bFLUSH(?:ALL|DB)\b", joined, re.IGNORECASE):
        return "Redis database flush"
    return None


def segment_reason(tokens: Sequence[str]) -> str | None:
    if reason := redirection_reason(tokens):
        return reason

    index = skip_redirections(tokens, 0)
    while index < len(tokens) and (ASSIGNMENT.match(tokens[index]) or tokens[index] in SHELL_KEYWORDS):
        index += 1
        index = skip_redirections(tokens, index)

    wrappers = {"command", "doas", "env", "exec", "ionice", "nice", "nohup", "sudo", "time"}
    while index < len(tokens) and executable_name(tokens[index]) in wrappers:
        wrapper = executable_name(tokens[index])
        boundary = skip_wrapper(tokens, index, wrapper)
        # Only the wrapper's own options count; `command rm -rf build -v` passes
        # -v to rm, and must not be read as `command -v`.
        wrapper_flags = tokens[index + 1 : boundary]
        if wrapper == "command" and any(arg in {"-v", "-V"} for arg in wrapper_flags):
            return None
        if wrapper == "sudo" and any(arg in {"-l", "--list", "-v", "--validate"} for arg in wrapper_flags):
            return None
        index = boundary
        index = skip_redirections(tokens, index)

    if index >= len(tokens):
        return None

    command = executable_name(tokens[index])
    args = list(tokens[index + 1 :])

    if command in DIRECTLY_DESTRUCTIVE and not informational_only(args):
        return DIRECTLY_DESTRUCTIVE[command]
    if command.startswith("mkfs."):
        return "filesystem creation"

    disk = disk_reason(command, args)
    if disk:
        return disk

    if command == "git":
        reason = git_reason(args)
        if reason:
            return reason

    if command == "rsync" and not contains_flag(args, "n", "--dry-run"):
        delete_modes = {
            "--del",
            "--delete",
            "--delete-after",
            "--delete-before",
            "--delete-delay",
            "--delete-during",
            "--delete-excluded",
        }
        if any(arg in delete_modes for arg in args):
            return "rsync destination deletion"

    if command == "find" and "-delete" in args:
        return "find-based file deletion"
    if command == "find":
        for marker in ("-exec", "-execdir"):
            if marker in args:
                nested = segment_reason(args[args.index(marker) + 1 :])
                if nested:
                    return nested

    if command == "xargs":
        options_with_value = {
            "-a",
            "-E",
            "-I",
            "-L",
            "-n",
            "-P",
            "-s",
            "--arg-file",
            "--eof",
            "--max-args",
            "--max-chars",
            "--max-lines",
            "--max-procs",
            "--replace",
        }
        position = 0
        while position < len(args):
            token = args[position]
            if token == "--":
                position += 1
                break
            if not token.startswith("-") or token == "-":
                break
            option = token.split("=", 1)[0]
            position += 1
            if option in options_with_value and "=" not in token and position < len(args):
                position += 1
        if position < len(args):
            return segment_reason(args[position:])

    if command in SHELLS:
        for position, token in enumerate(args):
            # A long option such as --norc contains "c" but is not -c.
            if token == "-c" or (
                token.startswith("-") and not token.startswith("--") and "c" in token[1:]
            ):
                if position + 1 < len(args):
                    return destructive_reason(args[position + 1])
                break
    if command == "eval" and args:
        return destructive_reason(" ".join(args))

    return platform_reason(command, args) or database_reason(command, args)


def command_substitutions(command: str) -> list[str]:
    substitutions: list[str] = []
    index = 0
    single_quoted = False
    double_quoted = False

    while index < len(command):
        char = command[index]
        if char == "\\":
            index += 2
            continue
        if char == "'" and not double_quoted:
            single_quoted = not single_quoted
            index += 1
            continue
        if char == '"' and not single_quoted:
            double_quoted = not double_quoted
            index += 1
            continue
        if single_quoted:
            index += 1
            continue

        if char == "`":
            end = index + 1
            while end < len(command):
                if command[end] == "\\":
                    end += 2
                    continue
                if command[end] == "`":
                    substitutions.append(command[index + 1 : end])
                    index = end + 1
                    break
                end += 1
            else:
                index += 1
            continue

        if (
            command.startswith("$(", index) and not command.startswith("$((", index)
        ) or command.startswith("<(", index) or command.startswith(">(", index):
            depth = 1
            end = index + 2
            nested_single = False
            nested_double = False
            while end < len(command):
                nested_char = command[end]
                if nested_char == "\\":
                    end += 2
                    continue
                if nested_char == "'" and not nested_double:
                    nested_single = not nested_single
                elif nested_char == '"' and not nested_single:
                    nested_double = not nested_double
                elif not nested_single and nested_char == "(":
                    depth += 1
                elif not nested_single and nested_char == ")":
                    depth -= 1
                    if depth == 0:
                        substitutions.append(command[index + 2 : end])
                        index = end + 1
                        break
                end += 1
            else:
                index += 2
            continue

        index += 1

    return substitutions


def destructive_reason(command: str) -> str | None:
    if re.search(r":\s*\(\s*\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:", command):
        return "shell fork bomb"

    for substitution in command_substitutions(strip_heredocs(command, only_quoted=True)):
        if reason := destructive_reason(substitution):
            return reason

    try:
        tokens = tokenize(command)
    except ValueError:
        return "command could not be parsed safely"

    for segment in command_segments(tokens):
        reason = segment_reason(segment)
        if reason:
            return reason
    return None


def deny(reason: str) -> None:
    message = (
        f"Blocked destructive command ({reason}). "
        "Run it manually outside Codex or disable this hook in /hooks if the operation is intentional."
    )
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": message,
                }
            }
        )
    )


def run_self_test() -> int:
    blocked = [
        "rm -rf build",
        "cd /tmp && /bin/rm stale.txt",
        "sudo -u root git reset --hard HEAD",
        "git clean -fdx",
        "git checkout -- README.md",
        "git restore src/app.ts",
        "find . -delete",
        "bash -lc 'rm -rf build'",
        "echo $(rm -f tmp.txt)",
        "docker system prune -af",
        "kubectl delete namespace production",
        "terraform destroy -auto-approve",
        "psql -c 'DROP TABLE users'",
        "diskutil eraseDisk APFS Empty /dev/disk4",
        "dd if=image.iso of=/dev/disk4",
        "shutdown -h now",
        ":(){ :|:& };:",
        "echo \"$(rm -f tmp.txt)\"",
        "printf result-`git clean -fd`",
        "xargs -0 rm < files.txt",
        # Regressions fixed after review of PR #17
        "git checkout README.md",
        "git restore --staged --worktree src/app.ts",
        "git push --force-with-lease=main",
        "bash --norc -c 'rm -rf build'",
        "exec rm -rf build",
        "echo preparing # harmless comment\nrm -rf build",
        "git stash drop",
        "git stash clear",
        # Second review round
        "echo replacement > README.md",
        "> README.md",
        "git push --mirror origin",
        "git switch --discard-changes other",
        "git switch -f other",
        "git worktree remove --force ../wt",
        "cat <(rm -rf build)",
        "rm -- --help",
        "git rm -- --help",
        "rsync -a --delete empty/ destination/",
        "command rm -rf build -v",
        "sudo rm -rf build -v",
        "cat <<EOF\n$(rm -rf build)\nEOF",
    ]
    allowed = [
        "echo rm -rf build",
        "printf '%s\\n' 'git reset --hard'",
        "git status",
        "git reset --soft HEAD~1",
        "git clean -ndx",
        "git restore --staged src/app.ts",
        "find . -name '*.tmp' -print",
        "bash -lc 'echo rm'",
        "docker system df",
        "kubectl get pods",
        "terraform plan",
        "psql -c 'SELECT 1'",
        "diskutil list",
        "fdisk -l",
        "dd --version",
        "rm --help",
        "git restore --help",
        "kubectl delete pod demo --dry-run=client",
        "command -v rm",
        "sudo -l rm",
        "xargs -I{} echo rm {}",
        "echo ok # rm -rf ignored-comment",
        "python3 -c 'print(\"rm -rf build\")'",
        "printf '%s' '`rm -rf build`'",
        "printf '%s' \"line one\nrm -rf build\"",
        # Regressions fixed after review of PR #17
        "git checkout main",
        "git restore --staged src/app.ts",
        "git stash list",
        "cat <<'EOF'\nrm -rf build\nEOF",
        "cat <<-EOF\nrm -rf build\nEOF",
        "bash --norc -c 'echo rm'",
        # Second review round
        "cat <<'EOF'\n$(rm -rf build)\nEOF",
        "echo x > brand-new-output.txt",
        "echo x >> README.md",
        "ls > /dev/null",
        "rsync -a --delete --dry-run empty/ destination/",
        "git switch other",
        "git worktree remove ../wt",
        "git worktree list",
    ]

    # looks_like_path() consults the filesystem, so pin the checks to a
    # scratch directory holding one known file.
    original_cwd = os.getcwd()
    with tempfile.TemporaryDirectory() as scratch:
        os.chdir(scratch)
        pathlib.Path("README.md").write_text("")
        try:
            failures = _collect_failures(blocked, allowed)
        finally:
            os.chdir(original_cwd)

    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print(f"Passed {len(blocked) + len(allowed)} destructive-command hook checks.")
    return 0


def _collect_failures(blocked: Sequence[str], allowed: Sequence[str]) -> list[str]:
    failures = []
    for command in blocked:
        if destructive_reason(command) is None:
            failures.append(f"expected block: {command}")
    for command in allowed:
        if reason := destructive_reason(command):
            failures.append(f"expected allow ({reason}): {command}")
    return failures


def main() -> int:
    if sys.argv[1:] == ["--self-test"]:
        return run_self_test()

    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        deny("hook input could not be parsed safely")
        return 0

    command = payload.get("tool_input", {}).get("command")
    if not isinstance(command, str) or not command.strip():
        return 0

    if reason := destructive_reason(command):
        deny(reason)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
