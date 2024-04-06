This is a [native plugin](https://github.com/shadowsocks/shadowsocks-android/blob/master/plugin/doc.md) for [Shadowsocks Android](https://github.com/shadowsocks/shadowsocks-android) which allows access to [GOST](https://github.com/go-gost/gost) functionality on Android clients.
This is based on valuable contributions from [@xausky](https://github.com/xausky) and [@segfault-bilibili](https://github.com/segfault-bilibili) on [Shadowsocks GOST Plugin](https://github.com/segfault-bilibili/ShadowsocksGostPlugin).
I'll try my best to keep this live and up-to-date.

# Build
Since I'm trying to revive the plugin, I decided to make least changes to the upstream work. Hence, this project can only be built on any *nix platfrom which supports *Bash, Android NDK, Go and GCC* (e.g., Ubuntu). I'll increase build portability in furture releases.
This project may be built using `Gradle` (with few dependencies provided) or direectly from *Android Studio*. Dependencies are outlined below.
## Common Build Dependencies
- Android SDK 26+
- Android NDK 26.2+
- GCC 11.4.0+
### Android Studio Builds
- Android Studio Hedgehog | 2023.1.1 Patch 2 (or above)
### Gradle Builds
- JDK 17+ 
- Gradle 8.6+
