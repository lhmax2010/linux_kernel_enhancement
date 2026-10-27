#!/usr/bin/bash
# User-run only. Do not source. The agent validates this file with bash -n only.
# External commands below are installed system tools; no external helper scripts.
set -uo pipefail
readonly WS=/home/linhao/Toolchain/development/linux_kernel_optimization
readonly KERNEL=/home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi
readonly WORK=/home/linhao/Toolchain/development/linux_kernel_optimization/temp
readonly GBS_HOME=/home/linhao/Toolchain/development/linux_kernel_optimization/temp/gbs-home
readonly SCRIPT=/home/linhao/Toolchain/development/linux_kernel_optimization/scripts/run_baseline_build.sh
readonly EXPECTED=f240c28093027707f5e09f8a9cbbed16a43ebb1a
readonly TIZEN=42aeefac58edeb081aff440f0b60be71cbe49755
export TMPDIR="$WORK" PYTHONDONTWRITEBYTECODE=1
# Deliberately do not export HOME or GIT_CONFIG_NOSYSTEM in this shell.
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

stamp() { /usr/bin/date --iso-8601=seconds; }
declare -A result=([preflight]=PENDING [export]=PENDING [gcc]=PENDING [llvm]=PENDING)
declare -A code=([preflight]=- [export]=- [gcc]=- [llvm]=-)
declare -A started=([preflight]=- [export]=- [gcc]=- [llvm]=-)
declare -A ended=([preflight]=- [export]=- [gcc]=- [llvm]=-)
status_file="$WORK/run_baseline_build.preflight.$$.status"
current=preflight
final_label='FAILED at preflight'
interrupted=0
handoff=0
active_pid=
command_rc=0
known_outside=0

write_status() {
    local phase status_tmp="${status_file}.new.$$"
    {
        printf 'BASE %s\nUPDATED %s\n' "$EXPECTED" "$(stamp)"
        for phase in preflight export gcc llvm; do
            printf 'STAGE %s result=%s exit=%s start=%s end=%s\n' \
                "$phase" "${result[$phase]}" "${code[$phase]}" \
                "${started[$phase]}" "${ended[$phase]}"
        done
        [[ -z $active_pid ]] || printf 'ACTIVE-OR-RESIDUAL PGID=%s (no signals sent)\n' "$active_pid"
        [[ ${1:-} != final ]] || printf 'ALL-END %s %s\n' "$(stamp)" "$final_label"
    } > "$status_tmp" && /usr/bin/mv -- "$status_tmp" "$status_file"
}
finish() {
    local rc=$? phase
    trap - EXIT
    if (( handoff )); then return; fi
    if (( interrupted )) && [[ ${result[$current]} == OK ]]; then
        result[$current]=FAILED; code[$current]=130; ended[$current]=$(stamp)
        final_label="FAILED at $current"
    fi
    if [[ ${result[$current]} == RUNNING ]]; then
        result[$current]=FAILED
        code[$current]=$rc
        (( rc != 0 )) || code[$current]=125
        ended[$current]=$(stamp)
        if [[ $current == gcc || $current == llvm ]]; then
            printf 'SUPERVISOR-EXIT: abnormal shell exit; raw log may remain active.\nBUILD-END %s %s exit=%s\n' \
                "$current" "${ended[$current]}" "${code[$current]}" >> "$WORK/build_${current}_r2.log"
        fi
    fi
    for phase in export gcc llvm; do
        if [[ ${result[$phase]} == PENDING ]]; then result[$phase]=SKIPPED; fi
    done
    write_status final || printf 'ERROR: cannot write ALL-END to %s\n' "$status_file" >&2
}
on_interrupt() {
    interrupted=1
    final_label="FAILED at $current"
    printf 'INTERRUPTED %s phase=%s; no signals forwarded; active command may continue.\n' "$(stamp)" "$current" >&2
    # Worker lets an active command finish naturally; it will not start another.
    if [[ ${1:-} == foreground ]]; then exit 130; fi
    write_status
}
fail() {
    local rc=$1; shift
    printf 'FAILED %s: %s\n' "$current" "$*" >&2
    result[$current]=FAILED; code[$current]=$rc; ended[$current]=$(stamp)
    final_label="FAILED at $current"
    exit "$rc"
}
within_ws() { [[ $1 == "$WS" || $1 == "$WS/"* ]]; }

