#!/bin/bash

[ -z "$GOLANG_VERSION" ] && GOLANG_VERSION="1.25.0"
[ -z "$GOST_VERSION" ] && GOST_VERSION="3.2.4"
[ -z "$ANDROID_NDK_ROOT" ] && NDK_VERSION="r26c"

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
  # GOLANG_DOWNLOAD="Go.v${GOLANG_VERSION}.Linux.x64_p30download.com.tar.gz"
  GOLANG_DOWNLOAD=$GOLANG_RELEASE
  # GOLANG_URL="https://pdn.sharezilla.ir/d/software/${GOLANG_DOWNLOAD}"
  GOLANG_URL="https://go.dev/dl/${GOLANG_RELEASE}"
  echo "GO was not detected"
  [ -f $GOLANG_DOWNLOAD ] || echo "Downloading '$GOLANG_RELEASE' ($GOLANG_URL) ..."
  [ -f $GOLANG_DOWNLOAD ] || curl $GOLANG_URL -LO
  [ -f $GOLANG_DOWNLOAD ] || mv -n $GOLANG_DOWNLOAD $GOLANG_RELEASE
  echo "Extracting $GOLANG_DOWNLOAD ..."
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
  echo "GOST was not detected"
  [ -f $GOST_RELEASE ] || echo "Downloading '$GOST_RELEASE' ($GOST_URL) ..."
  [ -f $GOST_RELEASE ] || curl $GOST_URL -Lo $GOST_RELEASE
  echo "Extracting $GOST_RELEASE ..."
  tar -zxf $GOST_RELEASE || exit $?
  mv gost-* gost
fi

latest_local_mod=$(find "../gost" -mindepth 1 -type f -printf '%T@\n' | sort -k1,1nr | head -1);
latest_gost_release_mod=$(find "gost" -mindepth 1 -type f -printf '%T@\n' | sort -k1,1nr | head -1);
if [[ !(-d "gost/gost_helper") || ( $latest_local_mod > $latest_gost_release_mod ) ]] 
then
  pushd gost > /dev/null
  patch --no-backup-if-mismatch -tlNp1 -r /tmp/rejects.txt < ../../gost/gost.patch || echo "GOST patching failed (already patched?)"
  cp -r ../../gost/gost_helper .
  echo " + GOST patched"
  popd > /dev/null
fi
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
  NDK_BASE="android-ndk-${NDK_VERSION}"
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
latest_mod=$(find $src "gost_helper" -mindepth 1 -type f -printf '%T@\n' | sort -k1,1nr | head -1) || exit $?;

echo "Building native GO modules"
echo " + Started: $(date)"

start=$SECONDS

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

duration=$(( $SECONDS - $start ))
echo " + Finished: $(date) [Took $duration seconds]"

exit 0;
