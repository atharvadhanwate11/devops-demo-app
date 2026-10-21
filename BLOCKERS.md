# BLOCKERS

Every problem that could not be solved inside the run, the exact error, and
the fallback that was used.

---

## B1 - Minikube with the docker driver is extremely slow in WSL2

**Error / symptom**
```
index.docker.io/kicbase/stable: 133.96 MiB / 507.61 MiB  26.39%  157.31 KiB/s
```
The `kicbase` image (507 MB) is pulled at 150-800 KB/s and the whole
`minikube start` takes tens of minutes. An earlier attempt stalled at 5 % for
12 minutes and produced no container.

**Cause** - the WSL2 virtual disk plus a saturated network link (three
downloads share it), and the docker driver has to unpack a 507 MB image.

**Fallback used** - the pull is left running in the background while the
other phases are verified. If it does not finish, the documented fallback is:

```bash
wsl -u root -e bash -c "export HOME=/home/dhance; minikube start --driver=none --kubernetes-version=v1.37.0"
chown -R dhance:dhance /home/dhance/.minikube /home/dhance/.kube
```
Prerequisites for `--driver=none` are already installed:
`crictl` (`/usr/local/bin/crictl`), CNI plugins (`/opt/cni/bin`),
`/etc/containerd/config.toml`.

**Status** - see PROGRESS.md, phase 4.

---

## B2 - `minikube start --driver=docker` fails when run as root

**Error**
```
* Exiting due to DRV_AS_ROOT: the docker driver should not be used with root privileges
```

**Fallback used** - always start minikube as the normal user `dhance`
(`HOME=/home/dhance`). Root is only used for the `--driver=none` fallback.

---

## B3 - The `none` driver needs three things that were missing

**Errors**
```
Exiting due to GUEST_MISSING_CONNTRACK
Exiting due to NOT_FOUND_CNI_PLUGINS
```

**Fixes applied**
```bash
apt-get install -y crictl conntrack socat iptables ethtool ebtables containernetworking-plugins
mkdir -p /opt/cni/bin && cp -a /usr/lib/cni/. /opt/cni/bin/
mkdir -p /etc/containerd && cp /etc/containerd/config.toml /etc/containerd/config.toml.bak
```

---

## B4 - `kubectl` 1.31.4 was too old for the 1.37 cluster

**Error**
```
error: unable to recognize "...": server version too new
```

**Fix** - kubectl v1.37.0 installed in `~/bin/kubectl` and put first in
`PATH` for every script.

---

## B5 - Jenkins setup wizard is interactive

**Error** - the Jenkins first-run wizard asks for the admin password and the
plugin list in a browser session. It cannot be driven from a script.

**Fallback used** - `scripts/jenkins/01-admin-user.groovy` in
`$JENKINS_HOME/init.groovy.d/` creates the `admin/admin` user, skips the
wizard and disables the "restart to finish the installation" banner, all
before the server accepts requests. The job is then created over the REST API
with a CSRF crumb.

**Manual fallback if the REST job creation fails** - create it in the UI:
1. `http://localhost:8080` -> log in with `admin/admin`.
2. *New Item* -> *Pipeline* -> name `task-api-pipeline`.
3. *Pipeline* -> *Pipeline script from SCM* -> Git ->
   `https://github.com/atharvadhanwate11/devops-demo-app.git`, branch `*/main`.
4. *Save*, then *Build Now*.

---

## B6 - `gh auth login --with-token` was rejected

**Error** - the token is missing the `read:org` scope, so the token-based
login refuses to continue.

**Fallback used** - the token was written directly into
`~/.config/gh/hosts.yml` and `gh auth setup-git` was run, which gives working
`gh` commands and `git push` over HTTPS.

---

## B7 - PowerShell -> WSL argument quoting

**Error** - inline bash through `wsl.exe -e bash -c "..."` gets mangled
(pipes and quotes are eaten) and here-strings piped into `bash -s` add CR
characters that break `head -1` and `tail -n`.

**Fallback used** - every command is written to a script file under
`/home/dhance/scratch/` and executed with `wsl -e bash /path/script.sh`.
Output is written to a log file and read back, because background jobs
otherwise make the tool call return empty output.

---

## B8 - Empty output from a tool call

**Error** - a tool call that starts a background process returns nothing,
even though the process runs fine.

**Fallback used** - `setsid ... < /dev/null > /dev/null 2>&1 &` inside the
script plus a log file that is read afterwards.
