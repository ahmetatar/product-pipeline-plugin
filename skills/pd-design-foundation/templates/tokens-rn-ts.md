# Skeleton — React Native / TypeScript tokens file

Path: `src/design-system/tokens.ts`

```ts
import { useColorScheme } from 'react-native';

const light = {
  color: { primary: '#2E5BFF', onPrimary: '#FFFFFF', background: '#F8F9FB' /* ... */ },
};
const dark = {
  color: { primary: '#6B8EFF', onPrimary: '#0E0F12', background: '#0E0F12' /* ... */ },
};

export const staticTokens = {
  font:   { body: { fontSize: 17, lineHeight: 24, fontWeight: '400' as const }, title: { fontSize: 22, lineHeight: 28, fontWeight: '600' as const } },
  space:  { xs: 4, sm: 8, md: 16, lg: 24 },
  radius: { sm: 8, md: 14, lg: 20, full: 999 },
};

export function useTokens() {
  const scheme = useColorScheme();
  return { ...(scheme === 'dark' ? dark : light), ...staticTokens };
}
```
