# Unmounted Fabric subtrees held by garbage in the Reanimated UI runtime

A minimal Android app. It shows that after a screen with an `Animated.ScrollView` and
`useAnimatedRef` is closed, its Fabric nodes stay in the native heap until a garbage
collection runs **in the Reanimated/Worklets UI runtime**. `onTrimMemory` does not
release them, and neither does a GC in the React Native runtime.

## Result in short

Reanimated 4.8.0, Worklets 0.14.0, React Native 0.88.1, release build, Samsung Galaxy
A22 5G. 20 times open and close a screen with 300 rows. "Heap Alloc" is the `Native Heap`
row of `adb shell dumpsys meminfo`.

| | `Animated.ScrollView` + `useAnimatedRef` | plain `ScrollView` (control) |
|---|---|---|
| After lap 1 | 50.4 MB | 52.2 MB |
| After lap 20 | 163.8 MB, linear, about +6.0 MB per lap, no drop | 68.3 MB, sawtooth, peak 91.4 MB |
| After `am send-trim-memory … RUNNING_CRITICAL` + 30 s | 162.1 MB | 45.8 MB |
| After `gc()` in the RN runtime | 150.2 MB | 34.0 MB |
| After `gc()` in the UI runtime | **32.5 MB** | 34.2 MB |

Heap Alloc right after a cold start was 29.1 MB (test arm) and 31.3 MB (control).

## The app

- `app/index.tsx`: Home, with these buttons:
  - **Open animated** → `app/animated.tsx`: the rows inside `Animated.ScrollView` with a
    ref from `useAnimatedRef`.
  - **Open plain** → `app/plain.tsx`: the same rows inside `ScrollView` from
    `react-native`. No Reanimated on this screen.
  - **GC RN runtime**: calls `globalThis.gc()` in the React Native runtime.
  - **GC UI runtime**: calls `scheduleOnUI(() => { 'worklet'; globalThis.gc(); })`.
  - **Toggle animation**: mounts a small `Animated.View` on Home that rotates forever
    (`withRepeat`). It is off by default.
  - A status line shows which runtime ran the last GC, `typeof gc` there and the time
    it took.
- `components/Rows.tsx`: the rows, shared by both screens. One row is a `View` with a
  `Text` and a `TextInput`. The default is 300 rows; `?rows=<n>` changes it.
- Deep links: `uigcrepro:///animated?rows=300` and `uigcrepro:///plain?rows=300`.

`gc` is a global function in both runtimes of a release build, so no special build is
needed.

## Versions

Two version sets are kept in `versions/`. `package.json` in the root is `sdk57`.

| Set | Expo | React Native | Reanimated | Worklets | React |
|---|---|---|---|---|---|
| `sdk57` | 57.0.7 | 0.86.0 | 4.5.1 | 0.10.2 | 19.2.3 |
| `sdk58` | 58.0.26 | 0.88.1 | 4.8.0 | 0.14.0 | 19.3.0 |

The source files are the same for both sets. New Architecture, Hermes, expo-router.

## Build and run

Needs Node, JDK 17, the Android SDK (`ANDROID_HOME`) and a device with adb. The builds
here were made with Node 22 on Linux (WSL2).

```sh
scripts/use-versions.sh sdk58     # or sdk57; copies the manifest and runs npm ci
scripts/build.sh                  # expo prebuild + gradlew assembleRelease (arm64)
adb install -r ui-gc-repro.apk

scripts/laps.sh animated 20       # test arm
scripts/laps.sh plain 20          # control arm
```

`scripts/laps.sh <animated|plain> [laps] [rows]` cold-starts the app. For each lap it
opens the screen with a deep link, waits 5 s, presses BACK, waits 5 s and prints Heap
Alloc. After the last lap it sends `trim-memory RUNNING_CRITICAL`, waits 30 s, and then
presses **GC RN runtime** and **GC UI runtime** twice in turn, with a reading after each
step. Options (environment variables):

- `DEV=<serial>`: the adb device.
- `ANIMATE=1`: press **Toggle animation** before the first lap and again after the last.
- `GC_RN_EACH_LAP=1`: press **GC RN runtime** after every lap, before the reading.

By hand: open and close **Open animated** a number of times, read
`adb shell dumpsys meminfo com.example.uigcrepro` (`Native Heap`, column `Heap Alloc`),
press **GC UI runtime** and read again.

## Measurements

Samsung Galaxy A22 5G (SM-A226B), Android 13, release build, 300 rows, 20 laps, one run
per row unless stated. Heap Alloc in MB (kB / 1024). The raw output of every run is in
`results/`.

"Start" is the reading after the cold start, and after the animation was started in the
rows where it is on. "Trim" is the reading 30 s after `trim-memory RUNNING_CRITICAL`.
"RN gc" and "UI gc" are the readings after the first press of each button, in that order.

### Reanimated 4.8.0, Worklets 0.14.0, React Native 0.88.1