# Return this group's live rows only; no kill, pkill or sudo cleanup.
group_rows() {
    /usr/bin/ps -eo pid=,ppid=,pgid=,user=,stat=,args= |
        /usr/bin/awk -v group="$1" '$3 == group && $5 !~ /^Z/ {print}'
}
group_snapshot() {
    printf 'PROCESS-GROUP %s PGID=%s\n' "$(stamp)" "$1"
    group_rows "$1"
}
observe_output_paths() {
    local group=$1 out=$2 pid ppid pgid owner state args fd target
    while read -r pid ppid pgid owner state args; do
        for fd in 1 2; do
            target=$(/usr/bin/readlink -- "/proc/$pid/fd/$fd" 2>/dev/null) || continue
            target=${target% (deleted)}
            case "$target" in
                /*) ;;
                *) continue ;;
            esac
            case "$target" in /dev/*|/proc/*|/sys/*) continue ;; esac
            if ! within_ws "$target"; then
                # Writable stdout/stderr of a member of THIS group is direct evidence.
                printf '%s PID=%s PGID=%s fd=%s path=%s\n' "$(stamp)" "$pid" "$group" "$fd" "$target" >> "$out"
                known_outside=1
            fi
        done
    done < <(group_rows "$group")
}
wait_residuals() {
    local group=$1 log=$2 deadline=$((SECONDS + 300)) rows
    rows=$(group_rows "$group")
    if [[ -n $rows ]]; then
        printf 'Residual group %s: waiting up to five minutes; no signals/sudo.\n' "$group" >> "$log"
        while [[ -n $rows ]] && (( SECONDS < deadline )); do
            /usr/bin/sleep 5
            rows=$(group_rows "$group")
        done
    fi
    group_snapshot "$group" >> "$log"
    [[ -z $rows ]]
}

# Job control makes the command leader a separate process group, while retaining
# the login session/controlling terminal used by foreground sudo -v (no setsid).
run_managed() {
    local phase=$1 log=$2; shift 2
    local pid state rc=0 monitor_rc=0 actual_group last_scan=$SECONDS
    local group_log="$WORK/${phase}_r2.processes.log"
    local raw_log="${log}.raw" command_end
    known_outside=0
    printf 'BEFORE %s\n' "$(stamp)" > "$group_log"
    /usr/bin/ps -eo pid=,ppid=,pgid=,user=,stat=,args= >> "$group_log"
    : > "$WORK/${phase}_r2.observed_outside.txt"
    : > "$raw_log"
    printf '%s-START %s %s\n' "${phase^^}" "$phase" "$(stamp)" >> "$log"
    printf 'LIVE-OUTPUT %s\n' "$raw_log" >> "$log"
    set -m
    "$@" >> "$raw_log" 2>&1 < /dev/null &
    pid=$!
    active_pid=$pid
    printf '%s\n' "$pid" > "$WORK/${phase}_r2.pgid"
    actual_group=$(/usr/bin/ps -o pgid= -p "$pid" 2>/dev/null) || actual_group=
    actual_group=${actual_group//[[:space:]]/}
    # An already exited short-lived command has no row. Do not signal on mismatch.
    if [[ -n $actual_group && $actual_group != "$pid" ]]; then
        printf 'Unexpected PGID %s for leader %s; will wait, then fail.\n' "$actual_group" "$pid" >> "$group_log"
        monitor_rc=125
    fi
    group_snapshot "$pid" >> "$group_log"
    write_status
    while :; do
        state=$(/usr/bin/ps -o stat= -p "$pid" 2>/dev/null) || state=
        state=${state//[[:space:]]/}
        [[ -n $state && $state != Z* ]] || break
        if [[ $state == *T* || $state == *t* ]]; then
            printf 'Command stopped (possibly terminal authentication); no signal sent.\n' >> "$group_log"
            monitor_rc=125
            break
        fi
        if (( SECONDS - last_scan >= 15 )); then
            observe_output_paths "$pid" "$WORK/${phase}_r2.observed_outside.txt"
            last_scan=$SECONDS
        fi
        /usr/bin/sleep 5
    done
    # With job control, wait without -f also reports a stopped job. It does not
    # resume/terminate it. Interrupted waits are retried only while it is running.
    while :; do
        wait "$pid"; rc=$?
        state=$(/usr/bin/ps -o stat= -p "$pid" 2>/dev/null) || state=
        state=${state//[[:space:]]/}
        if [[ -n $state && $state != *T* && $state != *t* && $state != Z* ]]; then continue; fi
        break
    done
    command_rc=$rc
    command_end=$(stamp)
    observe_output_paths "$pid" "$WORK/${phase}_r2.observed_outside.txt"
    if ! wait_residuals "$pid" "$group_log"; then
        printf 'Residuals remain after five minutes; stopped here without cleanup.\n' >> "$log"
        monitor_rc=125
    else
        active_pid=
    fi
    # Children only own the raw log. The report log can always end in its
    # BUILD-END marker, even if residuals keep writing after the five-minute wait.
    /usr/bin/cat "$raw_log" >> "$log"
    if [[ -z $active_pid ]]; then
        printf 'COMMAND-END %s %s exit=%s\n' "$phase" "$command_end" "$rc" >> "$log"
    else
        printf 'COMMAND-NOT-CLOSED %s %s wait_status=%s; descendants/stopped job remain.\n' "$phase" "$(stamp)" "$rc" >> "$log"
    fi
    (( monitor_rc == 0 )) || return "$monitor_rc"
    (( interrupted == 0 )) || return 130
    (( rc == 0 )) || return "$rc"
    (( known_outside == 0 )) || return 90
    return 0
}

runtime_path() {
    case "$1" in
        /|/etc|/etc/ld.so.cache|/etc/ld.so.preload|/etc/passwd|/etc/group|/etc/nsswitch.conf|\
        /etc/localtime|/etc/locale.alias|/etc/locale.conf|/etc/locale.gen|/etc/default/locale|\
        /etc/hosts|/etc/hostname|/etc/host.conf|/etc/resolv.conf|/etc/gai.conf|\
        /etc/ssl/openssl.cnf|/etc/ssl/certs|/etc/ssl/certs/*|/etc/pam.d/*|\
        /etc/sudoers|/etc/sudoers.d/*) return 0 ;;
        *) return 1 ;;
    esac
}
# strace -yy supplies resolved fd paths for successful opens. Track cwd and fork
# inheritance for successful relative mkdirs. Unknown/truncated/escaped paths
# fail closed, rather than guessing that they were inside the workspace.
trace_audit() {
    local trace="$WORK/export_check.strace" summary="$WORK/export_check_home.txt"
    local line pid body call path parent target child returned n=0 bad=0 first_pid=
    local re_line='^([0-9]+)[[:space:]]+(.*)$'
    local re_open='^[[:space:]]*(open|openat)\('
    # -yy may show e.g. 3</dev/null<char 1:3>>; stop at the next angle bracket.
    local re_fd='=[[:space:]]*[0-9]+<([^<>]+)'
    local re_ok='=[[:space:]]*0[[:space:]]*$'
    local re_child='=[[:space:]]*([0-9]+)[[:space:]]*$'
    local re_mkdir='^mkdir\("([^"]*)"'
    local re_mkdirat='^mkdirat\(([^,]*),[[:space:]]*"([^"]*)"'
    local re_chdir='^chdir\("([^"]*)"'
    local re_angle='<([^>]+)>'
    declare -A cwd=() pending=() a=() b=() c=() issues=()
    [[ -s $trace ]] || return 91
    while IFS= read -r line; do
        [[ $line =~ $re_line ]] || { issues["Unparsed trace line: $line"]=1; bad=1; continue; }
        pid=${BASH_REMATCH[1]}; body=${BASH_REMATCH[2]}
        if [[ -z $first_pid ]]; then first_pid=$pid; cwd[$pid]=$KERNEL; fi
        if [[ $body == *'<unfinished ...>'* ]]; then
            pending[$pid]=${body%'<unfinished ...>'*}; continue
        fi
        if [[ $body == '<... '* ]]; then
            if [[ -z ${pending[$pid]+yes} ]]; then
                issues["Unmatched resumed syscall: $line"]=1; bad=1; continue
            fi
            body=${pending[$pid]}${body#*resumed>}; unset 'pending[$pid]'
        fi
        case "$body" in
            '+++ '*|'--- '*) continue ;;
        esac
        if [[ $body =~ ^(clone|clone3|fork|vfork)\( && $body =~ $re_child ]]; then
            child=${BASH_REMATCH[1]}
            [[ -z ${cwd[$pid]+yes} ]] || cwd[$child]=${cwd[$pid]}
        elif [[ $body =~ $re_chdir && $body =~ $re_ok ]]; then
            [[ $body =~ $re_chdir ]]; target=${BASH_REMATCH[1]}
            if [[ $target != /* ]]; then target=${cwd[$pid]:-UNKNOWN}/$target; fi
            if [[ $target == /* && $target != *'\'* ]]; then cwd[$pid]=$(/usr/bin/realpath -m -- "$target"); else unset 'cwd[$pid]'; fi
        elif [[ $body == fchdir\(* && $body =~ $re_ok ]]; then
            if [[ $body =~ $re_angle ]]; then cwd[$pid]=${BASH_REMATCH[1]}; else unset 'cwd[$pid]'; fi
        fi
        if [[ $body =~ $re_open ]]; then
            # Failed opens are retained in raw trace but are not successful reads.
            [[ $body == *'= -1 '* ]] && continue
            if [[ ! $body =~ $re_fd ]]; then issues["Unresolved successful open: $line"]=1; bad=1; continue; fi
            path=${BASH_REMATCH[1]}; path=${path% (deleted)}
            if [[ $path != /* || $path == *'\'* ]]; then issues["Unresolved open path: $line"]=1; bad=1; continue; fi
            case "${path##*/}" in *gbs.conf*|*gitconfig*|*rpmmacros*)
                a[$path]=1; within_ws "$path" || { issues["External config: $path"]=1; bad=1; } ;;
            esac
            case "$path" in
                "$WS"|"$WS/"*|/usr|/usr/*|/lib|/lib/*|/lib32|/lib32/*|/lib64|/lib64/*|/libx32|/libx32/*|/proc|/proc/*|/sys|/sys/*|/dev|/dev/*) ;;
                *) b[$path]=1; runtime_path "$path" || { issues["Unapproved external open: $path"]=1; bad=1; } ;;
            esac
            ((n+=1))
        elif [[ $body == mkdir\(* || $body == mkdirat\(* ]]; then
            [[ $body =~ $re_ok ]] || continue
            path=; parent=
            if [[ $body =~ $re_mkdir ]]; then
                path=${BASH_REMATCH[1]}; parent=${cwd[$pid]:-UNKNOWN}
            elif [[ $body =~ $re_mkdirat ]]; then
                parent=${BASH_REMATCH[1]}; path=${BASH_REMATCH[2]}
                if [[ $parent =~ $re_angle ]]; then parent=${BASH_REMATCH[1]}
                elif [[ $parent == AT_FDCWD ]]; then parent=${cwd[$pid]:-UNKNOWN}
                else parent=UNKNOWN; fi
            fi
            [[ $path == /* ]] || path=$parent/$path
            if [[ $path != /* || $path == *'\'* ]]; then issues["Unresolved mkdir: $line"]=1; bad=1; continue; fi
            path=$(/usr/bin/realpath -m -- "$path") || { bad=1; continue; }
            c[$path]=1; within_ws "$path" || { issues["External mkdir: $path"]=1; bad=1; }
        fi
    done < "$trace"
    (( ${#pending[@]} == 0 )) || { issues['Unfinished syscalls at trace EOF']=1; bad=1; }
    (( n > 0 && ${#a[@]} > 0 && ${#c[@]} > 0 )) || { issues['Missing open/config/mkdir coverage']=1; bad=1; }
    {
        printf 'Export audit %s; successful opens only; successful mkdir only.\n' "$(stamp)"
        printf '\na. Configuration paths:\n'; for path in "${!a[@]}"; do printf '%s\n' "$path"; done | /usr/bin/sort
        printf '\nb. Other external opened paths (explicit runtime allowlist):\n'; for path in "${!b[@]}"; do printf '%s\n' "$path"; done | /usr/bin/sort
        printf '\nc. Created directories:\n'; for path in "${!c[@]}"; do printf '%s\n' "$path"; done | /usr/bin/sort
        printf '\nIssues:\n'; for path in "${!issues[@]}"; do printf '%s\n' "$path"; done | /usr/bin/sort
        printf 'AUDIT-EXIT %s\n' "$bad"
    } > "$summary"
    (( bad == 0 ))
}

scan_external() {
    local phase=$1 rc path base_name
    /usr/bin/find /var/tmp /tmp /home/linhao -maxdepth 3 -user "$(/usr/bin/id -un)" \
        -newer "$WORK/build_marker_$phase" -not -path "$WS/*" \
        > "$WORK/${phase}_r2.external_paths.txt" 2>/dev/null
    rc=$?
    {
        printf 'FIND-END %s exit=%s (permission errors suppressed by requested command)\n' "$(stamp)" "$rc"
        printf 'Names and time window alone cannot separate concurrent builds. No file was removed.\n'
        while IFS= read -r path; do
            base_name=${path##*/}
            case "$path" in
                *gbs*|*.gbs_export_*|*depanneur*|*GBS-ROOT*) printf '疑似构建相关，无法归属\t%s\n' "$path" ;;
                *) printf '无法归属\t%s\n' "$path" ;;
            esac
        done < "$WORK/${phase}_r2.external_paths.txt"
        printf '\nDirect observations for this process group (if any):\n'
        /usr/bin/cat "$WORK/${phase}_r2.observed_outside.txt"
    } > "$WORK/${phase}_r2.external_review.txt"
}

