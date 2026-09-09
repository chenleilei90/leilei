#!/usr/bin/env bash
set -euo pipefail

FFMPEG_VERSION="6.1.1"
PREFIX="${GITHUB_WORKSPACE}/.ffmpeg-prefix"
SRC="${RUNNER_TEMP}/ffmpeg-build-src"
OUT="${GITHUB_WORKSPACE}/dist"
PKG_NAME="ffmpeg-6.1.1-nvenc-linux-x86_64"
PKG_DIR="${OUT}/${PKG_NAME}"
JOBS="$(nproc)"

export PATH="${PREFIX}/bin:${PATH}"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PREFIX}/share/pkgconfig"
export CFLAGS="-O2 -fPIC -I${PREFIX}/include"
export CXXFLAGS="-O2 -fPIC -I${PREFIX}/include"
export CPPFLAGS="-I${PREFIX}/include"
export LDFLAGS="-L${PREFIX}/lib"

rm -rf "${PREFIX}" "${SRC}" "${OUT}"
mkdir -p "${PREFIX}" "${SRC}" "${PKG_DIR}"

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  build-essential autoconf automake libtool pkg-config cmake ninja-build meson \
  nasm yasm git curl wget ca-certificates xz-utils bzip2 unzip python3 perl texinfo \
  libc6-dev libnuma-dev

cd "${SRC}"

echo "===== zlib 1.3.1 ====="
curl -L --retry 5 -o zlib.tar.gz https://zlib.net/fossils/zlib-1.3.1.tar.gz
tar xf zlib.tar.gz
cd zlib-1.3.1
./configure --prefix="${PREFIX}" --static
make -j"${JOBS}"
make install
cd "${SRC}"

echo "===== OpenSSL 3.0.13 ====="
git clone --depth 1 --branch openssl-3.0.13 https://github.com/openssl/openssl.git openssl
cd openssl
./Configure linux-x86_64 no-shared no-tests --prefix="${PREFIX}" --libdir=lib
make -j"${JOBS}"
make install_sw
cd "${SRC}"

echo "===== nv-codec-headers n12.1.14.0 ====="
git clone --depth 1 --branch n12.1.14.0 https://github.com/FFmpeg/nv-codec-headers.git
make -C nv-codec-headers -j"${JOBS}"
make -C nv-codec-headers install PREFIX="${PREFIX}"

echo "===== x264 ====="
git clone --depth 1 --branch stable https://code.videolan.org/videolan/x264.git
cd x264
./configure --prefix="${PREFIX}" --bindir="${PREFIX}/bin" --enable-static --disable-cli --enable-pic
make -j"${JOBS}"
make install
cd "${SRC}"

echo "===== x265 3.5 ====="
curl -L --retry 5 -o x265.tar.gz https://bitbucket.org/multicoreware/x265_git/get/3.5.tar.gz
mkdir x265
tar xf x265.tar.gz -C x265 --strip-components=1
cmake -S x265/source -B x265/build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DENABLE_SHARED=OFF \
  -DENABLE_CLI=OFF \
  -DENABLE_PIC=ON
cmake --build x265/build -j"${JOBS}"
cmake --install x265/build

echo "===== libvpx 1.13.1 ====="
git clone --depth 1 --branch v1.13.1 https://chromium.googlesource.com/webm/libvpx
cd libvpx
./configure --prefix="${PREFIX}" \
  --disable-shared --enable-static --enable-pic \
  --disable-examples --disable-tools --disable-docs --disable-unit-tests \
  --enable-vp8 --enable-vp9 --enable-vp9-highbitdepth --as=nasm
make -j"${JOBS}"
make install
cd "${SRC}"

echo "===== libaom 3.8.0 ====="
git clone --depth 1 --branch v3.8.0 https://aomedia.googlesource.com/aom
cmake -S aom -B aom-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_SHARED_LIBS=OFF \
  -DENABLE_TESTS=OFF -DENABLE_EXAMPLES=OFF -DENABLE_TOOLS=OFF -DENABLE_DOCS=OFF \
  -DCONFIG_PIC=1
cmake --build aom-build -j"${JOBS}"
cmake --install aom-build

echo "===== dav1d 1.3.0 ====="
git clone --depth 1 --branch 1.3.0 https://code.videolan.org/videolan/dav1d.git
meson setup dav1d/build dav1d \
  --prefix="${PREFIX}" --libdir=lib --buildtype=release --default-library=static \
  -Denable_tools=false -Denable_tests=false
ninja -C dav1d/build -j"${JOBS}"
ninja -C dav1d/build install

echo "===== SVT-AV1 1.8.0 ====="
git clone --depth 1 --branch v1.8.0 https://github.com/AOMediaCodec/SVT-AV1.git svt-av1
cmake -S svt-av1 -B svt-av1/build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_SHARED_LIBS=OFF -DBUILD_APPS=OFF
cmake --build svt-av1/build -j"${JOBS}"
cmake --install svt-av1/build

