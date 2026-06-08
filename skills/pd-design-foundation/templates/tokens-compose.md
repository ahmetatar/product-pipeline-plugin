# Skeleton — Jetpack Compose tokens file

Path: `app/src/main/java/.../ui/theme/Tokens.kt`

```kotlin
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

object Tokens {
    object Color {
        val LightPrimary    = androidx.compose.ui.graphics.Color(0xFF2E5BFF)
        val DarkPrimary     = androidx.compose.ui.graphics.Color(0xFF6B8EFF)
        val LightOnPrimary  = androidx.compose.ui.graphics.Color(0xFFFFFFFF)
        val DarkOnPrimary   = androidx.compose.ui.graphics.Color(0xFF0E0F12)
        // ... one Light/Dark pair per spec token
    }
    val LightScheme = lightColorScheme(primary = Color.LightPrimary, onPrimary = Color.LightOnPrimary /*, ...*/)
    val DarkScheme  = darkColorScheme(primary = Color.DarkPrimary, onPrimary = Color.DarkOnPrimary /*, ...*/)

    object Type {
        val Body    = TextStyle(fontSize = 17.sp, lineHeight = 24.sp, fontWeight = FontWeight.Normal)
        val Title   = TextStyle(fontSize = 22.sp, lineHeight = 28.sp, fontWeight = FontWeight.SemiBold)
        val Caption = TextStyle(fontSize = 13.sp, lineHeight = 18.sp, fontWeight = FontWeight.Normal)
    }
    object Space { val xs = 4.dp; val sm = 8.dp; val md = 16.dp; val lg = 24.dp }
    object Radius { val sm = 8.dp; val md = 14.dp; val lg = 20.dp; val full = 999.dp }
}
```

Consumers wrap their root in `MaterialTheme(colorScheme = if (isSystemInDarkTheme()) Tokens.DarkScheme else Tokens.LightScheme)`.
