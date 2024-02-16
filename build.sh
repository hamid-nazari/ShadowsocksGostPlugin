#!/bin/bash

set -e
NDK_VERSION_IF_MISSING=r23b
GOST_VERSION=3.0.0-alpha.6
GOLANG_VERSION=1.19.2
cd $( cd "$( dirname "$0"  )" && pwd  )
git submodule update --init --recursive
if [ ! -d build ]
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
echo "Current GO version: $(go version|grep -oP "\d.*")"
if [ ! -e gost ] && [ -d ../gost ]
then
cp -r ../gost .
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

echo "Android NDK root: $ANDROID_NDK_ROOT"

cd gost

src="./cmd/gost";
latest_mod=$(find $src -mindepth 1 -type f -printf '%T@\n' | sort -k1,1nr | head -1);

output="../../app/src/main/jniLibs/armeabi-v7a/libgost-plugin.so";
GOARCH_="arm"
CC_=$(find $ANDROID_NDK_ROOT -iname "*armv7a-linux-androideabi21-clang" -print -quit);
[[ ! -z "$CC_" && (! -f $output || $(stat -c %Y $output) < $latest_mod) ]] \
|| (echo " + Skipping build for '$GOARCH_'" && exit 1) \
&& echo " + Building for '$GOARCH_' ..." \
&& CC=$CC_ GOOS="android" GOARCH=$GOARCH_ CGO_ENABLED="1" go build -buildvcs=false -ldflags "-s -w" -a -o $output $src;

output="../../app/src/main/jniLibs/arm64-v8a/libgost-plugin.so";
GOARCH_="arm64"
CC_=$(find $ANDROID_NDK_ROOT -iname "*aarch64-linux-android21-clang" -print -quit);
[[ ! -z "$CC_" && (! -f $output || $(stat -c %Y $output) < $latest_mod) ]] \
|| (echo " + Skipping build for '$GOARCH_'" && exit 1) \
&& echo " + Building for '$GOARCH_' ..." \
&& CC=$CC_ GOOS="android" GOARCH=$GOARCH_ CGO_ENABLED="1" go build -buildvcs=false -ldflags "-s -w" -a -o $output $src;

output="../../app/src/main/jniLibs/x86/libgost-plugin.so";
GOARCH_="386"
CC_=$(find $ANDROID_NDK_ROOT -iname "*i686-linux-android21-clang" -print -quit);
[[ ! -z "$CC_" && (! -f $output || $(stat -c %Y $output) < $latest_mod) ]] \
|| (echo " + Skipping build for '$GOARCH_'" && exit 1) \
&& echo " + Building for '$GOARCH_' ..." \
&& CC=$CC_ GOOS="android" GOARCH=$GOARCH_ CGO_ENABLED="1" go build -buildvcs=false -ldflags "-s -w" -a -o $output $src;

output="../../app/src/main/jniLibs/x86_64/libgost-plugin.so";
GOARCH_="amd64"
CC_=$(find $ANDROID_NDK_ROOT -iname "*x86_64-linux-android21-clang" -print -quit);
[[ ! -z "$CC_" && (! -f $output || $(stat -c %Y $output) < $latest_mod) ]] \
|| (echo " + Skipping build for '$GOARCH_'" && exit 1) \
&& echo " + Building for '$GOARCH_' ..." \
&& CC=$CC_ GOOS="android" GOARCH=$GOARCH_ CGO_ENABLED="1" go build -buildvcs=false -ldflags "-s -w" -a -o $output $src;

exit 0;