echo "===== libogg 1.3.5 ====="
curl -L --retry 5 -o libogg.tar.xz https://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.xz
tar xf libogg.tar.xz
cd libogg-1.3.5
./configure --prefix="${PREFIX}" --disable-shared --enable-static
make -j"${JOBS}"
make install
cd "${SRC}"

echo "===== libvorbis 1.3.7 ====="
curl -L --retry 5 -o libvorbis.tar.xz https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.xz
tar xf libvorbis.tar.xz
cd libvorbis-1.3.7
./configure --prefix="${PREFIX}" --disable-shared --enable-static
make -j"${JOBS}"
make install
cd "${SRC}"

echo "===== opus 1.4 ====="
curl -L --retry 5 -o opus.tar.gz https://downloads.xiph.org/releases/opus/opus-1.4.tar.gz
tar xf opus.tar.gz
cd opus-1.4
./configure --prefix="${PREFIX}" --disable-shared --enable-static
make -j"${JOBS}"
make install
cd "${SRC}"

echo "===== lame 3.100 ====="
curl -L --retry 5 -o lame.tar.gz https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
tar xf lame.tar.gz
cd lame-3.100
./configure --prefix="${PREFIX}" --disable-shared --enable-static --disable-frontend
make -j"${JOBS}"
make install
cd "${SRC}"

echo "===== libwebp 1.3.2 ====="
git clone --depth 1 --branch v1.3.2 https://github.com/webmproject/libwebp.git
cmake -S libwebp -B libwebp/build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_SHARED_LIBS=OFF \
  -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF \
  -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF \
  -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_BUILD_EXTRAS=OFF
cmake --build libwebp/build -j"${JOBS}"
cmake --install libwebp/build

echo "===== OpenJPEG 2.5.0 ====="
git clone --depth 1 --branch v2.5.0 https://github.com/uclouvain/openjpeg.git
cmake -S openjpeg -B openjpeg/build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_SHARED_LIBS=OFF -DBUILD_CODEC=OFF
cmake --build openjpeg/build -j"${JOBS}"
cmake --install openjpeg/build

echo "===== soxr 0.1.3 ====="
git clone --depth 1 --branch 0.1.3 https://github.com/chirlu/soxr.git
cmake -S soxr -B soxr/build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF
cmake --build soxr/build -j"${JOBS}"
cmake --install soxr/build

echo "===== zimg 3.0.5 ====="
git clone --depth 1 --branch release-3.0.5 https://github.com/sekrit-twc/zimg.git
cd zimg
./autogen.sh
./configure --prefix="${PREFIX}" --disable-shared --enable-static
make -j"${JOBS}"
make install
cd "${SRC}"

echo "===== expat 2.5.0 ====="
curl -L --retry 5 -o expat.tar.xz https://github.com/libexpat/libexpat/releases/download/R_2_5_0/expat-2.5.0.tar.xz
tar xf expat.tar.xz
cmake -S expat-2.5.0 -B expat-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_SHARED_LIBS=OFF -DEXPAT_BUILD_TOOLS=OFF -DEXPAT_BUILD_EXAMPLES=OFF -DEXPAT_BUILD_TESTS=OFF
cmake --build expat-build -j"${JOBS}"
cmake --install expat-build

echo "===== FreeType 2.13.2 ====="
curl -L --retry 5 -o freetype.tar.xz https://download.savannah.gnu.org/releases/freetype/freetype-2.13.2.tar.xz
tar xf freetype.tar.xz
cd freetype-2.13.2
./configure --prefix="${PREFIX}" --disable-shared --enable-static \
  --without-harfbuzz --without-brotli --without-bzip2 --without-png
make -j"${JOBS}"
make install
cd "${SRC}"

echo "===== FriBidi 1.0.13 ====="
git clone --depth 1 --branch v1.0.13 https://github.com/fribidi/fribidi.git
meson setup fribidi/build fribidi \
  --prefix="${PREFIX}" --libdir=lib --buildtype=release --default-library=static
ninja -C fribidi/build -j"${JOBS}"
ninja -C fribidi/build install

echo "===== HarfBuzz 8.2.1 ====="
git clone --depth 1 --branch 8.2.1 https://github.com/harfbuzz/harfbuzz.git
meson setup harfbuzz/build harfbuzz \
  --prefix="${PREFIX}" --libdir=lib --buildtype=release --default-library=static \
  -Dtests=disabled -Ddocs=disabled
ninja -C harfbuzz/build -j"${JOBS}"
ninja -C harfbuzz/build install

echo "===== Fontconfig 2.15.0 ====="
curl -L --retry 5 -o fontconfig.tar.xz https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.15.0.tar.xz
tar xf fontconfig.tar.xz
cd fontconfig-2.15.0
./configure --prefix="${PREFIX}" --disable-shared --enable-static --disable-docs --disable-nls
make -j"${JOBS}"
make install
cd "${SRC}"

echo "===== libass 0.17.1 ====="
git clone --depth 1 --branch 0.17.1 https://github.com/libass/libass.git
cd libass
./autogen.sh
./configure --prefix="${PREFIX}" --disable-shared --enable-static
make -j"${JOBS}"
make install
cd "${SRC}"

