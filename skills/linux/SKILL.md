---
name: linux
description: Expert Linux/sysadmin. À invoquer pour systemd, networking, perf troubleshooting, filesystem, users/permissions, logs, kernel. Déclencheurs : "systemd", "service linux", "iptables", "nftables", "disk", "mount", "journal", "kernel", "cron".
---

# Skill : Linux Sysadmin

Tu es expert Linux senior. Tu débugges en couches (kernel → userland), tu factuelles avant d'opiner.

## Philosophy

- **Mesurer, pas deviner** : `top`, `iostat`, `vmstat`, `strace`, `perf`
- **Logs d'abord** : `journalctl`, `dmesg`, `/var/log/`
- **Une action, une vérif** : après chaque changement, confirmer avant d'enchaîner
- **Pas de sudo cowboy** : minimum de droits, rollback planifié

## systemd (standard moderne)

### Gestion de services
```bash
systemctl status nginx
systemctl start|stop|restart|reload nginx
systemctl enable --now nginx      # active au boot + démarre
systemctl daemon-reload           # après modif d'un unit file
systemctl cat nginx               # voir le unit file effectif
systemctl show nginx              # toutes les properties
systemctl list-units --failed     # services en échec
systemctl list-unit-files         # tous les units
systemctl edit nginx              # override propre (pas modifier /lib/)
```

### Unit file minimal (service)
```ini
[Unit]
Description=My App
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=myapp
Group=myapp
WorkingDirectory=/opt/myapp
ExecStart=/opt/myapp/bin/app
Restart=on-failure
RestartSec=5
StartLimitInterval=60
StartLimitBurst=3
# Hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/myapp

[Install]
WantedBy=multi-user.target
```

### Logs (journald)
```bash
journalctl -u nginx                    # logs d'une unit
journalctl -u nginx -f                 # suivi live
journalctl -u nginx --since "1 hour ago"
journalctl -u nginx -p err             # erreurs seulement
journalctl -b                          # boot courant
journalctl -b -1                       # boot précédent
journalctl --disk-usage                # taille logs
journalctl --vacuum-time=7d            # nettoyage
```

### Timers (alternative moderne à cron)
Unit `.timer` + unit `.service` → mieux intégré, logs journald, dépendances.

## Networking

### IP / routes
```bash
ip a                     # interfaces
ip r                     # routes
ip -s link               # stats interfaces
ss -tulpn                # ports écoutés (remplace netstat)
ss -tan state established  # connexions actives
```

### Firewall — nftables (moderne) ou iptables (legacy)
```bash
# nft
nft list ruleset
nft add rule inet filter input tcp dport 22 accept

# iptables
iptables -L -n -v
iptables -I INPUT -p tcp --dport 22 -j ACCEPT
```

### DNS / connectivity debug
```bash
dig @8.8.8.8 example.com
dig +trace example.com
mtr example.com
curl -v https://example.com
nc -zv example.com 443
tcpdump -i any port 443 -w /tmp/cap.pcap
```

## Filesystems / disques

```bash
df -hT                   # espace + fs type
du -sh /var/* | sort -h  # taille par sous-dossier
lsblk -f                 # disques + fs
mount | column -t        # mounts
findmnt                  # pareil, plus lisible
blkid                    # UUID/labels

# I/O perf
iostat -xz 1 5           # latences / utilisation
iotop                    # par process
```

### LVM
```bash
pvs / vgs / lvs                     # vue d'ensemble
lvextend -L +10G /dev/vg/lv_root && resize2fs /dev/vg/lv_root
```

## Performance troubleshooting

### Load
```bash
uptime                    # load average 1/5/15 min
top / htop / btop
```

### CPU
```bash
mpstat -P ALL 1           # par CPU
pidstat -u 1              # par process
perf top                  # profiling live
```

### Mémoire
```bash
free -h
vmstat 1                  # swap in/out, etc.
smem -tk                  # mémoire réelle par process (PSS)
cat /proc/meminfo
```

### I/O
```bash
iotop -oPa
iostat -xz 1
```

### Network
```bash
iftop          # bande passante
nload          # par interface
nethogs        # par process
```

### Process
```bash
ps aux --sort=-%mem | head
ps auxf        # tree
lsof -p <pid>  # fichiers ouverts
strace -p <pid>  # appels système
strace -f -e openat,read,write -p <pid>
```

## Users / permissions

```bash
id alice
groups alice
passwd alice
usermod -aG docker alice   # ajouter au groupe
chage -l alice             # politique password

# Permissions
chmod u+x,g-w file
chown user:group file
getfacl / setfacl          # ACLs fines
umask 027                  # umask plus strict pour /etc/profile
```

**Règle** : 644 pour configs, 600 pour secrets, 755 pour binaires/dossiers, 700 pour `~/.ssh`.

## Sécurité de base

- **SSH** : `PasswordAuthentication no`, clés obligatoires, `Port` changé optionnel (security through obscurity), `fail2ban`
- **Users** : pas de login direct root, sudo avec timeout
- **Updates** : `unattended-upgrades` pour security, reboots planifiés
- **Audit** : `auditd` pour trace d'accès, `aide` pour intégrité fichiers
- **Firewall** : default deny incoming
- **SELinux / AppArmor** : ne pas désactiver par défaut, apprendre à écrire les policies

## Kernel / limites

```bash
ulimit -a                           # limites du shell courant
/etc/security/limits.conf           # limites par user
sysctl -a | grep <param>
sysctl -w vm.swappiness=10
# Persistant :
echo "vm.swappiness=10" > /etc/sysctl.d/99-custom.conf
sysctl --system
```

Tuning classique serveur :
```
vm.swappiness = 10
fs.file-max = 2097152
net.ipv4.tcp_tw_reuse = 1
net.core.somaxconn = 4096
```

## Cron

```bash
crontab -e         # user
crontab -l         # list
/etc/cron.d/       # system-wide, format avec user
/etc/cron.{hourly,daily,weekly,monthly}/  # scripts simples
```

Préférer systemd timers pour les nouvelles tâches (meilleure observabilité).

## Red flags

- `chmod 777` → presque jamais justifié
- Scripts critiques sans `set -euo pipefail`
- Logs qui remplissent `/` → surveiller + logrotate
- Pas de monitoring RAM/CPU/disk
- SSH en password auth sur IP publique
- Updates de sécurité non appliqués
- `/tmp` plein → process qui crash silencieux
- Swap à 100% en prod → OOM imminent

## Learnings

<!-- Enrichi via /skill-enrich linux -->
