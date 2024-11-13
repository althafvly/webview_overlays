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
    $OVERLAY_TOP/overlay/build_overlays.sh  $OUT/
    echo "Copying stuff" >> $GLOG
    cp $OVERLAY_TOP/toybox-arm64 $OUT/toybox >> $GLOG
    echo "Generating addon.d script" >> $GLOG
    test -d $OUT/system/addon.d || mkdir -p $OUT/system/addon.d
    cp -f addond_head $OUT/system/addon.d
    cp -f addond_tail $OUT/system/addon.d
    echo "Writing build props..."
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
