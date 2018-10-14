#!/usr/bin/env bash

# This build script bases on these tools:
#
# - /sdk-path/build-tools/28.0.3
#    - aapt2
#    - d8
#    - zipalign
# - sdk/platforms/android-28
#    - android.jar
# - /jdk1.8.0_171.jdk/Contents/Home/bin/javac
#    - javac
#    - jarsigner
# - some other *nix common tools (regular shell commands)
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
    ### link
    linkInputs=$(find ${compileTargetArchiveUnzip} -type f | tr '\r\n' ' ')
    aapt2 link -o ${linkTarget} -I ${androidJar} --manifest ${manifest} --java ${r} ${linkInputs}
    echo -e "aapt2 generated \r\n  - R.java      : ${r} \r\n  - res package : ${linkTarget}"


## 3. build java classes
    classesOutput=${buildDir}/classes
    mainClassesInput=./app/src/main/java/me/xx2bab/manualbuilding/*.java
    rDotJava=${r}/me/xx2bab/manualbuilding/R.java
    mkdir ${classesOutput}
    ## .java -> .classes
    javac -bootclasspath ${androidJar} -d ${classesOutput} ${mainClassesInput} ${rDotJava}
    ## .classes -> .dex
    dexOutput=${buildDir}/dex
    mkdir ${dexOutput}
    d8 ${classesOutput}/me/xx2bab/manualbuilding/*.class --lib ${androidJar} --output ${dexOutput}


## 4. build apk
    tools=${sdk}/tools/lib
    unsignedApk=${buildDir}/manual-build-unsigned.apk
    signedApk=${buildDir}/manual-build-signed.apk
    zipAlignedSignedApk=${buildDir}/manual-build-aligned-signed.apk
    ## build apk
    java -cp $(echo ${tools}/*.jar | tr ' ' ':') com.android.sdklib.build.ApkBuilderMain ${unsignedApk} -u -v -z ${linkTarget} -f ${dexOutput}/classes.dex
    ## signature
    jarsigner -verbose -keystore ./debug.keystore -storepass android -keypass android -signedjar ${signedApk} ${unsignedApk} androiddebugkey
    ## zipalign
    zaTool=$(dirname $(which aapt2))/zipalign
    ${zaTool} -v 4 ${signedApk} ${zipAlignedSignedApk}
