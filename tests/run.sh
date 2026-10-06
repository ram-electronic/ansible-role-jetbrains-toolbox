#!/usr/bin/env bash
# Test roles/jetbrains_toolbox in a fresh, disposable container (Debian/Ubuntu or Arch Linux),
# as root. Installs Ansible, runs the role twice and checks the result. Used by CI
# (.github/workflows/ci.yml) and tests/docker.sh. Do not run on your own system:
# it installs packages and creates the user "tester".
#
# Exit code: 0 = all checks passed.

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR=/home/tester
TOOLBOX="$HOME_DIR/.local/opt/jetbrains-toolbox"
FAIL=0

ok()  { printf '  ok:   %s\n' "$1"; }
bad() { printf '  FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

[[ -f /.dockerenv || -n ${CI:-} ]] || { echo "Run only in a disposable container (see header)." >&2; exit 1; }

echo "== Install Ansible"
if command -v apt-get >/dev/null; then
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -qq
	apt-get install -y -qq ansible-core ca-certificates >/dev/null
else
	pacman -Sy --noconfirm --needed ansible >/dev/null  # with community.general (pacman module)
fi
grep PRETTY_NAME /etc/os-release
ansible --version | head -1

export ANSIBLE_NOCOLOR=1 ANSIBLE_LOCALHOST_WARNING=0 ANSIBLE_PYTHON_INTERPRETER=auto_silent

run_playbook() {
	echo "== Run $1"
	ansible-playbook -i localhost, "$TESTS_DIR/test.yml" | tee "/tmp/run-$1.log"
}

run_playbook 1 || { echo "First run failed"; exit 1; }
run_playbook 2 || { echo "Second run failed"; exit 1; }

echo "== Checks"
if grep -Eq 'localhost +: .*changed=0 ' /tmp/run-2.log; then
	ok "second run changed nothing (idempotent)"
else
	bad "second run changed something: $(grep -E 'localhost +:' /tmp/run-2.log)"
fi

if [[ -x $TOOLBOX/bin/jetbrains-toolbox ]]; then
	ok "Toolbox App installed in $TOOLBOX"
else
	bad "$TOOLBOX/bin/jetbrains-toolbox missing"
fi

for path in "$HOME_DIR/.local" "$HOME_DIR/.local/opt" "$TOOLBOX" "$TOOLBOX/bin/jetbrains-toolbox" \
	"$HOME_DIR/.local/share/applications/jetbrains-toolbox.desktop"; do
	owner=$(stat -c %U "$path" 2>/dev/null || echo missing)
	if [[ $owner == tester ]]; then ok "$path owned by tester"; else bad "$path owned by $owner"; fi
done

# The dependencies are what the app's native libraries link against. Not counted:
# libjvm.so (the bundled JVM, loaded at runtime) and libasound.so.2 (only Java Sound,
# unused by the Toolbox App, not in JetBrains' requirements).
missing=$(find "$TOOLBOX/bin" -type f \( -name '*.so*' -o -name jetbrains-toolbox \) -exec ldd {} \; 2>/dev/null \
	| grep 'not found' | grep -vE '^\s*(libjvm\.so|libasound\.so\.2) ' | sort -u || true)
if [[ -z $missing ]]; then
	ok "no missing shared libraries"
else
	bad "missing shared libraries:"
	echo "$missing"
fi

echo
if (( FAIL )); then echo "$FAIL check(s) failed"; else echo "All checks passed"; fi
exit "$FAIL"
