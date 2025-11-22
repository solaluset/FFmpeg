FFMPEG_INSTALL="$(pwd)/ffmpeg"


build_opus() {
  local OPUS_PREFIX="$(pwd)/opus"
  local OPUS_PKG_CONFIG="$OPUS_PREFIX/lib/pkgconfig"

  curl -L -o opus.tar.gz https://downloads.xiph.org/releases/opus/opus-1.4.tar.gz
  tar xf opus.tar.gz
  rm opus.tar.gz
  mv opus* opus-src
  cd opus-src

  cmake . -A Win32
  cmake --build . --config Release
  cmake --install . --prefix "$OPUS_PREFIX"

  cd ..
  rm -r opus-src

  # generated prefix is not correct, replace it
  local orig_prefix=$(sed -n "s|^prefix=||p" "$OPUS_PKG_CONFIG/opus.pc")
  sed -i "s|$orig_prefix|$OPUS_PREFIX|g" "$OPUS_PKG_CONFIG/opus.pc"

  export PKG_CONFIG_PATH="$OPUS_PKG_CONFIG"
}


check_cfg() {
  local output="$1"
  shift

  while [ $# != 0 ]; do
    local pattern="^$1\\s+([^\$]+)\$"
    local value=$(sed -E -n "s/$pattern/\\1/p" <<< "$output")

    if [ "$value" = "" -o "$value" = "no" ]; then
      return 1
    fi

    shift
  done

  return 0
}


build_ffmpeg() {
  local cfg_out="$(
    ./configure --prefix="$FFMPEG_INSTALL" \
      --toolchain=msvc --arch=x86_32 --enable-static \
      --extra-ldflags="-NODEFAULTLIB:MSVCRT" --pkg-config-flags="--static" \
      --enable-gpl --enable-version3 --extra-version="SL_$(date '+%s')" \
      --disable-programs --enable-ffmpeg --enable-libopus \
      --disable-debug --disable-doc
  )"
  local result=$?
  echo "$cfg_out"
  if [ $result != 0 ] \
    || ! check_cfg "$cfg_out" "network support" "threading support" \
    || ! grep -q '^config:x86:x86_32:generic:win32:' ffbuild/config.fate; then
    echo "Configuration failed."
    cat ffbuild/config.fate ffbuild/config.log
    exit 1
  fi
  make -j $(nproc)
  make install
}


export PATH="$(cat path_diff):$PATH"
build_opus
build_ffmpeg
zip -j ffmpeg.zip "$FFMPEG_INSTALL/bin/ffmpeg.exe"
