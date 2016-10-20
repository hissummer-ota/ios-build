#!/bin/bash

toenv=$1
datestamp=$(date +"%Y-%m-%d_%T")
echo ${BUILD_NUMBER}


buildSchemes=(
"heika-backup"
"heika-develop"
"heika-test"
"heika-ucloud"
"heika-train"
"heika-develop-perform"
"heika-online"
)

buildConfigurations=(
"HeikaBackup_Release"
"HeikaDevelop_Release"
"HeikaTest_Release"
"HeikaUCloud_Release"
"HeikaTrain_Release"
"HeikaDevelopPerform_Release"
"HeikaOnline_Release"
)

function defEnv()
{
buildScheme=$1
buildConfiguration=$2
}

case "${toenv}" in
        38)
             defEnv ${buildSchemes[2]} ${buildConfigurations[2]}
            ;;
        113)
             defEnv ${buildSchemes[1]} ${buildConfigurations[1]}
            ;;
        ucloud)
             defEnv ${buildSchemes[3]} ${buildConfigurations[3]}
            ;;
        backup)
             defEnv ${buildSchemes[0]} ${buildConfigurations[0]}
            ;;
        develop-perform)
             defEnv ${buildSchemes[5]} ${buildConfigurations[5]}
            ;;
        online)
             defEnv ${buildSchemes[6]} ${buildConfigurations[6]}
            ;;
        train)
		defEnv ${buildSchemes[4]} ${buildConfigurations[4]}
            ;;
        *)
            echo "arguments error!"
            exit 1
esac

function generatePlist()
{
#itms-services://?action=download-manifest&url=https://172.16.2.45/plist/63
echo generate plist

cat > ${WORKSPACE}/output/${buildConfiguration}_${codeBranch}_${datestamp}.xml << MYEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>items</key>
<array>
<dict>
<key>assets</key>
<array>
<dict>
<key>kind</key>
<string>software-package</string>
<key>url</key>
<string>http://172.16.2.37/jenkins/job/IOS%E6%9E%84%E5%BB%BA/${BUILD_NUMBER}/artifact/output/${buildConfiguration}_${codeBranch}_${datestamp}.ipa</string>
</dict>
</array>
<key>metadata</key>
<dict>
<key>bundle-identifier</key>
<string>com.renrendai.heika</string>
<key>bundle-version</key>
<string>1.0</string>
<key>kind</key>
<string>software</string>
<key>title</key>
<string>${buildConfiguration}_${codeBranch}_${datestamp}</string>
</dict>
</dict>
</array>
</dict>
</plist>

MYEOF


}


#clean the project
#mkdir -p ${WORKSPACE}
#rm -rf ${WORKSPACE}/*
#cp /Users/buildtest/CI/workspace/*.ipa ${WORKSPACE}/

rm -rf ${WORKSPACE}/output/*
rm -rf ${WORKSPACE}/*.root



#unlock the keychain, the default kechain for user buildtest is login.keychain. 
#how to check the keychain which used .  security list-keychains  
security unlock -p " "  ~/Library/Keychains/login.keychain
security  set-keychain-settings  -t 50000 -l "/Users/buildtest/Library/Keychains/login.keychain"


cd ${WORKSPACE}/heika/
xcodebuild clean OBJROOT=${WORKSPACE}/Obj.root SYMROOT=${WORKSPACE}/sym.root
#compile test!
echo xcodebuild -scheme "${buildScheme}" -target "heika" -configuration "${buildConfiguration}" -sdk iphoneos OBJROOT=${WORKSPACE}/Obj.root SYMROOT=${WORKSPACE}/sym.root
xcodebuild -scheme "${buildScheme}" -target "heika" -configuration "${buildConfiguration}" -sdk iphoneos OBJROOT=${WORKSPACE}/Obj.root SYMROOT=${WORKSPACE}/sym.root
#xcodebuild -scheme "${buildScheme}" -target "heika" -configuration "${buildConfiguration}" -sdk iphoneos 

#echo $?

if [ $? -ne 0 ] ; then
   exit 1;
fi

appDir=$(find "${WORKSPACE}/sym.root/" -name "heika.app"  -type d | head -n 1)

mkdir -p ${WORKSPACE}/output/

#export ipa test!
echo xcrun -sdk iphoneos PackageApplication -v "${appDir}" -o "${WORKSPACE}/output/${buildConfiguration}_${codeBranch}_${datestamp}.ipa"
xcrun -sdk iphoneos PackageApplication -v "${appDir}" -o "${WORKSPACE}/output/${buildConfiguration}_${codeBranch}_${datestamp}.ipa"
if [ $? -ne 0 ] ; then
   exit 1;
fi

#tar the sym.root files for debuging

cd ${WORKSPACE}
tar -cjvf output/sym.root.tar.bz sym.root/

#generate the plist file for the ipa
generatePlist

#generate qrcode png

/usr/local/bin/qrencode -s 8 -l M -v 3 -o ${WORKSPACE}/output/${buildConfiguration}_${codeBranch}_${datestamp}.png "itms-services://?action=download-manifest&url=https://qa.heika.com/jenkins/plist/${BUILD_NUMBER}/artifact/output/${buildConfiguration}_${codeBranch}_${datestamp}.xml"

#generate iosqrcode html output for job page.

cat > ${WORKSPACE}/output/qrcode.html <<EOF
<script>
function bright(a)
{
a.style.border ="1px solid blue";
}

function dark(a)
{
a.style.border ="0px";
}
</script>

<div style="display:inline-block;" >
<span style="margin:10px;font-size:1.3em;background-color:rgba(255,255,255,0.5);font-weight:bold;font-color:blue;"> ${buildConfiguration}_${codeBranch}_${datestamp}.ipa </span>
<br/>
<span style="margin:10px;font-size:1.3em;background-color:rgba(255,255,255,0.5);font-weight:bold;font-color:blue;"> <a href="itms-services://?action=download-manifest&url=https://qa.heika.com/jenkins/plist/${BUILD_NUMBER}/artifact/output/${buildConfiguration}_${codeBranch}_${datestamp}.xml" > ${buildConfiguration}_${codeBranch}_${datestamp}.plist </a></span>
<br/>
<img src="${BUILD_URL}artifact/output/${buildConfiguration}_${codeBranch}_${datestamp}.png"></img>
</div>
<br/>

EOF


output=$(cat ${WORKSPACE}/output/qrcode.html | tr '\n' ' ')

echo iosqrcode=$output > ${WORKSPACE}/../../shell/iosqrcode.properties