start_phase() {
    current=$1; result[$current]=RUNNING; started[$current]=$(stamp)
    final_label="FAILED at $current"; write_status
}
pass_phase() {
    result[$current]=OK; code[$current]=0; ended[$current]=$(stamp); write_status
}
run_build() {
    local phase=$1 conf=$2 rc clean_status log="$WORK/build_${1}_r2.log"
    start_phase "$phase"
    [[ $(/usr/bin/git -C "$KERNEL" rev-parse HEAD) == "$EXPECTED" ]] || fail 92 'base changed before build'
    [[ $(/usr/bin/git -C "$KERNEL" symbolic-ref --short HEAD) == lko/base ]] || fail 92 'kernel branch changed before build'
    clean_status=$(/usr/bin/git -C "$KERNEL" status --porcelain) || fail 92 'cannot inspect kernel status'
    [[ -z $clean_status ]] || fail 92 'kernel worktree no longer clean'
    /usr/bin/touch "$WORK/build_marker_$phase" || fail 93 'cannot create build marker'
    printf 'BUILD-START %s %s\nBASE=%s\n' "$phase" "$(stamp)" "$EXPECTED" > "$log"
    run_managed "$phase" "$log" /usr/bin/env HOME="$GBS_HOME" GIT_CONFIG_NOSYSTEM=1 \
        /usr/bin/time -v /usr/bin/gbs -c "$conf" build -A armv7l --threads 1 --define '_smp_mflags -j10'
    rc=$?
    scan_external "$phase"
    # Report log is sealed; raw output remains available if descendants persist.
    if [[ -z $active_pid ]]; then
        printf 'BUILD-END %s %s exit=%s\n' "$phase" "$(stamp)" "$command_rc" >> "$log"
    else
        printf 'INCOMPLETE: group still live; following exit is supervisor failure, not a confirmed command exit; raw log may continue.\n' >> "$log"
        printf 'BUILD-END %s %s exit=%s\n' "$phase" "$(stamp)" "$rc" >> "$log"
    fi
    (( rc == 0 )) || fail "$rc" "command_exit=$command_rc; inspect $log and process/external logs"
    (( interrupted == 0 )) || fail 130 'interrupted after command completion'
    pass_phase
}

