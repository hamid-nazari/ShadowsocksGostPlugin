set -e
NDK_VERSION_IF_MISSING=r23b
GOST_VERSION=3.0.0-alpha.6
GOLANG_VERSION=1.19.2
cd $( cd "$( dirname "$0"  )" && pwd  )
git submodule update --init --recursive
if [ ! -e build ]
then
mkdir build
fi
cd build
if [ ! -e go ]
then
echo "GO was not detected, downloading ..."
curl "https://dl.google.com/go/go$GOLANG_VERSION.linux-amd64.tar.gz" -L | tar -zx || exit $?
cd go
patch -p1 -r . < ../../go.patch
cd ..
fi
export PATH=$PWD/go/bin:$PATH
export GOROOT=$PWD/go
echo "Current GO version: $(go version)"
if [ ! -e gost ] && [ -d ../gost ]
then
mv -v ../gost .
fi

IS_NDK_MISSING=true
if [ ! -z "$ANDROID_NDK_ROOT" ]
then
  IS_NDK_MISSING=$([[ ! -d $ANDROID_NDK_ROOT || -z "$(find $ANDROID_NDK_ROOT -iname "*clang" -print -quit)" ]] && echo true || echo false);
fi

if $IS_NDK_MISSING
then
  ANDROID_NDK_ROOT=$(find ~+/ndk -maxdepth 1 -mindepth 1 -type d -print -quit);
  IS_NDK_MISSING=$([[ ! -d $ANDROID_NDK_ROOT || -z "$(find $ANDROID_NDK_ROOT -iname "*clang" -print -quit)" ]] && echo true || echo false);
fi

if $IS_NDK_MISSING
then
echo "No NDK could be detected, downloading ..."
mkdir -p ndk
cd ndk
curl https://dl.google.com/android/repository/android-ndk-${NDK_VERSION_IF_MISSING}-linux.zip -L -o ndk.zip
unzip ndk.zip > /dev/null || exit $?
rm -f ndk.zip
[ ! -d android-ndk-${NDK_VERSION_IF_MISSING} ] && echo "Missing directory: android-ndk-${NDK_VERSION_IF_MISSING}" && exit 1
export ANDROID_NDK_ROOT=$PWD/android-ndk-${NDK_VERSION_IF_MISSING}
cd ..
fi

echo "Android NDK root=$ANDROID_NDK_ROOT"

cd gost

echo "Begining build:"

CC_=$(find $ANDROID_NDK_ROOT -iname "*armv7a-linux-androideabi21-clang" -print -quit);
[ ! -z "$CC_" ] && echo " + Building for '$(basename $CC_)' ..." && CC=$CC_ GOOS="android" GOARCH="arm" CGO_ENABLED="1" \
go build -v -buildvcs=false -ldflags "-s -w" -a -o ../../app/src/main/jniLibs/armeabi-v7a/libgost-plugin.so ./cmd/gost

CC_=$(find $ANDROID_NDK_ROOT -iname "*aarch64-linux-android21-clang" -print -quit);
[ ! -z "$CC_" ] && echo " + Building for '$(basename $CC_)' ..." && CC=$CC_ GOOS="android" GOARCH="arm64" CGO_ENABLED="1" \
go build -v -buildvcs=false -ldflags "-s -w" -a -o ../../app/src/main/jniLibs/arm64-v8a/libgost-plugin.so ./cmd/gost

CC_=$(find $ANDROID_NDK_ROOT -iname "*i686-linux-android21-clang" -print -quit);
[ ! -z "$CC_" ] && echo " + Building for '$(basename $CC_)' ..." && CC=$CC_ GOOS="android" GOARCH="386" CGO_ENABLED="1" \
go build -v -buildvcs=false -ldflags "-s -w" -a -o ../../app/src/main/jniLibs/x86/libgost-plugin.so ./cmd/gost

CC_=$(find $ANDROID_NDK_ROOT -iname "*x86_64-linux-android21-clang" -print -quit);
[ ! -z "$CC_" ] && echo " + Building for '$(basename $CC_)' ..." && CC=$CC_ GOOS="android" GOARCH="amd64" CGO_ENABLED="1" \
go build -v -buildvcs=false -ldflags "-s -w" -a -o ../../app/src/main/jniLibs/x86_64/libgost-plugin.so ./cmd/gost
