#!/bin/sh
# vps-sampler.sh — one-shot resource sample for the cheap one-box VPS.
#
# Run once per minute from cron. Appends one row to host.csv and one row per
# running container to containers.csv. Pure /proc + coreutils + docker — no
# sysstat/top/mpstat dependency, so it works on a bare Debian/Ubuntu box.
#
# Purpose: collect ~1 week of data to decide whether the Netcup VPS 1000 G12
# (4 vCore / 8 GB) is sustainable, i.e. whether to commit to the annual plan.
#
# Install/collect/remove is driven by .github/workflows/vps-monitoring.yml.

set -eu

# cron runs with a bare PATH; make sure docker/flock/nproc resolve.
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
export PATH

OUT_DIR="${VPS_MON_DIR:-/opt/deepiri/monitoring}"
HOST_CSV="$OUT_DIR/host.csv"
CONT_CSV="$OUT_DIR/containers.csv"
MAX_BYTES="${VPS_MON_MAX_BYTES:-52428800}"   # 50 MiB per file: rotate guard

mkdir -p "$OUT_DIR"

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- load average + cpu count -------------------------------------------------
# /proc/loadavg: "0.42 0.38 0.35 1/523 12345"
read -r L1 L5 L15 _ < /proc/loadavg
NCPU="$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo)"

# --- procs in uninterruptible sleep (usually disk I/O wait) ------------------
PROCS_BLOCKED="$(awk '/^procs_blocked/ {print $2}' /proc/stat)"
[ -n "${PROCS_BLOCKED:-}" ] || PROCS_BLOCKED=0

# --- CPU busy% and steal% over a 1s window ----------------------------------
# /proc/stat line 1: cpu  user nice system idle iowait irq softirq steal ...
# CPU utilisation only exists as a delta, hence the 1s sleep between reads.
read -r _ U1 N1 S1 I1 W1 IRQ1 SIRQ1 ST1 _ < /proc/stat
sleep 1
read -r _ U2 N2 S2 I2 W2 IRQ2 SIRQ2 ST2 _ < /proc/stat

D_IDLE=$(( (I2 + W2) - (I1 + W1) ))
D_STEAL=$(( ST2 - ST1 ))
D_TOTAL=$(( (U2+N2+S2+I2+W2+IRQ2+SIRQ2+ST2) - (U1+N1+S1+I1+W1+IRQ1+SIRQ1+ST1) ))

if [ "$D_TOTAL" -gt 0 ]; then
	CPU_BUSY="$(awk "BEGIN{printf \"%.1f\", (1 - $D_IDLE/$D_TOTAL) * 100}")"
	CPU_STEAL="$(awk "BEGIN{printf \"%.1f\", ($D_STEAL/$D_TOTAL) * 100}")"
else
	CPU_BUSY="0.0"
	CPU_STEAL="0.0"
fi

# --- memory + swap (MiB) ---------------------------------------------------
MEM_TOTAL="$(awk '/^MemTotal:/     {printf "%d", $2/1024}' /proc/meminfo)"
MEM_AVAIL="$(awk '/^MemAvailable:/ {printf "%d", $2/1024}' /proc/meminfo)"
MEM_USED=$(( MEM_TOTAL - MEM_AVAIL ))
SWAP_TOTAL="$(awk '/^SwapTotal:/ {printf "%d", $2/1024}' /proc/meminfo)"
SWAP_FREE="$(awk '/^SwapFree:/  {printf "%d", $2/1024}' /proc/meminfo)"
SWAP_USED=$(( SWAP_TOTAL - SWAP_FREE ))

# --- disk (used %) -------------------------------------------------------
DISK_ROOT="$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')"
DISK_DATA="$(df -P /var/lib/docker 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')"
[ -n "${DISK_DATA:-}" ] || DISK_DATA="$DISK_ROOT"

# --- write host row ------------------------------------------------------
if [ ! -f "$HOST_CSV" ]; then
	echo "ts,load1,load5,load15,ncpu,cpu_busy_pct,cpu_steal_pct,procs_blocked,mem_total_mb,mem_used_mb,mem_avail_mb,swap_used_mb,disk_root_pct,disk_data_pct" > "$HOST_CSV"
fi
echo "$TS,$L1,$L5,$L15,$NCPU,$CPU_BUSY,$CPU_STEAL,$PROCS_BLOCKED,$MEM_TOTAL,$MEM_USED,$MEM_AVAIL,$SWAP_USED,$DISK_ROOT,$DISK_DATA" >> "$HOST_CSV"

# --- per-container rows ------------------------------------------------
# Skip quietly if docker is unavailable; the host row is still useful.
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
	if [ ! -f "$CONT_CSV" ]; then
		echo "ts,name,cpu_pct,mem_used,mem_limit,pids" > "$CONT_CSV"
	fi
	# MemUsage looks like "142MiB / 7.6GiB": split on "/", trim spaces.
	docker stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.PIDs}}' 2>/dev/null \
		| awk -F'|' -v ts="$TS" '
			{
				gsub(/%/, "", $2)
				n = split($3, m, "/")
				used = m[1]; limit = (n > 1 ? m[2] : "")
				gsub(/^[ \t]+|[ \t]+$/, "", used)
				gsub(/^[ \t]+|[ \t]+$/, "", limit)
				print ts "," $1 "," $2 "," used "," limit "," $4
			}' >> "$CONT_CSV"
fi

# --- rotate guard: keep a runaway file from filling the disk we measure ---
for f in "$HOST_CSV" "$CONT_CSV"; do
	if [ -f "$f" ] && [ "$(wc -c < "$f")" -gt "$MAX_BYTES" ]; then
		mv "$f" "$f.$(date -u +%Y%m%dT%H%M%SZ).old"
	fi
done