worker() {
    status_file="$WORK/run_baseline_build.status"
    result[preflight]=OK; code[preflight]=0
    started[preflight]=$1; ended[preflight]=$2
    trap finish EXIT
    trap 'on_interrupt worker' INT TERM HUP
    cd "$KERNEL" || fail 94 'cannot enter kernel directory'
    start_phase export
    run_managed export "$WORK/export_check.log" /usr/bin/env HOME="$GBS_HOME" GIT_CONFIG_NOSYSTEM=1 \
        /usr/bin/strace -f -yy -s 65535 \
        -e trace=openat,open,mkdir,mkdirat,chdir,fchdir,clone,clone3,fork,vfork \
        -o "$WORK/export_check.strace" /usr/bin/gbs export . -o "$WORK/export_check" \
        --outdir-directly --spec linux-rpi.spec --commit=HEAD
    local rc=$? audit_rc=0
    trace_audit || audit_rc=91
    (( rc == 0 )) || fail "$rc" 'export command/group/outside-output failure'
    (( audit_rc == 0 )) || fail "$audit_rc" 'export path audit failed; later stages skipped'
    # Only the exact export output directory created by this run is removed.
    [[ ! -L $WORK/export_check && $(/usr/bin/realpath -m "$WORK/export_check") == "$WORK/export_check" ]] || fail 95 'unsafe export cleanup path'
    /usr/bin/rm -rf -- "$WORK/export_check" || fail 95 'export cleanup failed'
    pass_phase
    (( interrupted == 0 )) || fail 130 'interrupted; no next stage'
    run_build gcc "$WS/config/gbs_gcc.conf"
    (( interrupted == 0 )) || fail 130 'interrupted; no next stage'
    run_build llvm "$WS/config/gbs_llvm.conf"
    final_label=OK
    exit 0
}

