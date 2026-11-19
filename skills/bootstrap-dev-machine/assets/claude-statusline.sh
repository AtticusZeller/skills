#!/usr/bin/env bash
# Claude Code statusline — Tokyo Night truecolor + Nerd Font, ideas borrowed from CCometixLine.
# Line 1: model · effort │ dir │ git │ context bar · room before auto-compact ..... date time
# Line 2: prompt cache ......................... 5h / 7d quota left + pace │ duration
# Narrow terminals (COLUMNS) drop detail level by level; see "Shrink levels" below.
# Set CCSL_GLYPHS=unicode if the terminal font has no Nerd Font glyphs.

export LC_ALL=C.UTF-8
input=$(cat)
now=$(date +%s)

# ── Extract every field with one jq call (unit-separator joined) ─────────────
IFS=$'\x1f' read -r cwd model effort used ctx_size in_tok cache_r cache_w dur_ms session_id \
    r5_used r5_reset r7_used r7_reset \
    pc_obs pc_warm pc_ttl pc_exp pc_hit pc_req pc_misses pc_cause pc_recache \
  < <(jq -r '
    def r: if . == null then null else round end;
    [
      (.workspace.current_dir // .cwd), .model.display_name, .effort.level,
      (.context_window.used_percentage | r), .context_window.context_window_size,
      .context_window.current_usage.input_tokens,
      .context_window.current_usage.cache_read_input_tokens,
      .context_window.current_usage.cache_creation_input_tokens,
      (.cost.total_duration_ms | r), .session_id,
      (.rate_limits.five_hour.used_percentage | r), (.rate_limits.five_hour.resets_at | r),
      (.rate_limits.seven_day.used_percentage | r), (.rate_limits.seven_day.resets_at | r),
      .prompt_cache.caching_observed, .prompt_cache.warm, .prompt_cache.ttl,
      (.prompt_cache.expires_at | r),
      (.prompt_cache.hit_ratio | if . == null then null else . * 100 | round end),
      .prompt_cache.requests, .prompt_cache.misses,
      (.prompt_cache.last_miss_cause
        | if type == "object" then .causes[0]? elif type == "string" then . else null end),
      .prompt_cache.recache_tokens_if_cold
    ] | map(if . == null then "" else tostring end) | join("\u001f")' <<<"$input")

# ── Palette: Tokyo Night ─────────────────────────────────────────────────────
fg() { printf -v "$1" '\e[38;2;%d;%d;%dm' "0x${2:1:2}" "0x${2:3:2}" "0x${2:5:2}"; }
bg() { printf -v "$1" '\e[48;2;%d;%d;%dm' "0x${2:1:2}" "0x${2:3:2}" "0x${2:5:2}"; }
fg OK '#9ece6a'; fg WARN '#e0af68'; fg CRIT '#f7768e'; fg MUTED '#565f89'; fg TEXT '#c0caf5'
fg IDENT '#7aa2f7'; fg WS '#9ece6a'; fg VCS '#7dcfff'; fg CTX '#bb9af7'
fg QUOTA '#ff9e64'; fg CACHE '#73daca'; fg SESS '#bb9af7'
fg TRACK '#3b4261'; bg TRACK_BG '#292e42'; bg PASSED_BG '#565f89'
R=$'\e[0m'; B=$'\e[1m'

# ── Icons ────────────────────────────────────────────────────────────────────
if [ "${CCSL_GLYPHS:-nerd}" = nerd ]; then
    I_MODEL=$''; I_EFF=$''; I_DIR=$'\U000f024b'; I_GIT=$'\U000f02a2'
    I_CTX=$''; I_CMP=$''; I_CACHE=$''; I_QUOTA=$'\U000f0520'
    I_DUR=$'\U000f19bb'
else
    I_MODEL='◆'; I_EFF='ϟ'; I_DIR='▣'; I_GIT='⎇'; I_CTX='◔'; I_CMP='⇲'
    I_CACHE='≈'; I_QUOTA='◷'; I_DUR='◷'
fi

# ── Helpers ──────────────────────────────────────────────────────────────────
fmt_tok() {
    local n=${1:-0}
    if   (( n >= 1000000 )); then printf '%d.%dM' $((n / 1000000)) $((n % 1000000 / 100000))
    elif (( n >= 1000 ));    then printf '%dk' $(( (n + 500) / 1000 ))
    else printf '%d' "$n"; fi
}
fmt_dur() {
    local s=${1:-0}
    if   (( s >= 86400 )); then printf '%dd%dh' $((s / 86400)) $((s % 86400 / 3600))
    elif (( s >= 3600 ));  then printf '%dh%02dm' $((s / 3600)) $((s % 3600 / 60))
    elif (( s >= 600 ));   then printf '%dm' $((s / 60))
    elif (( s >= 60 ));    then printf '%dm%02ds' $((s / 60)) $((s % 60))
    else printf '%ds' "$s"; fi
}
SEP=" ${TRACK}│${R} "
join_segs() {
    local out="" s
    for s in "$@"; do [ -n "$s" ] && out+="${out:+$SEP}$s"; done
    printf '%s' "$out"
}

# ── Git, cached 5s per session ───────────────────────────────────────────────
CACHE_DIR="/tmp/.claude-statusline-cache"
mkdir -p "$CACHE_DIR" 2>/dev/null
cf="${CACHE_DIR}/${session_id}.git"
cache_age=999
[ -f "$cf" ] && cache_age=$(( now - $(stat -c %Y "$cf" 2>/dev/null || echo 0) ))

if (( cache_age > 5 )); then
    gb="" gs=0 gm=0 gu=0 ga=0 gbh=0
    if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        gb=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
             || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
        read -r gs gm gu < <(git -C "$cwd" --no-optional-locks status --porcelain=v2 2>/dev/null | awk '
            /^[12] / { if (substr($2,1,1) != ".") s++; if (substr($2,2,1) != ".") m++ }
            /^u /    { m++ }
            /^\? /   { u++ }
            END      { print s+0, m+0, u+0 }')
        read -r gbh ga < <(git -C "$cwd" --no-optional-locks rev-list --left-right --count \
            '@{upstream}...HEAD' 2>/dev/null || echo "0 0")
    fi
    printf '%s\n' "$gb" "$gs" "$gm" "$gu" "$ga" "$gbh" > "${cf}.tmp" 2>/dev/null \
        && mv "${cf}.tmp" "$cf" 2>/dev/null
else
    { read -r gb; read -r gs; read -r gm; read -r gu; read -r ga; read -r gbh; } < "$cf"
fi


# ── Values that don't depend on the width level ──────────────────────────────
read -r c_date c_time < <(TZ='Asia/Shanghai' date '+%m-%d %H:%M')

# Auto-compact point follows Claude Code's rule (as in CCometixLine):
# window - 20k output reserve - 13k buffer, or CLAUDE_AUTOCOMPACT_PCT_OVERRIDE if lower.
if [ -n "$used" ]; then
    win=${ctx_size:-200000}
    tok=$(( ${in_tok:-0} + ${cache_r:-0} + ${cache_w:-0} ))
    usable=$(( win - 20000 ))
    cpt=$(( usable - 13000 ))
    if [ -n "$CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" ]; then
        p=$(( usable * ${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE%.*} / 100 ))
        (( p < cpt )) && cpt=$p
    fi
    room=$(( cpt - tok )); (( room < 0 )) && room=0
    if   (( tok > 0 && room < 20000 ));   then sc=$CRIT
    elif (( tok > 0 && room * 4 < cpt )); then sc=$WARN
    else sc=$OK; fi
fi

# ── Shrink levels: what each level keeps (0 = everything) ────────────────────
# Each line picks its own lowest level that fits, so a line with room keeps its
# detail; both are then padded to the wider one.
#  L  change from previous level
#  1  drop 7d reset countdown          7  bars 4 / 6
#  2  drop 5h reset countdown          8  drop date
#  3  "hit 96%" → "96%"; bars 6 / 8    9  drop directory
#  4  drop effort, miss cause text    10  drop quota bars; context bar 4
#  5  drop pace delta +N% / -N%       11  drop git counts
#  6  drop session duration           12  drop cache hit ratio and /ttl
set_level() {
    L=$1
    r7=$(( L < 1 )); r5=$(( L < 2 )); hitword=$(( L < 3 )); eff=$(( L < 4 )); cause=$(( L < 4 ))
    arrow=$(( L < 5 )); dur=$(( L < 6 )); hit=$(( L < 12 )); date_on=$(( L < 8 )); dir=$(( L < 9 ))
    gitcnt=$(( L < 11 ))
    if   (( L < 3 ));  then qcells=8; ccells=10
    elif (( L < 7 ));  then qcells=6; ccells=8
    elif (( L < 10 )); then qcells=4; ccells=6
    else                    qcells=0; ccells=4; fi
}

# ── Segment builders ─────────────────────────────────────────────────────────
seg_model() {
    [ -z "$model" ] && return
    local s="${IDENT}${I_MODEL} ${B}${model}${R}"
    (( eff )) && [ -n "$effort" ] && s+=" ${MUTED}${I_EFF}${effort}${R}"
    printf '%s' "$s"
}

seg_dir() { (( dir )) && printf '%s' "${WS}${I_DIR} ${cwd##*/}${R}"; }

seg_git() {
    [ -z "$gb" ] && return
    local s="${VCS}${I_GIT} ${gb}${R}"
    if (( gitcnt )); then
        (( ${ga:-0} > 0 ))  && s+=" ${VCS}⇡${ga}${R}"
        (( ${gbh:-0} > 0 )) && s+=" ${VCS}⇣${gbh}${R}"
        (( ${gs:-0} > 0 ))  && s+=" ${OK}+${gs}${R}"
        (( ${gm:-0} > 0 ))  && s+=" ${WARN}!${gm}${R}"
        (( ${gu:-0} > 0 ))  && s+=" ${MUTED}?${gu}${R}"
    fi
    printf '%s' "$s"
}

seg_ctx() {
    [ -z "$used" ] && return
    local i bar fill
    fill=$(( (used * ccells + 50) / 100 )); (( fill > ccells )) && fill=$ccells
    bar="${sc}"; for (( i = 0; i < fill; i++ )); do bar+="▰"; done
    bar+="${TRACK}"; for (( i = fill; i < ccells; i++ )); do bar+="▱"; done
    local s="${CTX}${I_CTX}${R} ${bar}${R} ${TEXT}${used}%${R}"
    (( tok > 0 )) && s+=" ${sc}${I_CMP} $(fmt_tok "$room")${R}"
    printf '%s' "$s"
}

seg_clock() {
    (( date_on )) && printf '%s ' "${MUTED}${c_date}${R}"
    printf '%s' "${TEXT}${c_time}${R}"
}

seg_cache() {
    [ "$pc_obs" = true ] || return
    local ttl_s=300 left=0 thr cc s
    [ "$pc_ttl" = 1h ] && ttl_s=3600
    [ "$pc_warm" = true ] && [ -n "$pc_exp" ] && left=$(( pc_exp - now ))
    if (( left > 0 )); then
        thr=$(( ttl_s / 5 )); (( thr < 60 )) && thr=60; (( thr > 300 )) && thr=300
        (( left < thr )) && cc=$WARN || cc=$CACHE
        s="${cc}${I_CACHE} $(fmt_dur "$left")${R}"
        (( hit )) && s+="${MUTED}/${pc_ttl}${R}"
    else
        s="${WARN}${I_CACHE} cold${R}"
        [ -n "$pc_recache" ] && s+=" ${MUTED}+$(fmt_tok "$pc_recache")${R}"
    fi
    # First request only writes the cache, so its 0% hit says nothing yet.
    if (( hit )) && [ -n "$pc_hit" ] && (( ${pc_req:-0} > 1 )); then
        (( hitword )) && s+=" ${MUTED}hit${R}"
        s+=" ${TEXT}${pc_hit}%${R}"
    fi
    if (( ${pc_misses:-0} > 0 )); then
        s+=" ${CRIT}✗${pc_misses}${R}"
        (( cause )) && [ -n "$pc_cause" ] && s+=" ${MUTED}${pc_cause//_/ }${R}"
    fi
    printf '%s' "$s"
}

# Quota shows what is LEFT. Each pace cell is "▀": the top half (fg) is quota
# left, the bottom half (bg) time left in the window. +N% = N points of quota
# to spare versus the clock, -N% = burning faster than the window refills.
quota_seg() {   # label used reset length show_reset
    local label=$1 used=$2 reset=$3 length=$4 show_reset=$5
    [ -z "$used" ] && return
    [ -n "$reset" ] && (( reset <= now )) && return   # window already reset: stale
    local rem=$(( 100 - used )) qc=$QUOTA
    (( rem < 0 )) && rem=0
    (( rem <= 30 )) && qc=$WARN
    (( rem <= 10 )) && qc=$CRIT
    local out="${MUTED}${label}${R} "
    if [ -n "$reset" ]; then
        local left=$(( reset - now ))
        local tleft=$(( left * 100 / length ))
        (( tleft < 0 )) && tleft=0; (( tleft > 100 )) && tleft=100
        if (( qcells > 0 )); then
            local q=$(( (rem * qcells + 50) / 100 )) t=$(( (tleft * qcells + 50) / 100 )) i
            for (( i = 0; i < qcells; i++ )); do
                if (( i < q )); then out+="$qc"; else out+="$TRACK"; fi
                if (( i < t )); then out+="$PASSED_BG"; else out+="$TRACK_BG"; fi
                out+="▀"
            done
            out+="${R} "
        fi
        out+="${qc}${rem}%${R}"
        if (( arrow )); then
            local d=$(( rem - tleft ))
            if   (( d > 0 )); then out+=" ${OK}+${d}%${R}"
            elif (( d < 0 )); then out+=" ${WARN}-$(( -d ))%${R}"
            else out+=" ${MUTED}±0%${R}"; fi
        fi
        (( show_reset )) && out+=" ${MUTED}↻$(fmt_dur "$left")${R}"
    else
        out+="${qc}${rem}%${R}"
    fi
    printf '%s' "$out"
}

seg_quota() {
    local a b
    a=$(quota_seg 5h "$r5_used" "$r5_reset" 18000 "$r5")
    b=$(quota_seg 7d "$r7_used" "$r7_reset" 604800 "$r7")
    [ -z "$a$b" ] && return
    printf '%s' "${QUOTA}${I_QUOTA}${R} $(join_segs "$a" "$b")"
}

seg_dur() {
    (( dur )) && [ -n "$dur_ms" ] && printf '%s' "${SESS}${I_DUR} $(fmt_dur $((dur_ms / 1000)))${R}"
}

# ── Layout ───────────────────────────────────────────────────────────────────
# Each line is a left group and a right group; the gap between them is padded so
# both lines end on the same column at every shrink level.
#   Line 1: model │ dir │ git │ context ........................ date time
#   Line 2: cache ............................ 5h │ 7d │ duration
# Claude Code passes the terminal width in COLUMNS (2.1.153+).
shopt -s extglob
vis_width() { local s=${1//$'\e['*([0-9;])m/}; printf '%d' "${#s}"; }
GAP_MIN=3
avail=$(( ${COLUMNS:-200} - 4 ))

MAX_LEVEL=12
done1=0; done2=0
for (( lvl = 0; lvl <= MAX_LEVEL; lvl++ )); do
    set_level "$lvl"
    if (( ! done1 )); then
        l1_left=$(join_segs "$(seg_model)" "$(seg_dir)" "$(seg_git)" "$(seg_ctx)")
        l1_right=$(seg_clock)
        w1=$(( $(vis_width "$l1_left") + GAP_MIN + $(vis_width "$l1_right") ))
        (( w1 <= avail || lvl == MAX_LEVEL )) && done1=1
    fi
    if (( ! done2 )); then
        l2_left=$(seg_cache)
        l2_right=$(join_segs "$(seg_quota)" "$(seg_dur)")
        [ -z "$l2_left" ] && { l2_left=$l2_right; l2_right=""; }
        w2r=$(vis_width "$l2_right")
        w2=$(( $(vis_width "$l2_left") + (w2r > 0 ? GAP_MIN + w2r : 0) ))
        (( w2 <= avail || lvl == MAX_LEVEL )) && done2=1
    fi
    (( done1 && done2 )) && break
done
width=$(( w1 > w2 ? w1 : w2 ))

render_line() {   # left right
    local lw rw gap pad
    lw=$(vis_width "$1"); rw=$(vis_width "$2")
    gap=$(( width - lw - rw )); (( gap < 1 )) && gap=1
    [ -z "$2" ] && gap=0
    printf -v pad '%*s' "$gap" ''
    printf '%s%s%s\n' "$1" "$pad" "$2"
}
render_line "$l1_left" "$l1_right"
if [ -n "$l2_left$l2_right" ]; then render_line "$l2_left" "$l2_right"; fi
