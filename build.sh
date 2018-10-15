#!/usr/bin/env bash

# This build script bases on tools below:
#
# Android SDK:
#
# - /android-sdk-path/build-tools/28.0.3
#    - aapt2
#    - d8
#    - zipalign
#
# - /android-sdk-path/platforms/android-28
#    - android.jar
#
# - /android-sdk-path/tools/lib
#   - sdklib (ApkBuilderMain & ApkBuilder)
#   - common
#   - some other libs that provide the dependencies for sdklib and common
#
# JDK:
#
# - /jdk-path/Contents/Home/bin/
#    - java
#    - javac
#    - jarsigner
#
# *nix shell commands
#
#    - echo
#    - which
#    - rm
#    - mkdir
#    - unzip
#    - find
#    - tr
#
# please set them up before you run the script.

## 1. let's start
    echo 'start to build'
    ### mkdir build dir
    buildDir="./app/manual-build"
    echo 'clean'
    rm -rf ${buildDir}
    echo "make a build directory at ${buildDir}"
    mkdir ${buildDir}
    ### global
    sdk=$(dirname $(dirname $(dirname $(which aapt2))))
    androidJar=${sdk}/platforms/android-28/android.jar

## 2. build resources
    echo 'compile resources'
    appResDir="./app/src/main/res"
    manifest="./app/src/main/AndroidManifest.xml"
    compileTargetArchive=${buildDir}/compiledRes
    compileTargetArchiveUnzip=${buildDir}/compiledResDir
    linkTarget=${buildDir}/resources.ap_
    r=${buildDir}/r
    ### compile
    aapt2 compile -o ${compileTargetArchive} --dir ${appResDir}
    unzip -q ${compileTargetArchive} -d ${compileTargetArchiveUnzip}
    echo -e "aapt2 intermediates \r\n  - compiled resources zip archive : ${compileTargetArchive} \r\n  - unzip resources from above     : ${compileTargetArchiveUnzip} "
    ### link
    linkInputs=$(find ${compileTargetArchiveUnzip} -type f | tr '\r\n' ' ')
    aapt2 link -o ${linkTarget} -I ${androidJar} --manifest ${manifest} --java ${r} ${linkInputs}
    echo -e "aapt2 generated \r\n  - R.java      : ${r} \r\n  - res package : ${linkTarget}"


## 3. compile java classes
    echo 'compile classes'
    classesOutput=${buildDir}/classes
    mainClassesInput=./app/src/main/java/me/xx2bab/manualbuilding/*.java
    rDotJava=${r}/me/xx2bab/manualbuilding/R.java
    mkdir ${classesOutput}
    ## .java -> .classes
    javac -bootclasspath ${androidJar} -d ${classesOutput} ${mainClassesInput} ${rDotJava}
    echo "javac generated ${classesOutput}"
    ## .classes -> .dex
    dexOutput=${buildDir}/dex
    mkdir ${dexOutput}
    d8 ${classesOutput}/me/xx2bab/manualbuilding/*.class --lib ${androidJar} --output ${dexOutput}
    echo "d8 generated ${classesOutput}"


## 4. build apk
    tools=${sdk}/tools/lib
    unsignedApk=${buildDir}/manual-build-unsigned.apk
    signedApk=${buildDir}/manual-build-signed.apk
    zipAlignedSignedApk=${buildDir}/manual-build-aligned-signed.apk
    ## build apk
    java -cp $(echo ${tools}/*.jar | tr ' ' ':') com.android.sdklib.build.ApkBuilderMain ${unsignedApk} -u -v -z ${linkTarget} -f ${dexOutput}/classes.dex
    echo "building apk by ApkBuilderMain"
    ## signature
    jarsigner -keystore ./debug.keystore -storepass android -keypass android -signedjar ${signedApk} ${unsignedApk} androiddebugkey
    echo "signed apk"
    ## zipalign
    zaTool=$(dirname $(which aapt2))/zipalign
    ${zaTool} 4 ${signedApk} ${zipAlignedSignedApk}
    echo "zipalign"
    echo "Build Completed, check the final apk at ${zipAlignedSignedApk}"
