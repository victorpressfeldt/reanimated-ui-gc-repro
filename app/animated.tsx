import { useLocalSearchParams } from 'expo-router';
import Animated, { useAnimatedRef } from 'react-native-reanimated';

import { parseCount, Rows } from '../components/Rows';

// Test arm: Animated.ScrollView + useAnimatedRef.
export default function AnimatedForm() {
  const { rows } = useLocalSearchParams<{ rows?: string }>();
  const ref = useAnimatedRef<Animated.ScrollView>();
  return (
    <Animated.ScrollView ref={ref}>
      <Rows count={parseCount(rows)} />
    </Animated.ScrollView>
  );
}
