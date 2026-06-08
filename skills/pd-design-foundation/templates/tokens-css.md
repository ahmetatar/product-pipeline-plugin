# Skeleton — CSS / Web tokens file

Path: `src/styles/tokens.css`

```css
:root {
  --color-primary: #2E5BFF;
  --color-on-primary: #FFFFFF;
  --color-background: #F8F9FB;
  --font-body-size: 1.0625rem;     /* 17px */
  --font-body-line: 1.5rem;         /* 24px */
  --space-xs: 0.25rem;  --space-sm: 0.5rem;  --space-md: 1rem;  --space-lg: 1.5rem;
  --radius-sm: 0.5rem;  --radius-md: 0.875rem;  --radius-lg: 1.25rem;  --radius-full: 9999px;
}
@media (prefers-color-scheme: dark) {
  :root {
    --color-primary: #6B8EFF;
    --color-on-primary: #0E0F12;
    --color-background: #0E0F12;
  }
}
```
