#!/bin/bash
# (c) Joey Rizzoli, 2015
# (c) Paul Keith, 2017
# (c) althafvly, 2024
# Released under GPL v2 License

export OVERLAY_TOP=$(realpath .)
OUT=$OVERLAY_TOP/out
BUILD=$OVERLAY_TOP/build
METAINF=$BUILD/meta
export GLOG=$OVERLAY_TOP/log
ADDOND=$OVERLAY_TOP/addond.sh

SIGNAPK=$OVERLAY_TOP/build/sign/signapk.jar
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$OVERLAY_TOP/build/sign

ZIP_KEY_PK8=$OVERLAY_TOP/build/sign/testkey.pk8
ZIP_KEY_PEM=$OVERLAY_TOP/build/sign/testkey.x509.pem

APKTOOL=$OVERLAY_TOP/build/apktool/apktool_2.8.1.jar
APKSIGNER=$OVERLAY_TOP/build/sign/apksigner.jar

##
# functions
#
function clean() {
    echo "Cleaning up..."
    rm -r $OUT/
    rm /tmp/$BUILDZIP
    return $?
}

function failed() {
    echo "Build failed, check $GLOG"
    exit 1
}

function create() {
    test -f $GLOG && rm -f $GLOG
    echo "Starting Overlays compilation" > $GLOG
    echo "ARCH= " >> $GLOG
    echo "OS= $(uname -s -r)" >> $GLOG
    echo "NAME= $(whoami) at $(uname -n)" >> $GLOG
    test -d $OUT || mkdir $OUT;
    test -d $OUT/ || mkdir -p $OUT/
    test -d $OUT/system || mkdir -p $OUT/system
    echo "Build directories are now ready" >> $GLOG
    echo "Compiling RROs"
    build_overlay
    echo "Copying stuff" >> $GLOG
    cp $OVERLAY_TOP/toybox-arm64 $OUT/toybox >> $GLOG
    echo "Generating addon.d script" >> $GLOG
    test -d $OUT/system/addon.d || mkdir -p $OUT/system/addon.d
    cp $OVERLAY_TOP/push.sh $OUT/ >> $GLOG
    addon
    echo "Writing build props..."
}

function addon() {
    echo "Generating addon.d file"
    cd $OUT/system
    cat $OVERLAY_TOP/addond_head > addon.d/30-webview.sh
    for f in `find . ! -path "./addon.d/*" -type f`; do
      line=$(echo "$f" | sed 's/\.\///')
      echo "$line" >> addon.d/30-webview.sh
    done
    cat $OVERLAY_TOP/addond_tail >> addon.d/30-webview.sh
    cd $OVERLAY_TOP
}

function zipit() {
    BUILDZIP=WebViewOverlays.zip
    echo "Importing installation scripts..."
    test -d $OUT/META-INF || mkdir $OUT/META-INF;
    cp -r $METAINF/* $OUT/META-INF/ && echo "Meta copied" >> $GLOG
    echo "Creating package..."
    cd $OUT/
    zip -r /tmp/$BUILDZIP . >> $GLOG
    rm -rf $OUT/tmp >> $GLOG
    cd $OVERLAY_TOP
    if [ -f /tmp/$BUILDZIP ]; then
        echo "Signing zip..."
        java -Xmx2048m -jar $SIGNAPK -w $ZIP_KEY_PEM $ZIP_KEY_PK8 /tmp/$BUILDZIP $BUILDZIP >> $GLOG
    else
        echo "Couldn't zip files!"
        echo "Couldn't find unsigned zip file, aborting" >> $GLOG
        return 1
    fi
}

function build_overlay() {
    cd "$OVERLAY_TOP/overlay"

    OVERLAYS=$(for dir in $(ls -d */); do echo ${dir%%/}; done)

    for OVERLAY in $OVERLAYS; do
        PARTITION=$(grep -Eo "\w+_specific: true" $OVERLAY/Android.bp | sed "s/_specific.*$//")
        OVERLAY_TARGET_DIR="$OUT/system/$PARTITION/overlay/"
        OVERLAY_TARGET="$OVERLAY_TARGET_DIR/$OVERLAY.apk"
        test -d $OVERLAY_TARGET_DIR || mkdir -p $OVERLAY_TARGET_DIR
        java -Xmx2048m -jar $APKTOOL b $OVERLAY --use-aapt2 >> $GLOG 2>&1
        touch -amt 200901010000.00 \
            $OVERLAY/build/apk/resources.arsc \
            $OVERLAY/build/apk/AndroidManifest.xml
        zip -j $OVERLAY_TARGET -n .arsc \
            $OVERLAY/build/apk/resources.arsc \
            $OVERLAY/build/apk/AndroidManifest.xml >> $GLOG 2>&1
        java -Xmx2048m -jar $APKSIGNER sign --key $ZIP_KEY_PK8 --cert $ZIP_KEY_PEM $OVERLAY_TARGET
        rm $OVERLAY_TARGET.idsig
    done

    cd $OVERLAY_TOP
}

function getmd5() {
    if [ -x $(which md5sum) ]; then
        echo "md5sum is installed, getting md5..." >> $GLOG
        echo "Getting md5sum..."
        GMD5=$(md5sum $BUILDZIP)
        echo -e "$GMD5" > $BUILDZIP.md5sum
        echo "md5 exported at $BUILDZIP.md5sum"
        return 0
    else
        echo "md5sum is not installed, aborting" >> $GLOG
        return 1
    fi
}

if [ -x $(which realpath) ]; then
    echo "Realpath found!" >> $GLOG
else
    GAPPS_TOP=$(cd . && pwd) # some darwin love
    echo "No realpath found!" >> $GLOG
fi

for func in create zipit getmd5 clean; do
    $func
    ret=$?
    if [ "$ret" == 0 ]; then
        continue
    else
        failed
    fi
done

echo "Done!" >> $GLOG
echo "Build completed: $GMD5"
exit 0
