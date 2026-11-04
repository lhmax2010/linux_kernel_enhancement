#!/usr/bin/bash
# User-run only. Adapted from run_baseline_build.sh; never source this file.
# No artifact verification here. One foreground sudo -v; all other sudo is GBS-owned.
set -uo pipefail
readonly WS=/home/linhao/Toolchain/development/linux_kernel_optimization
readonly WORK=/home/linhao/Toolchain/development/linux_kernel_optimization/temp/task12
readonly ROOT=/home/linhao/Toolchain/development/linux_kernel_optimization/temp/task12/GBS-ROOT-LKO-VBASE01
readonly GBS_HOME=/home/linhao/Toolchain/development/linux_kernel_optimization/temp/gbs-home
readonly CONF=/home/linhao/Toolchain/development/linux_kernel_optimization/config/gbs_llvm.conf
readonly CONF_SHA=d47536dd30900412e7bbd2d7057e9dd486f94ad2b2b6d8404a510a23be0bdc48
readonly SCRIPT=/home/linhao/Toolchain/development/linux_kernel_optimization/scripts/run_task12_build.sh
readonly LOCK="$WORK/run_task12_build.lock"
readonly -a phases=(kernel modsrc modules)
declare -Ar source_dir=(
    [kernel]="$WS/vendor_local/linux-rpi-vbase"
    [modsrc]="$WS/ext/linux-tizen-modules-source"
    [modules]="$WS/ext/linux-tizen-modules")
declare -Ar expected=(
    [kernel]=7a1eddc637fc8ff5e55963b00fec49b5f3706b43
    [modsrc]=25797e8af7ed95a5783bbe84c11959560aaf7e92
    [modules]=8e032ef18ae9d9633c1508b48d4778216ab960a0)
declare -Ar expected_branch=([kernel]=lko/vbase01-local [modsrc]=lko/base01 [modules]=lko/vbase01)
export TMPDIR="$WS/temp" PYTHONDONTWRITEBYTECODE=1
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
# Do not set umask. Keep the caller's terminal/session for GBS sudo timestamps.
stamp() { TZ=Asia/Shanghai /usr/bin/date --iso-8601=seconds; }
declare -A result=([preflight]=PENDING [kernel]=PENDING [modsrc]=PENDING [modules]=PENDING)
declare -A code=([preflight]=- [kernel]=- [modsrc]=- [modules]=-)
declare -A started=([preflight]=- [kernel]=- [modsrc]=- [modules]=-)
declare -A ended=([preflight]=- [kernel]=- [modsrc]=- [modules]=-)
declare -A sealed=([kernel]=0 [modsrc]=0 [modules]=0)
status_file="$WORK/preflight.$$.status"
current=preflight
handoff=0
interrupted=0
owns_run=0
active_pid=
command_rc=UNKNOWN
known_outside=0
credential_seen=0