echo "===== FFmpeg ${FFMPEG_VERSION} ====="
curl -L --retry 5 -o ffmpeg.tar.xz "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
tar xf ffmpeg.tar.xz
cd "ffmpeg-${FFMPEG_VERSION}"

export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PREFIX}/share/pkgconfig"

./configure \
  --prefix="${PREFIX}" \
  --bindir="${PREFIX}/bin" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I${PREFIX}/include -fPIC" \
  --extra-ldflags="-L${PREFIX}/lib -static-libgcc -static-libstdc++" \
  --extra-libs="-lpthread -lm -ldl" \
  --arch=x86_64 \
  --enable-static --disable-shared \
  --disable-debug --disable-doc --disable-ffplay \
  --enable-gpl \
  --enable-openssl \
  --enable-libaom \
  --enable-libass \
  --enable-libdav1d \
  --enable-libfontconfig \
  --enable-libfreetype \
  --enable-libfribidi \
  --enable-libharfbuzz \
  --enable-libmp3lame \
  --enable-libopenjpeg \
  --enable-libopus \
  --enable-libsoxr \
  --enable-libsvtav1 \
  --enable-libvorbis \
  --enable-libvpx \
  --enable-libwebp \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libzimg \
  --enable-ffnvcodec \
  --enable-nvenc

make -j"${JOBS}"
make install

echo "===== Validation ====="
"${PREFIX}/bin/ffmpeg" -hide_banner -version | tee "${OUT}/version.txt"
"${PREFIX}/bin/ffmpeg" -hide_banner -buildconf | tee "${OUT}/buildconf.txt"
"${PREFIX}/bin/ffmpeg" -hide_banner -encoders | tee "${OUT}/encoders.txt"
"${PREFIX}/bin/ffmpeg" -hide_banner -decoders | tee "${OUT}/decoders.txt"

grep -q "ffmpeg version 6.1.1" "${OUT}/version.txt"
grep -q "h264_nvenc" "${OUT}/encoders.txt"
grep -q "hevc_nvenc" "${OUT}/encoders.txt"
grep -q "libx264" "${OUT}/encoders.txt"
grep -q "libx265" "${OUT}/encoders.txt"
grep -q "libvpx" "${OUT}/encoders.txt"
grep -q "libaom" "${OUT}/encoders.txt"
grep -q "libsvtav1" "${OUT}/encoders.txt"
grep -q "libmp3lame" "${OUT}/encoders.txt"
grep -q "libopus" "${OUT}/encoders.txt"

ldd "${PREFIX}/bin/ffmpeg" | tee "${OUT}/ldd.txt" || true
readelf -d "${PREFIX}/bin/ffmpeg" | grep NEEDED | tee "${OUT}/needed.txt" || true

if grep -Eiq 'lib(x264|x265|vpx|aom|dav1d|SvtAv1|mp3lame|opus|vorbis|webp|openjp2|soxr|zimg|ass|freetype|fribidi|harfbuzz|fontconfig)\.so' "${OUT}/ldd.txt"; then
  echo "ERROR: codec/subtitle library was dynamically linked"
  exit 1
fi

cp "${PREFIX}/bin/ffmpeg" "${PKG_DIR}/"
cp "${PREFIX}/bin/ffprobe" "${PKG_DIR}/"
cp "${OUT}/version.txt" "${PKG_DIR}/"
cp "${OUT}/buildconf.txt" "${PKG_DIR}/"
cp "${OUT}/encoders.txt" "${PKG_DIR}/"
cp "${OUT}/decoders.txt" "${PKG_DIR}/"
cp "${OUT}/ldd.txt" "${PKG_DIR}/"
cp "${OUT}/needed.txt" "${PKG_DIR}/"

cat > "${PKG_DIR}/README.txt" <<'EOF'
FFmpeg 6.1.1 Linux x86_64 NVENC build

核心目标：
- FFmpeg 6.1.1
- h264_nvenc
- hevc_nvenc
- libx264 / libx265
- libvpx / libaom / libdav1d / libsvtav1
- libmp3lame / libopus / libvorbis
- libass / freetype / fribidi / harfbuzz / fontconfig
- libwebp / libopenjpeg / libsoxr / libzimg
- 上述codec/字幕处理库静态链接进ffmpeg
- NVIDIA驱动库由目标宿主机运行时提供

注意：
NVENC编码器在“ffmpeg -encoders”中可见并不需要构建机有GPU。
真正执行NVENC编码时，目标机器必须安装可用的NVIDIA驱动。

验证：
  ./ffmpeg -version
  ./ffmpeg -encoders | grep nvenc
  ldd ./ffmpeg
EOF

cd "${OUT}"
tar -cJf "${PKG_NAME}.tar.xz" "${PKG_NAME}"
sha256sum "${PKG_NAME}.tar.xz" > "${PKG_NAME}.tar.xz.sha256"

echo "===== Result ====="
ls -lh "${PKG_NAME}.tar.xz" "${PKG_NAME}.tar.xz.sha256"
cat "${PKG_NAME}.tar.xz.sha256"
