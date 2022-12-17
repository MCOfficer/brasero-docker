# ---- gst-plugins-bad builder ----
FROM alpine:3.17 as gst-plugins-bad

RUN apk add \
    # general build tools
    curl gcc g++ \
    # needed to build mjpegtools
    make libjpeg-turbo-dev libpng-dev libdv-dev \
    # needed to build gst-plugins-bad
    meson gstreamer-dev gst-plugins-base-dev

# Build mjpegtools, which isn't in the repos
RUN curl -L https://downloads.sourceforge.net/project/mjpeg/mjpegtools/2.2.1/mjpegtools-2.2.1.tar.gz | tar -xz
WORKDIR /mjpegtools-2.2.1
RUN ./configure --prefix=/usr \
    && make DESTDIR=/install install \
    && make install

# and now gst-plugins-bad itself
WORKDIR /
RUN curl -L https://gstreamer.freedesktop.org/src/gst-plugins-bad/gst-plugins-bad-1.20.4.tar.xz | tar -xJ
RUN mkdir /gst-plugins-bad-1.20.4/build
WORKDIR /gst-plugins-bad-1.20.4/build
RUN meson ..  \
    # Optimized release build
    -Dtests=disabled -Dbuildtype=release -Db_lto=true --prefix /usr \
    # Required for mplex & mpeg2enc
    -Dgpl=enabled \
    # compile & install
    && DESTDIR=/install meson install

# ----       main image        ----
FROM jlesage/baseimage-gui:alpine-3.17-v4

# vcdimager is not in the 3.17 repos yet
RUN echo "@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && apk update

RUN add-pkg \
    # maybe these help? idk anymore
    gtk+3.0 libgudev dbus-glib libnotify jansson numactl pciutils libdvdcss librsvg lsscsi coreutils \
    # Brasero itself
    brasero dbus-x11 gvfs udisks2 \
    # Fonts
    font-noto \
    # install_app_icon.sh will need these later
    curl jq sed \
    # cdrtools dependencies
    acl libcap \
    # mjpegtools dependencies
    libjpeg libpng libdv \
    # 
    # PLUGINS:
    # 
    # rganalysis, rgvolume (for Normalization)
    gst-plugins-good \
    # avenc_mp2, avenc_ac3 (for transcode2vob, alongside mplex & mpeg2enc from self-compiled gst-plugins-bad)
    gst-libav \
    # cdrecord, genisoimage, mkisofs, readcd (patched with wrapper scripts, see /usr/local/bin)
    cdrkit \
    # toc2cue, cdrdao (for cdrdao)
    cdrdao \
    # dvd+rw-format (for dvd-rw-format), growisofs
    dvd+rw-tools \
    # dvdauthor
    dvdauthor \
    # libdvdcss.so (for dvdcss)
    libdvdcss \
    # vcdimager (patched with wrapper scripts, see /usr/local/bin)
    vcdimager@testing

# Customize the final container
ENV APP_NAME "Brasero"
RUN install_app_icon.sh "https://gitlab.gnome.org/GNOME/brasero/raw/master/data/icons/hicolor_apps_256x256_brasero.png"

# copy our various stuff
COPY --from=gst-plugins-bad /install/ /
COPY rootfs/ /

VOLUME ["/config"]