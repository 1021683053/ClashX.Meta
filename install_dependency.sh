#!/bin/bash
set -e

if [ ! -d "clash.meta" ]; then
    echo "Downloading mihomo (arm64 only)..."
    mkdir clash.meta
    # arm64 only
    curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest \
     | grep "browser_download_url.*mihomo-darwin-arm64-v.*gz" \
     | cut -d '"' -f 4 \
     | xargs curl -L -o clash.meta/mihomo-darwin-arm64.gz

    echo "Download complete."
fi

echo "Unzip core files"
cd clash.meta
ls
gzip -d *.gz
echo "Rename arm64 core"
mv mihomo-darwin-arm64* com.metacubex.ClashX.ProxyConfigHelper.meta
chmod +x com.metacubex.ClashX.ProxyConfigHelper.meta

echo "Update meta core md5 to code"
sed -i '' "s/WOSHIZIDONGSHENGCHENGDEA/$(md5 -q com.metacubex.ClashX.ProxyConfigHelper.meta)/g" ../ClashX/AppDelegate.swift
sed -n '20p' ../ClashX/AppDelegate.swift

echo "Gzip Universal core"
gzip com.metacubex.ClashX.ProxyConfigHelper.meta
cp com.metacubex.ClashX.ProxyConfigHelper.meta.gz ../ClashX/Resources/
cd ..

echo "delete old files"
rm -f ./ClashX/Resources/country.mmdb
rm -f ./ClashX/Resources/geosite.dat
rm -f ./ClashX/Resources/geoip.dat
rm -rf ./ClashX/Resources/dashboard
rm -f GeoLite2-Country.*
echo "install mmdb"
curl -LO https://github.com/MetaCubeX/meta-rules-dat/raw/release/country.mmdb
gzip country.mmdb
mv country.mmdb.gz ./ClashX/Resources/country.mmdb.gz
echo "install geosite"
curl -LO https://github.com/MetaCubeX/meta-rules-dat/raw/release/geosite.dat
gzip geosite.dat
mv geosite.dat.gz ./ClashX/Resources/geosite.dat.gz
echo "install geoip"
curl -LO https://github.com/MetaCubeX/meta-rules-dat/raw/release/geoip.dat
gzip geoip.dat
mv geoip.dat.gz ./ClashX/Resources/geoip.dat.gz


echo "install zashboard"
cd ClashX/Resources
mkdir -p dashboard
cd dashboard
curl -L -o dist-no-fonts.zip https://github.com/Zephyruso/zashboard/releases/latest/download/dist-no-fonts.zip
unzip -q dist-no-fonts.zip
mv dist zashboard
rm -f dist-no-fonts.zip