import { Link } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';
import { scheduleOnRN, scheduleOnUI } from 'react-native-worklets';

type WithGc = { gc?: () => void };

// An endless animation. It keeps the UI runtime allocating on every frame,
// like any app that has an animation running somewhere.
function Spinner() {
  const turn = useSharedValue(0);
  useEffect(() => {
    turn.value = withRepeat(
      withTiming(1, { duration: 1000, easing: Easing.linear }),
      -1
    );
  }, [turn]);
  const style = useAnimatedStyle(() => ({
    transform: [{ rotate: `${turn.value * 360}deg` }],
  }));
  return <Animated.View style={[styles.spinner, style]} />;
}

export default function Home() {
  const [status, setStatus] = useState('no gc requested');
  const [spinning, setSpinning] = useState(false);
  const seq = useRef(0);

  const report = (runtime: string, kind: string, ms: number) => {
    seq.current += 1;
    setStatus(`#${seq.current} ${runtime} gc: typeof gc = ${kind}, ${ms} ms`);
  };

  const gcUiRuntime = () => {
    scheduleOnUI(() => {
      'worklet';
      const gc = (globalThis as WithGc).gc;
      const start = Date.now();
      gc?.();
      scheduleOnRN(report, 'UI', typeof gc, Date.now() - start);
    });
  };

  const gcRnRuntime = () => {
    const gc = (globalThis as WithGc).gc;
    const start = Date.now();
    gc?.();
    report('RN', typeof gc, Date.now() - start);
  };

  return (
    <View style={styles.container}>
      <Link href="/animated" style={styles.button}>
        Open animated
      </Link>
      <Link href="/plain" style={styles.button}>
        Open plain
      </Link>
      <Pressable onPress={gcRnRuntime}>
        <Text style={styles.button}>GC RN runtime</Text>
      </Pressable>
      <Pressable onPress={gcUiRuntime}>
        <Text style={styles.button}>GC UI runtime</Text>
      </Pressable>
      <Pressable onPress={() => setSpinning((on) => !on)}>
        <Text style={styles.button}>Toggle animation</Text>
      </Pressable>
      <Text>{status}</Text>
      <Text>animation: {spinning ? 'on' : 'off'}</Text>
      {spinning && <Spinner />}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 32, gap: 24 },
  button: { padding: 16, borderWidth: 1, fontSize: 18, textAlign: 'center' },
  spinner: { width: 40, height: 40, backgroundColor: 'black' },
});
