import { useLocalSearchParams } from 'expo-router';
import { ScrollView } from 'react-native';

import { parseCount, Rows } from '../components/Rows';

// Control arm: the same content in a plain ScrollView, no Reanimated.
export default function PlainForm() {
  const { rows } = useLocalSearchParams<{ rows?: string }>();
  return (
    <ScrollView>
      <Rows count={parseCount(rows)} />
    </ScrollView>
  );
}