| Arm | Animation | RN gc each lap | Start | Lap 1 | Lap 20 | Peak (lap) | Trim | RN gc | UI gc |
|---|---|---|---|---|---|---|---|---|---|
| animated (run 2) | off | no | 29.1 | 50.4 | 163.8 | 163.8 (20) | 162.1 | 150.2 | **32.5** |
| animated (run 1) | off | no | 28.8 | 50.7 | 163.5 | 163.5 (20) | 161.7 | 150.0 | **32.4** |
| plain | off | no | 31.3 | 52.2 | 68.3 | 91.4 (10) | 45.8 | 34.0 | 34.2 |
| animated | on | no | 33.0 | 54.4 | 166.9 | 166.9 (20) | 152.8 | 152.8 | **35.2** |
| plain | on | no | 33.0 | 54.5 | 62.0 | 94.4 (11) | 34.4 | 34.5 | 34.8 |
| animated | on | yes | 33.0 | 55.0 | 120.7 | 120.7 (20) | 107.8 | 107.8 | **37.3** |
| plain | on | yes | 32.9 | 46.8 | 47.1 | 47.4 (3) | 34.0 | 34.1 | 34.2 |

### Reanimated 4.5.1, Worklets 0.10.2, React Native 0.86.0

| Arm | Animation | RN gc each lap | Start | Lap 1 | Lap 20 | Peak (lap) | Trim | RN gc | UI gc |
|---|---|---|---|---|---|---|---|---|---|
| animated | off | no | 49.4 | 126.9 | 175.0 | 193.5 (12) | 174.9 | 162.9 | **111.3** |
| plain | off | no | 49.7 | 69.7 | 75.3 | 105.2 (10) | 64.4 | 52.8 | 54.0 |
| animated | off | yes | 49.7 | 126.9 | 151.3 | 174.2 (9) | 128.2 | 116.2 | **111.0** |
| plain | off | yes | 49.8 | 63.6 | 63.9 | 64.1 (12) | 64.0 | 52.2 | 53.4 |
| animated | on | no | 148.0 | 168.4 | 281.2 | 281.2 (20) | 267.3 | 267.2 | **152.1** |
| plain | on | no | 146.0 | 166.6 | 191.2 | 200.1 (9) | 148.8 | 148.8 | 149.5 |

## Reading the numbers

- **Control arm.** Heap Alloc rises between collections of the React Native runtime and
  falls back when that runtime collects. With a forced RN-runtime GC after every lap it
  is flat (47 MB on 4.8.0, 64 MB on 4.5.1). After trim and an RN-runtime GC it is back
  near the start level. A UI-runtime GC changes nothing. This is the known behaviour
  where JS wrappers keep shadow nodes alive until the next GC.
- **Test arm.** With the same forced RN-runtime GC after every lap, Heap Alloc still
  grows. So part of the memory is not held by the React Native runtime. Trim and
  RN-runtime GC leave most of it in place. One `gc()` in the UI runtime releases it:
  about 118 MB in each of the three 4.8.0 runs without forced GC, and 115 MB in the
  4.5.1 run with the animation on.
- **Does the UI runtime collect by itself?** On 4.8.0 it did not, in 20 laps, with or
  without the animation. On 4.5.1 without the animation it did, so the growth there is
  a large sawtooth: with forced RN-runtime GC after every lap, Heap Alloc fell by 52 MB
  at lap 10 and by 23 MB at lap 16, and without forced GC it fell by 46 MB at lap 13. On
  4.5.1 with the animation running there was no drop in 20 laps.
- The growth per lap in the test arm is about 6 MB wherever nothing collects (4.8.0:
  5.9 to 6.0 MB per lap; 4.5.1 with the animation: 5.9 MB per lap).

## Other observations (not investigated)

- On 4.5.1 the first animated screen leaves about 60 MB that neither GC releases (level
  111 MB afterwards, against 53 MB in the control arm). Starting the animation on 4.5.1
  raises Heap Alloc by about 100 MB (start level 148 MB against 49 MB). Neither shows on
  4.8.0.
- In the runs without the animation, on both version sets, the first press of **GC RN
  runtime** after the trim released about 12 MB more than the trim had. In the runs
  with the animation it released nothing more.
- With forced RN-runtime GC on 4.8.0 (animation on) the test arm grew in steps: some
  laps added about 6 MB and some added nothing.

## Limits

- One device and one run per configuration, except the 4.8.0 test arm without the
  animation, which was run twice. Android only; iOS was not tested.
- 20 laps per run. Whether the UI runtime on 4.8.0 would collect by itself later was
  not measured.
- The 4.5.1 runs without the animation were made with a build from before the **Toggle
  animation** button was added to Home. The two screens under test did not change.
- On 4.8.0, run 2 of the test arm and the control run without the animation were made
  with the build from the manifest in `versions/`. The other 4.8.0 runs were made with
  a build from before `react-dom` was added to `package.json`.
- The app shows that a UI-runtime GC releases the memory. It does not show which
  objects in the UI runtime hold the nodes.

## Related

- software-mansion/react-native-reanimated#10521
- software-mansion/react-native-reanimated#10851 (part of 4.8.0)
- "The memory Hermes can't see: stale shadow nodes in React Native" (Software Mansion
  blog, 2026-08-05)
