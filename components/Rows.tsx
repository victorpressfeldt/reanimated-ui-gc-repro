import { StyleSheet, Text, TextInput, View } from 'react-native';

// Both arms render exactly this content, so the only difference between them
// is the scroll container.
export function Rows({ count }: { count: number }) {
  return Array.from({ length: count }, (_, i) => (
    <View key={i} style={styles.row}>
      <Text>Row {i}</Text>
      <TextInput placeholder={`Field ${i}`} style={styles.input} />
    </View>
  ));
}

export function parseCount(rows: string | string[] | undefined): number {
  const n = Number(Array.isArray(rows) ? rows[0] : rows);
  return Number.isInteger(n) && n > 0 ? n : 300;
}

const styles = StyleSheet.create({
  row: { padding: 8, borderBottomWidth: 1 },
  input: { borderWidth: 1 },
});
