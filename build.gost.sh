#!/bin/bash

GOLANG_VERSION="1.22.0"
GOST_VERSION="3.0.0-nightly.20240201"
NDK_VERSION_IF_MISSING="r26c"

set -e

pushd $( cd "$( dirname "$0"  )" && pwd ) > /dev/null

if [ ! -d ".go_build" ]
then
  mkdir ".go_build"
fi
pushd ".go_build" > /dev/null

if [ ! -e go ]
then
  GOLANG_RELEASE="go${GOLANG_VERSION}.linux-amd64.tar.gz"
  GOLANG_URL="https://dl.google.com/go/$GOLANG_RELEASE"
  echo "GO was not detected, downloading '$GOLANG_RELEASE' ($GOLANG_URL) ..."
  curl $GOLANG_URL -LO
  tar -zxf $GOLANG_RELEASE || exit $?
  pushd go > /dev/null
  patch -p1 -r . < ../../gost/go.patch
  popd > /dev/null
fi

export PATH=$PWD/go/bin:$PATH
export GOROOT=$PWD/go
echo "Current GO version: $(go version|grep -oP "\d.*")"

if [ ! -e gost ]
then
  GOST_RELEASE="gost_v${GOST_VERSION}.tar.gz"
  GOST_URL="https://github.com/go-gost/gost/archive/refs/tags/v${GOST_VERSION}.tar.gz"
  echo "GOST was not detected, downloading '$GOST_RELEASE' ($GOST_URL) ..."
  curl $GOST_URL -Lo $GOST_RELEASE
  tar -zxf $GOST_RELEASE || exit $?
  mv gost-* gost
  pushd gost > /dev/null
  patch -p1 -r . < ../../gost/gost.patch
  popd > /dev/null
fi
cp -r ../gost/ssand_helper gost
echo "GOST version: v$GOST_VERSION"

IS_NDK_MISSING=true
if [ ! -z "$ANDROID_NDK_ROOT" ]
then
  IS_NDK_MISSING=$([[ ! -d $ANDROID_NDK_ROOT || -z "$(find $ANDROID_NDK_ROOT -iname "*clang" -print -quit)" ]] && echo true || echo false);
fi

if $IS_NDK_MISSING && [ -d ~+/ndk ]
then
  ANDROID_NDK_ROOT=$(find ~+/ndk -maxdepth 1 -mindepth 1 -type d -print -quit);
  IS_NDK_MISSING=$([[ ! -d $ANDROID_NDK_ROOT || -z "$(find $ANDROID_NDK_ROOT -iname "*clang" -print -quit)" ]] && echo true || echo false);
fi

if $IS_NDK_MISSING
then
  NDK_BASE="android-ndk-${NDK_VERSION_IF_MISSING}"
  NDK_RELEASE="${NDK_BASE}-linux.zip"
  NDK_URL="https://dl.google.com/android/repository/$NDK_RELEASE"
  echo "No NDK could be detected, downloading '$NDK_RELEASE' ($NDK_URL) ..."
  curl $NDK_URL -L -O
  unzip $NDK_RELEASE > /dev/null || exit $?
  pushd $NDK_BASE > /dev/null
  export ANDROID_NDK_ROOT=$PWD
  popd > /dev/null
fi
echo "Android NDK root: $ANDROID_NDK_ROOT"

pushd gost > /dev/null

src="./cmd/gost";
latest_mod=$(find $src -mindepth 1 -type f -printf '%T@\n' | sort -k1,1nr | head -1);

echo "Building native GO modules"
echo " + Started: $(date)"

start=$SECONDS

#output="../../app/src/main/jniLibs/armeabi-v7a/libgost-plugin.so";
#GOARCH_="arm"
#CC_=$(find $ANDROID_NDK_ROOT -iname "*armv7a-linux-androideabi21-clang" -print -quit);
#[[ ! -z "$CC_" && (! -f $output || $(stat -c %Y $output) < $latest_mod) ]] \
#|| (echo " + Skipping build for '$GOARCH_'" && exit 1) \
#&& echo " + Building for '$GOARCH_' ..." \
#&& CC=$CC_ GOOS="android" GOARCH=$GOARCH_ CGO_ENABLED="1" go build -buildvcs=false -ldflags "-s -w" -a -o $output $src;

#output="../../app/src/main/jniLibs/arm64-v8a/libgost-plugin.so";
#GOARCH_="arm64"
#CC_=$(find $ANDROID_NDK_ROOT -iname "*aarch64-linux-android21-clang" -print -quit);
#[[ ! -z "$CC_" && (! -f $output || $(stat -c %Y $output) < $latest_mod) ]] \
#|| (echo " + Skipping build for '$GOARCH_'" && exit 1) \
#&& echo " + Building for '$GOARCH_' ..." \
#&& CC=$CC_ GOOS="android" GOARCH=$GOARCH_ CGO_ENABLED="1" go build -buildvcs=false -ldflags "-s -w" -a -o $output $src;

output="../../app/src/main/jniLibs/x86/libgost-plugin.so";
GOARCH_="386"
CC_=$(find $ANDROID_NDK_ROOT -iname "*i686-linux-android21-clang" -print -quit);
[[ ! -z "$CC_" && (! -f $output || $(stat -c %Y $output) < $latest_mod) ]] \
|| (echo " + Skipping build for '$GOARCH_'" && exit 1) \
&& echo " + Building for '$GOARCH_' ..." \
&& CC=$CC_ GOOS="android" GOARCH=$GOARCH_ CGO_ENABLED="1" go build -buildvcs=false -ldflags "-s -w" -a -o $output $src;

#output="../../app/src/main/jniLibs/x86_64/libgost-plugin.so";
#GOARCH_="amd64"
#CC_=$(find $ANDROID_NDK_ROOT -iname "*x86_64-linux-android21-clang" -print -quit);
#[[ ! -z "$CC_" && (! -f $output || $(stat -c %Y $output) < $latest_mod) ]] \
#|| (echo " + Skipping build for '$GOARCH_'" && exit 1) \
#&& echo " + Building for '$GOARCH_' ..." \
#&& CC=$CC_ GOOS="android" GOARCH=$GOARCH_ CGO_ENABLED="1" go build -buildvcs=false -ldflags "-s -w" -a -o $output $src;

duration=$(( $SECONDS - $start ))
echo " + Finished: $(date) [Took $duration seconds]"

exit 0;
