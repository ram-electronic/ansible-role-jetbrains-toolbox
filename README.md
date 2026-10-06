# Ansible role: jetbrains_toolbox

Installs the [JetBrains Toolbox App](https://www.jetbrains.com/toolbox-app/) for one user on
Arch Linux and Debian/Ubuntu. The IDEs themselves (IntelliJ IDEA, PhpStorm, PyCharm, RustRover,
…) are then installed and kept up to date from within the Toolbox App. It has no command line
for that on Linux.

- Downloads the **latest** release from JetBrains' release API and verifies its **sha256**
  (x86_64 and aarch64).
- Unpacks it to `~/.local/opt/jetbrains-toolbox`. The Toolbox App runs from there and **updates
  itself** there, so the role only installs it when it is missing and never replaces it.
- Installs the libraries it needs (JetBrains system requirements). Can be turned off.
- Adds a menu entry for the first start. The Toolbox App then writes its own menu and
  autostart entries.
- Idempotent: a second run changes nothing.

## Requirements

- Arch Linux, Debian or Ubuntu. Other distributions work with
  `jetbrains_toolbox_install_dependencies: false` (install the libraries from
  [`vars/main.yml`](vars/main.yml) yourself).
- ansible-core 2.16 or newer. On Arch Linux also `community.general` (for the `pacman`
  module), which the `ansible` package includes.
- Runs as root (`become: true`) and sets the owner of everything it creates to the user.
- Internet access to `data.services.jetbrains.com` and `download.jetbrains.com`.

## Installation

From Ansible Galaxy:

```
ansible-galaxy role install ram_electronic.jetbrains_toolbox
```

Or in `requirements.yml`, straight from GitHub:

```yaml
roles:
  - name: ram_electronic.jetbrains_toolbox
    src: https://github.com/ram-electronic/ansible-role-jetbrains-toolbox
    version: v1.0.0
```

## Role variables

| Variable | Default | Description |
|---|---|---|
| `jetbrains_toolbox_user` | **required** | User who gets the Toolbox App. |
| `jetbrains_toolbox_dir` | `""` | Install directory. Empty means `~/.local/opt/jetbrains-toolbox` of the user. Directories inside the home are created owned by the user; existing parent directories keep their mode. |
| `jetbrains_toolbox_install_dependencies` | `true` | Install the libraries the Toolbox App needs (Arch Linux and Debian family). Fails with a clear message on other distributions; set to `false` there. |
| `jetbrains_toolbox_menu_entry` | `true` | Add `~/.local/share/applications/jetbrains-toolbox.desktop` for the first start (not overwritten afterwards). |
| `jetbrains_toolbox_releases_url` | JetBrains release API | Where the latest release is looked up. |

The variables are validated against [`meta/argument_specs.yml`](meta/argument_specs.yml).

## Example playbook

```yaml
- hosts: workstations
  become: true
  roles:
    - role: ram_electronic.jetbrains_toolbox
      vars:
        jetbrains_toolbox_user: alice
```

Afterwards the user starts "JetBrains Toolbox" from the application menu, logs in and installs
the IDEs there.

## Notes

- IDEs are installed to `~/.local/share/JetBrains/Toolbox/apps` (1–3 GB each), their caches
  to `~/.cache/JetBrains`. On Btrfs with snapshots of `/home` (e.g. Snapper), consider making
  these nested subvolumes before the first start, so they are not part of the snapshots.
- To update the Toolbox App, let it update itself. The role does not touch an existing install.
- Uninstall: quit the Toolbox App, delete the install directory,
  `~/.local/share/JetBrains/Toolbox` and the `jetbrains-toolbox.desktop` files in
  `~/.local/share/applications` and `~/.config/autostart`.

## Testing

`tests/docker.sh` runs the role twice in fresh Debian 13, Ubuntu 24.04 and Arch Linux
containers (needs Docker) and checks the result: idempotency, file ownership, no missing
shared libraries. CI runs the same on every pull request and weekly, because the role
always installs the latest Toolbox App.

```
tests/docker.sh                 # all images
tests/docker.sh debian:13       # just one
```

## License

[MIT](LICENSE)