# Only this launch path can inherit the exclusive lock on descriptor 9.
if [[ ${1:-} == --worker ]]; then
    [[ ${2:-} == "$EXPECTED" && -e /proc/$$/fd/9 ]] || exit 96
    worker "${3:--}" "${4:--}"
fi

# Foreground preflight. Failed duplicate launches get their own status file and
# must never overwrite the status/logs belonging to a running or completed run.
[[ -d $WORK && -w $WORK && $(/usr/bin/realpath -e "$WORK") == "$WORK" ]] || { printf 'FAILED: workspace temp unavailable or redirected\nALL-END %s FAILED at preflight\n' "$(stamp)" >&2; exit 1; }
[[ ! -e $status_file && ! -L $status_file ]] || { printf 'FAILED: preflight status already exists\nALL-END %s FAILED at preflight\n' "$(stamp)" >&2; exit 1; }
trap finish EXIT
trap 'on_interrupt foreground' INT TERM HUP
result[preflight]=RUNNING; started[preflight]=$(stamp); write_status
[[ $# == 0 ]] || fail 2 'no user arguments accepted'
[[ $(pwd -P) == "$KERNEL" ]] || fail 2 "run from $KERNEL"
for tool in bash gbs strace sudo git find ps date awk readlink realpath nproc flock sort cmp touch rm mv sleep env time cat id tee; do
    [[ -x /usr/bin/$tool ]] || fail 2 "missing installed tool /usr/bin/$tool"
done
[[ $(/usr/bin/realpath -e "$WORK") == "$WORK" && $(/usr/bin/realpath -e "$GBS_HOME") == "$GBS_HOME" ]] || fail 2 'workspace temp/user-directory is missing or redirects elsewhere'
[[ ! -L $WORK/run_baseline_build.lock ]] || fail 2 'lock file must not be a symlink'
exec 9> "$WORK/run_baseline_build.lock" || fail 2 'cannot open lock'
/usr/bin/flock -n 9 || fail 2 'another baseline launcher still holds the lock; do not touch its processes'
for file in run_baseline_build.status run_baseline_build.log export_check export_check.log export_check.log.raw export_check.strace export_check_home.txt build_gcc_r2.log build_gcc_r2.log.raw build_llvm_r2.log build_llvm_r2.log.raw; do
    [[ ! -e $WORK/$file && ! -L $WORK/$file ]] || fail 2 "preserving existing $WORK/$file; no automatic overwrite/retry"
done
previous_status=$status_file
status_file="$WORK/run_baseline_build.status"
/usr/bin/mv -- "$previous_status" "$status_file" || fail 2 'cannot promote preflight status'
write_status
[[ $(/usr/bin/git -C "$KERNEL" symbolic-ref --short HEAD) == lko/base ]] || fail 2 'kernel branch is not lko/base'
[[ $(/usr/bin/git -C "$KERNEL" rev-parse HEAD) == "$EXPECTED" ]] || fail 2 'unexpected kernel HEAD'
[[ $(/usr/bin/git -C "$KERNEL" rev-parse tizen) == "$TIZEN" ]] || fail 2 'tizen SHA changed'
clean_status=$(/usr/bin/git -C "$KERNEL" status --porcelain) || fail 2 'cannot inspect kernel status'
[[ -z $clean_status ]] || fail 2 'kernel worktree is not clean'
[[ -f $GBS_HOME/.gbs.conf && ! -L $GBS_HOME/.gbs.conf ]] || fail 2 'workspace user config must be a regular file'
/usr/bin/cmp -s "$GBS_HOME/.gbs.conf" <(printf '[general]\ntmpdir = /home/linhao/Toolchain/development/linux_kernel_optimization/temp\n') || fail 2 'workspace user config is not the exact two-line configuration'
[[ ! -e /etc/gbs.conf && ! -L /etc/gbs.conf ]] || fail 2 '/etc/gbs.conf exists'
(( $(/usr/bin/nproc) / 2 >= 10 )) || fail 2 'requested -j10 exceeds half of nproc'
for var in GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_CONFIG GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS XDG_CONFIG_HOME XDG_CACHE_HOME TIZEN_BUILD_ROOT VIRTUAL_ENV; do
    [[ -z ${!var:-} ]] || fail 2 "environment $var is set; refusing an unreviewed override"
done
for file in "$WS/config/gbs_gcc.conf" "$WS/config/gbs_llvm.conf"; do
    [[ -f $file && ! -L $file ]] || fail 2 "missing/nonregular build config: $file"
done
printf 'Existing GBS/depanneur/build processes (display only):\n'
/usr/bin/ps -eo pid=,ppid=,pgid=,user=,stat=,args= |
    /usr/bin/awk '$0 ~ /(^|[ /])(gbs|depanneur)([ :/]|$)|\/usr\/bin\/build([ ]|$)/ {print}' |
    /usr/bin/tee "$WORK/run_baseline_build.existing_processes.txt"
# Ordinary sudo in depanneur may need authentication. One foreground validation
# covers that possibility; a valid cache/NOPASSWD requires no password prompt.
# Root skips this validation. No sudo probe, keepalive or cleanup in this script.
if (( EUID != 0 )); then
    printf 'Foreground sudo validation; enter a password only if sudo requests it.\n'
    /usr/bin/sudo -v || fail 3 'sudo validation failed; no background stage launched'
fi
(( interrupted == 0 )) || fail 130 'interrupted before handoff'
result[preflight]=OK; code[preflight]=0; ended[preflight]=$(stamp); write_status
set -m
/usr/bin/bash "$SCRIPT" --worker "$EXPECTED" "${started[preflight]}" "${ended[preflight]}" \
    > "$WORK/run_baseline_build.log" 2>&1 < /dev/null &
worker_pid=$!
# Exit trap is owned by the worker after successful launch.
handoff=1
disown "$worker_pid"
printf 'Background supervisor PID/PGID=%s. Keep this terminal session open for sudo timestamp compatibility.\n' "$worker_pid"
printf 'Progress commands:\n'
printf '/usr/bin/tail -F %s/run_baseline_build.log %s/export_check.log.raw %s/build_gcc_r2.log.raw %s/build_llvm_r2.log.raw\n' "$WORK" "$WORK" "$WORK" "$WORK"
printf '/usr/bin/cat %s/run_baseline_build.status\n' "$WORK"
