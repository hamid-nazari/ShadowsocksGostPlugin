This is a [native plugin](https://github.com/shadowsocks/shadowsocks-android/blob/master/plugin/doc.md) for [Shadowsocks Android](https://github.com/shadowsocks/shadowsocks-android) which allows access to [GOST](https://github.com/go-gost/gost) functionality on Android clients.
This is based on valuable work by [@xausky](https://github.com/xausky) and [@segfault-bilibili](https://github.com/segfault-bilibili) on [Shadowsocks GOST Plugin](https://github.com/segfault-bilibili/ShadowsocksGostPlugin).
I'll try my best to keep this live and up-to-date.

# Build
I decided to make the least changes to the upstream code. Therefore, currently it can only be built on *nix platfroms* which support *Bash, Android NDK, Go and GCC* (like, Ubuntu). Build portability will be increased in furture releases.
After `cloning` this repo locally, the project may be built either using `Gradle` (with few dependencies provided) or direectly from *Android Studio*.
Dependencies are outlined below. *Gradle* needs internet access to obtain compile and runtime dependencies.
## Common Build Dependencies
- Android SDK 26+
- Android NDK 26.2+
- GCC 11.4.0+
### Android Studio Builds
- Android Studio Hedgehog | 2023.1.1 Patch 2 (or above)
To build, go to *Gradle* view and click on *Execute a gradle task* on the toolbar and type `gradle build`
### Gradle Builds
- JDK 17+ 
- Gradle 8.6+
To build, open a terminal in the root of the project and type `./gradlew build`