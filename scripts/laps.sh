#!/usr/bin/env bash
# Usage: scripts/laps.sh <animated|plain> [laps=20] [rows=300]
# Cold-starts the app, opens and closes the chosen screen <laps> times and
# prints the native Heap Alloc (kB, from `dumpsys meminfo`) after each lap.
# Then: trim-memory + 30 s, followed by two rounds of "GC RN runtime" and
# "GC UI runtime", with one reading after each step.
#
# Environment:
#   DEV=<adb serial>     when more than one device is attached
#   GC_RN_EACH_LAP=1     press "GC RN runtime" after every lap, before reading
#   ANIMATE=1            press "Toggle animation" before the first lap and
#                        again after the last one
#   SETTLE=<seconds>     wait after open and after close (default 5)
set -u
export MSYS_NO_PATHCONV=1

ARM=${1:?usage: laps.sh <animated|plain> [laps] [rows]}
LAPS=${2:-20}
ROWS=${3:-300}
PKG=com.example.uigcrepro
SETTLE=${SETTLE:-5}
GC_RN_EACH_LAP=${GC_RN_EACH_LAP:-0}
ANIMATE=${ANIMATE:-0}

a() { adb ${DEV:+-s "$DEV"} "$@"; }

mem() {
  a shell dumpsys meminfo $PKG | awk '
    /^ +Native Heap /{printf "heap_alloc_kb=%s ", $9}
    /TOTAL PSS:/{printf "pss_kb=%s ", $3}
    /^ +Views:/{printf "views=%s", $2}
    END{print ""}'
}

in_front() {
  a shell dumpsys activity activities | grep -E "(mResumedActivity|topResumedActivity|ResumedActivity:)" | grep -q "$PKG"
}

nodes() { a exec-out uiautomator dump /dev/tty | tr '>' '\n'; }

frames() { a shell dumpsys gfxinfo $PKG | awk '/Total frames rendered:/{print $4; exit}'; }

# Prints "x y", the centre of the first node whose text is exactly $1.
center_of() {
  nodes | grep -F "text=\"$1\"" | head -1 |
    sed -E 's/.*bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]".*/\1 \2 \3 \4/' |
    awk 'NF==4{print int(($1+$3)/2), int(($2+$4)/2)}'
}

status_line() {
  nodes | grep -oE 'text="(#[0-9]+ [A-Z]+ gc|no gc)[^"]*"' | head -1 | sed -E 's/^text="(.*)"$/\1/'
}

a shell "input keyevent KEYCODE_WAKEUP; wm dismiss-keyguard"
a shell am force-stop $PKG
sleep 2
a shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 12
in_front || { echo "app is not in front after launch"; exit 1; }

RN_XY=$(center_of "GC RN runtime")
UI_XY=$(center_of "GC UI runtime")
[ -z "$RN_XY" ] || [ -z "$UI_XY" ] && { echo "cannot find the GC buttons on screen"; exit 1; }

if [ "$ANIMATE" = 1 ]; then
  TOGGLE_XY=$(center_of "Toggle animation")
  [ -z "$TOGGLE_XY" ] && { echo "cannot find \"Toggle animation\" on screen"; exit 1; }
  a shell input tap $TOGGLE_XY
  sleep 3
  # uiautomator cannot dump a screen that never goes idle, so the running
  # animation is confirmed by the frame counter instead.
  f1=$(frames); sleep 2; f2=$(frames)
  [ "$f2" -gt $((f1 + 30)) ] || { echo "the animation did not start ($f1 -> $f2 frames in 2 s)"; exit 1; }
fi

echo "arm=$ARM laps=$LAPS rows=$ROWS settle=${SETTLE}s gc_rn_each_lap=$GC_RN_EACH_LAP animate=$ANIMATE"
echo -n "start: "; mem
for i in $(seq 1 "$LAPS"); do
  a shell "am start -a android.intent.action.VIEW -d 'uigcrepro:///$ARM?rows=$ROWS' $PKG" >/dev/null 2>&1
  sleep "$SETTLE"
  a shell input keyevent KEYCODE_BACK
  sleep "$SETTLE"
  in_front || { echo "lap $i: app left the foreground (did the screen open?)"; exit 1; }
  if [ "$GC_RN_EACH_LAP" = 1 ]; then
    a shell input tap $RN_XY
    sleep 2
  fi
  echo -n "lap $i: "; mem
done

if [ "$ANIMATE" = 1 ]; then
  # Stop the animation so that the status line can be read back below.
  a shell input tap $TOGGLE_XY
  sleep 2
  echo -n "animation stopped: "; mem
fi

a shell am send-trim-memory $PKG RUNNING_CRITICAL
sleep 30
echo -n "after trim-memory RUNNING_CRITICAL + 30 s: "; mem

for round in 1 2; do
  a shell input tap $RN_XY; sleep 5
  echo -n "round $round, after GC RN runtime [$(status_line)]: "; mem
  a shell input tap $UI_XY; sleep 5
  echo -n "round $round, after GC UI runtime [$(status_line)]: "; mem
done