write_status() {
    local phase status_tmp="${status_file}.new.$$"
    {
        printf 'TASK12 UPDATED %s\n' "$(stamp)"
        for phase in preflight "${phases[@]}"; do
            printf 'STAGE %s result=%s exit=%s start=%s end=%s\n' \
                "$phase" "${result[$phase]}" "${code[$phase]}" "${started[$phase]}" "${ended[$phase]}"
        done
        [[ -z $active_pid ]] || printf 'ACTIVE-OR-RESIDUAL PGID=%s; raw log may still grow; no signal sent\n' "$active_pid"
        if [[ ${1:-} == final ]]; then
            printf 'ALL-END %s kernel=%s modsrc=%s modules=%s\n' \
                "$(stamp)" "${result[kernel]}" "${result[modsrc]}" "${result[modules]}"
        fi
    } > "$status_tmp" && /usr/bin/mv -- "$status_tmp" "$status_file"
}
# During a build log and raw are hardlinks: output is visible immediately.
# Seal by replacing only log's directory entry; lingering writers keep raw open.
seal_log() {
    local phase=$1 exit_code=$2 note=$3
    local log="$WORK/build_${1}.log" raw="$WORK/build_${1}.log.raw" tmp="$WORK/build_${1}.log.seal.$$"
    (( sealed[$phase] == 0 )) || return 0
    if [[ -f $raw ]]; then
        /usr/bin/cp -- "$raw" "$tmp" || return 1
    else
        printf 'BUILD-NOT-STARTED %s\n' "$phase" > "$tmp" || return 1
    fi
    printf '\n%s\nBUILD-END %s %s exit=%s\n' "$note" "$phase" "$(stamp)" "$exit_code" >> "$tmp" || return 1
    /usr/bin/mv -- "$tmp" "$log" || return 1
    sealed[$phase]=1
}
finish() {
    local rc=$? phase
    trap - EXIT
    (( handoff == 0 )) || return
    if [[ ${result[$current]} == RUNNING || ${result[$current]} == PENDING ]]; then
        result[$current]=FAILED
        (( rc != 0 )) || rc=125
        code[$current]=$rc; ended[$current]=$(stamp)
    fi
    for phase in "${phases[@]}"; do
        if [[ ${result[$phase]} == PENDING ]]; then
            result[$phase]=SKIPPED; code[$phase]=125; ended[$phase]=$(stamp)
        fi
        if (( owns_run && sealed[$phase] == 0 )); then
            seal_log "$phase" "${code[$phase]}" \
                "RESULT=${result[$phase]}; 125 for SKIPPED means not run. Abnormal exit may leave raw writers; inspect process log/status." || \
                printf 'ERROR: cannot seal %s log\n' "$phase" >&2
        fi
    done
    write_status final || printf 'ERROR writing status; ALL-END %s kernel=%s modsrc=%s modules=%s\n' \
        "$(stamp)" "${result[kernel]}" "${result[modsrc]}" "${result[modules]}" >&2
}
fail() {
    local rc=$1; shift
    printf 'FAILED %s: %s\n' "$current" "$*" >&2
    result[$current]=FAILED; code[$current]=$rc; ended[$current]=$(stamp)
    exit "$rc"
}
on_interrupt() {
    interrupted=1
    printf 'INTERRUPTED %s phase=%s; no signals forwarded; active build may continue naturally\n' "$(stamp)" "$current" >&2
    [[ $1 != foreground ]] || exit 130
    write_status || fail 93 'cannot update status'
}
within_ws() { [[ $1 == "$WS" || $1 == "$WS/"* ]]; }
group_rows() {
    /usr/bin/ps -eo pid=,ppid=,pgid=,user=,stat=,args= |
        /usr/bin/awk -v group="$1" '$3 == group && $5 !~ /^Z/ {print}'
}
group_snapshot() {
    printf 'PROCESS-GROUP %s PGID=%s\n' "$(stamp)" "$1"
    group_rows "$1"
}
observe_output_paths() {
    local group=$1 out=$2 rows pid ppid pgid owner state args fd target
    rows=$(group_rows "$group") || return 1
    [[ -n $rows ]] || return 0
    while read -r pid ppid pgid owner state args; do
        [[ -n $pid ]] || continue
        for fd in 1 2; do
            target=$(/usr/bin/readlink -- "/proc/$pid/fd/$fd" 2>/dev/null) || continue
            [[ -n $target ]] || continue
            target=${target% (deleted)}
            case "$target" in /dev/*|/proc/*|/sys/*) continue ;; /*) ;; *) continue ;; esac
            if ! within_ws "$target"; then
                printf '%s PID=%s PGID=%s fd=%s path=%s\n' "$(stamp)" "$pid" "$group" "$fd" "$target" >> "$out"
                known_outside=1
            fi
        done
    done <<< "$rows"
}
wait_residuals() {
    local group=$1 log=$2 deadline=$((SECONDS + 300)) rows
    rows=$(group_rows "$group") || return 1
    if [[ -n $rows ]]; then
        printf 'Residuals/stopped job: wait five minutes; no signals or sudo cleanup.\n' >> "$log"
        while [[ -n $rows ]] && (( SECONDS < deadline )); do
            /usr/bin/sleep 5
            rows=$(group_rows "$group") || return 1
        done
    fi
    group_snapshot "$group" >> "$log" || return 1
    [[ -z $rows ]]
}
credential_prompt() {
    LC_ALL=C /usr/bin/grep -Eiq \
        '(\[sudo\].*password|password for |a password is required|a terminal is required|no tty present|incorrect password|failed to request passwd|authentication failure|sorry, try again|username for |enter passphrase)' "$1"
}
scan_external() {
    local phase=$1 rc path user
    user=$(/usr/bin/id -un) || return 1
    [[ -n $user ]] || return 1
    /usr/bin/find /var/tmp /tmp /home/linhao -maxdepth 3 -user "$user" \
        -newer "$WORK/build_marker_$phase" -not -path "$WS/*" \
        > "$WORK/${phase}.external_paths.txt" 2>/dev/null
    rc=$?
    {
        printf 'FIND-END %s exit=%s; permission errors suppressed; root/deeper/deleted files not covered\n' "$(stamp)" "$rc"
        printf 'Names/time alone cannot attribute concurrent writes; no files removed.\n'
        while IFS= read -r path; do
            [[ -n $path ]] || continue
            case "$path" in
                *gbs*|*.gbs_export_*|*depanneur*|*GBS-ROOT*) printf '疑似构建相关，无法归属\t%s\n' "$path" ;;
                *) printf '无法归属\t%s\n' "$path" ;;
            esac
        done < "$WORK/${phase}.external_paths.txt"
        printf '\nDirect observations of this process group:\n'
        /usr/bin/cat "$WORK/${phase}.observed_outside.txt"
    } > "$WORK/${phase}.external_review.txt"
}
check_source() {
    local phase=$1 head branch dirty
    head=$(/usr/bin/git -C "${source_dir[$phase]}" rev-parse HEAD) || fail 92 "cannot read $phase HEAD"
    [[ -n $head && $head == "${expected[$phase]}" ]] || fail 92 "$phase HEAD mismatch: $head"
    branch=$(/usr/bin/git -C "${source_dir[$phase]}" symbolic-ref --short HEAD) || fail 92 "$phase is detached"
    [[ -n $branch && $branch == "${expected_branch[$phase]}" ]] || fail 92 "$phase branch mismatch"
    dirty=$(/usr/bin/git -C "${source_dir[$phase]}" status --porcelain) || fail 92 "cannot inspect $phase worktree"
    # Empty output is the required successful result for git status.
    [[ -z $dirty ]] || fail 92 "$phase worktree not clean"
}
check_config() {
    local digest
    [[ -f $CONF && ! -L $CONF ]] || fail 92 'missing/nonregular LLVM config'
    digest=$(/usr/bin/sha256sum -- "$CONF") || fail 92 'cannot hash config'
    [[ -n $digest && ${digest%% *} == "$CONF_SHA" ]] || fail 92 'LLVM config SHA mismatch'
}
run_managed() {
    local phase=$1 log=$2; shift 2
    local pid state actual_group rc=125 monitor_rc=0 last_scan=$SECONDS scan_rc
    local group_log="$WORK/${phase}.processes.log" raw_log="${log}.raw"
    known_outside=0; credential_seen=0; command_rc=UNKNOWN
    printf 'BEFORE %s\n' "$(stamp)" > "$group_log"
    /usr/bin/ps -eo pid=,ppid=,pgid=,user=,stat=,args= >> "$group_log" || return 125
    : > "$WORK/${phase}.observed_outside.txt"
    printf 'BUILD-START %s %s\nSOURCE=%s\nCOMMIT=%s\nCOMMAND=' "$phase" "$(stamp)" "${source_dir[$phase]}" "${expected[$phase]}" > "$raw_log"
    printf '%q ' "$@" >> "$raw_log"; printf '\n' >> "$raw_log"
    /usr/bin/ln -- "$raw_log" "$log" || return 125
    set -m
    "$@" >> "$raw_log" 2>&1 < /dev/null &
    pid=$!; active_pid=$pid
    printf '%s\n' "$pid" > "$WORK/task12_${phase}.pgid"
    actual_group=$(/usr/bin/ps -o pgid= -p "$pid" 2>/dev/null) || actual_group=
    actual_group=${actual_group//[[:space:]]/}
    if [[ -n $actual_group && $actual_group != "$pid" ]]; then
        printf 'Unexpected PGID=%s; no signals; do not start later stages.\n' "$actual_group" >> "$raw_log"
        monitor_rc=125
    fi
    group_snapshot "$pid" >> "$group_log" || monitor_rc=125
    write_status || fail 93 'cannot update status'
    while :; do
        if credential_prompt "$raw_log"; then
            credential_seen=1; monitor_rc=126
            printf 'CREDENTIAL-STOP %s: no input/retry; five-minute residual observation only.\n' "$(stamp)" >> "$raw_log"
            break
        else
            scan_rc=$?
            (( scan_rc == 1 )) || { monitor_rc=125; break; }
        fi
        state=$(/usr/bin/ps -o stat= -p "$pid" 2>/dev/null) || state=
        state=${state//[[:space:]]/}
        [[ -n $state && $state != Z* ]] || break
        if [[ $state == *T* || $state == *t* ]]; then
            printf 'STOPPED-JOB %s: possible terminal authentication; no resume/signal.\n' "$(stamp)" >> "$raw_log"
            monitor_rc=125; break
        fi
        if (( SECONDS - last_scan >= 15 )); then
            observe_output_paths "$pid" "$WORK/${phase}.observed_outside.txt" || monitor_rc=125
            last_scan=$SECONDS
        fi
        /usr/bin/sleep 5
    done
    # Do not call blocking wait on a running/stopped credential request.
    # Only reap after this group's processes have gone; otherwise seal as incomplete.
    if wait_residuals "$pid" "$group_log"; then
        wait "$pid"; rc=$?
        command_rc=$rc; active_pid=
    else
        printf 'INCOMPLETE: group still live after five minutes (or inspection failed); raw may grow.\n' >> "$raw_log"
        (( monitor_rc != 0 )) || monitor_rc=125
    fi
    # A last prompt could have been emitted after the leader's last status check.
    if credential_prompt "$raw_log"; then
        credential_seen=1; monitor_rc=126
    else
        scan_rc=$?
        (( scan_rc == 1 )) || monitor_rc=125
    fi
    observe_output_paths "$pid" "$WORK/${phase}.observed_outside.txt" || monitor_rc=125
    printf 'COMMAND-EXIT %s time=%s exit=%s credential_seen=%s\n' "$phase" "$(stamp)" "$command_rc" "$credential_seen" >> "$raw_log"
    (( monitor_rc == 0 )) || return "$monitor_rc"
    (( interrupted == 0 )) || return 130
    (( rc == 0 )) || return "$rc"
    (( known_outside == 0 )) || return 90
    return 0
}
run_build() {
    local phase=$1 rc
    current=$phase; result[$phase]=RUNNING; started[$phase]=$(stamp); write_status || fail 93 'cannot start stage status'
    check_source "$phase"; check_config
    (( interrupted == 0 )) || fail 130 'interrupted; no next build'
    cd "${source_dir[$phase]}" || fail 94 "cannot enter $phase source"
    /usr/bin/touch "$WORK/build_marker_$phase" || fail 93 'cannot create marker'
    run_managed "$phase" "$WORK/build_${phase}.log" \
        /usr/bin/env HOME="$GBS_HOME" GIT_CONFIG_NOSYSTEM=1 GBP_CONF_FILES="$GBS_HOME/.gbp.conf" \
        /usr/bin/time -v /usr/bin/gbs -c "$CONF" build -P tizen_unified_standard -A armv7l -B "$ROOT" \
        --threads 1 --define '_smp_mflags -j10' --commit "${expected[$phase]}"
    rc=$?
    scan_external "$phase" || { (( rc != 0 )) || rc=125; }
    (( interrupted == 0 || rc != 0 )) || rc=130
    ended[$phase]=$(stamp); code[$phase]=$rc
    if (( rc == 0 )); then result[$phase]=OK; else result[$phase]=FAILED; fi
    seal_log "$phase" "$rc" "RESULT=${result[$phase]}; GBS/time exit=$command_rc; active_or_residual=${active_pid:-none}" || fail 125 'cannot seal build log'
    write_status || fail 93 'cannot update status'
    (( rc == 0 )) || fail "$rc" "inspect build_${phase}.log, raw and process/external logs; later stages skipped"
}
worker() {
    status_file="$WORK/status.txt"; owns_run=1
    result[preflight]=OK; code[preflight]=0; started[preflight]=$1; ended[preflight]=$2
    trap finish EXIT
    trap 'on_interrupt worker' INT TERM HUP
    run_build kernel
    run_build modsrc
    run_build modules
    exit 0
}
# Internal handoff requires the inherited descriptor for the launcher lock.
if [[ ${1:-} == --worker ]]; then
    lock_target=$(/usr/bin/readlink "/proc/$$/fd/9" 2>/dev/null) || lock_target=
    [[ $# == 4 && ${2:-} == "${expected[kernel]}" && -n $lock_target && $lock_target == "$LOCK" ]] || exit 96
    worker "$3" "$4"
fi

# Preflight never authenticates. Duplicate/unsafe attempts get a separate status;
# they must not overwrite a running/completed invocation's status.txt or logs.
resolved_work=$(/usr/bin/realpath -e -- "$WORK" 2>/dev/null) || resolved_work=
if [[ -z $resolved_work || $resolved_work != "$WORK" || ! -d $WORK || ! -w $WORK ]]; then
    printf 'FAILED: task12 directory missing/unwritable/redirected\nALL-END %s kernel=SKIPPED modsrc=SKIPPED modules=SKIPPED\n' "$(stamp)" >&2
    exit 1
fi
[[ ! -e $status_file && ! -L $status_file ]] || { printf 'FAILED: preflight status exists\nALL-END %s kernel=SKIPPED modsrc=SKIPPED modules=SKIPPED\n' "$(stamp)" >&2; exit 1; }
trap finish EXIT
trap 'on_interrupt foreground' INT TERM HUP
result[preflight]=RUNNING; started[preflight]=$(stamp); write_status || fail 93 'cannot create preflight status'
[[ $# == 0 ]] || fail 2 'no user arguments accepted'
for tool in bash gbs sudo git find ps date awk readlink realpath nproc flock sha256sum cmp touch mv cp ln sleep env time cat id tee grep; do
    [[ -x /usr/bin/$tool ]] || fail 2 "missing installed tool /usr/bin/$tool"
done
[[ ! -L $LOCK && ( ! -e $LOCK || -f $LOCK ) ]] || fail 2 'lock must be a regular file, never a symlink/device'
exec 9>> "$LOCK" || fail 2 'cannot open task12 lock'
/usr/bin/flock -n 9 || fail 2 'task12 lock still held; no authentication or process changes'
for phase in supervisor "${phases[@]}"; do
    pgfile="$WORK/task12_${phase}.pgid"
    [[ ! -e $pgfile && ! -L $pgfile ]] && continue
    [[ -f $pgfile && ! -L $pgfile ]] || fail 2 "invalid old PGID file: $pgfile"
    old_group=$(< "$pgfile")
    [[ -n $old_group && $old_group =~ ^[1-9][0-9]*$ ]] || fail 2 "empty/invalid PGID: $pgfile"
    old_rows=$(group_rows "$old_group") || fail 2 'cannot inspect old process group'
    [[ -z $old_rows ]] || fail 2 "old task12 PGID $old_group still live; preserve all processes"
done
for file in status.txt run_task12_build.log build_kernel.log build_modsrc.log build_modules.log build_kernel.log.raw build_modsrc.log.raw build_modules.log.raw; do
    [[ ! -e $WORK/$file && ! -L $WORK/$file ]] || fail 2 "preserving existing $file; no automatic rerun/overwrite"
done
for phase in "${phases[@]}"; do
    for suffix in processes.log observed_outside.txt external_paths.txt external_review.txt; do
        [[ ! -e $WORK/$phase.$suffix && ! -L $WORK/$phase.$suffix ]] || fail 2 "preserving prior $phase.$suffix"
    done
    [[ ! -e $WORK/build_marker_$phase && ! -L $WORK/build_marker_$phase ]] || fail 2 "preserving prior marker $phase"
done
[[ ! -e $WORK/existing_processes.txt && ! -L $WORK/existing_processes.txt ]] || fail 2 'preserving existing process snapshot'
previous_status=$status_file
status_file="$WORK/status.txt"
/usr/bin/mv -- "$previous_status" "$status_file" || fail 2 'cannot promote preflight status'
owns_run=1
resolved_root=$(/usr/bin/realpath -e -- "$ROOT" 2>/dev/null) || resolved_root=
[[ -n $resolved_root && $resolved_root == "$ROOT" && $ROOT == "$WORK/"* && -d $ROOT && -w $ROOT && ! -L $ROOT ]] || fail 2 'independent task12 build root missing/unwritable/redirected'
# First launch must use the fresh empty directory created during task12 preparation.
root_entry=$(/usr/bin/find "$ROOT" -mindepth 1 -maxdepth 1 -print -quit) || fail 2 'cannot inspect root contents'
[[ -z $root_entry ]] || fail 2 'task12 root is not empty; refusing reuse or automatic cleanup'
for phase in "${phases[@]}"; do check_source "$phase"; done
check_config
resolved_home=$(/usr/bin/realpath -e -- "$GBS_HOME" 2>/dev/null) || resolved_home=
[[ -n $resolved_home && $resolved_home == "$GBS_HOME" ]] || fail 2 'isolated HOME missing or redirected'
[[ -f $GBS_HOME/.gbs.conf && ! -L $GBS_HOME/.gbs.conf ]] || fail 2 'invalid isolated gbs config'
/usr/bin/cmp -s "$GBS_HOME/.gbs.conf" <(printf '[general]\ntmpdir = /home/linhao/Toolchain/development/linux_kernel_optimization/temp\n') || fail 2 'isolated gbs config differs from approved two lines'
[[ -f $GBS_HOME/.gbp.conf && ! -L $GBS_HOME/.gbp.conf && -r $GBS_HOME/.gbp.conf && -s $GBS_HOME/.gbp.conf ]] || fail 2 'invalid isolated GBP config'
while IFS= read -r config_line || [[ -n $config_line ]]; do
    [[ $config_line =~ ^[[:space:]]*# ]] || fail 2 'GBP config must contain comments only'
done < "$GBS_HOME/.gbp.conf"
[[ ! -e /etc/gbs.conf && ! -L /etc/gbs.conf ]] || fail 2 '/etc/gbs.conf exists'
processors=$(/usr/bin/nproc) || fail 2 'cannot read nproc'
[[ -n $processors && $processors =~ ^[1-9][0-9]*$ ]] || fail 2 'empty/invalid nproc'
(( processors / 2 >= 10 )) || fail 2 '-j10 exceeds half of nproc'
for var in GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_CONFIG GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS XDG_CONFIG_HOME XDG_CACHE_HOME TIZEN_BUILD_ROOT VIRTUAL_ENV; do
    [[ -z ${!var:-} ]] || fail 2 "unreviewed environment override: $var"
done
processes=$(/usr/bin/ps -eo pid=,ppid=,pgid=,user=,stat=,args=) || fail 2 'cannot snapshot existing processes'
[[ -n $processes ]] || fail 2 'empty process snapshot'
if /usr/bin/grep -Fq -- "$ROOT" <<< "$processes"; then fail 2 'a process already references this build root; no process modified'; fi
printf 'Existing GBS/build processes (display only):\n'
/usr/bin/awk '$0 ~ /(^|[ /])(gbs|depanneur)([ :/]|$)|\/usr\/bin\/build([ ]|$)/ {print}' <<< "$processes" |
    /usr/bin/tee "$WORK/existing_processes.txt"
# Sole direct sudo invocation; user authenticates in the foreground terminal.
if (( EUID != 0 )); then
    printf 'Foreground sudo validation; authenticate only in your own terminal.\n'
    /usr/bin/sudo -v || fail 3 'sudo validation failed; no background build launched'
fi
(( interrupted == 0 )) || fail 130 'interrupted before handoff'
result[preflight]=OK; code[preflight]=0; ended[preflight]=$(stamp); write_status || fail 93 'cannot record preflight completion'
set -m
/usr/bin/bash "$SCRIPT" --worker "${expected[kernel]}" "${started[preflight]}" "${ended[preflight]}" \
    > "$WORK/run_task12_build.log" 2>&1 < /dev/null &
worker_pid=$!
printf '%s\n' "$worker_pid" > "$WORK/task12_supervisor.pgid"
handoff=1
disown "$worker_pid"
printf 'Background supervisor PID/PGID=%s. Keep this tmux/terminal session open for GBS sudo authentication.\n' "$worker_pid"
printf 'ALL-END records supervisor completion; inspect stage results and ACTIVE-OR-RESIDUAL before assuming success.\n'
# These are deliberately the last two foreground output lines.
printf '/usr/bin/tail -F %s/build_kernel.log %s/build_modsrc.log %s/build_modules.log %s/status.txt\n' "$WORK" "$WORK" "$WORK" "$WORK"
printf '/usr/bin/grep ALL-END %s/status.txt\n' "$WORK"
