#!/usr/bin/env bash

BASE_DIR=$(dirname $0)

GEOIP_COUNTRIES_ZIP="${BASE_DIR}/output/geoip_countries.zip"
GEOIP_COUNTRIES="${BASE_DIR}/output/geoip_countries"

COUNTRIES="${BASE_DIR}/output/countries"
CONTINENTS="${BASE_DIR}/output/continents"

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--out|--countries)        # Output directory of subnets
            COUNTRIES="$2"
            shift
            shift
            ;;
        --continents)        # Output directory of subnets
            CONTINENTS="$2"
            shift
            shift
            ;;
        --license)        # Your MaxMind license key
            MAXMIND_LICENSE="$2"
            shift
            shift
            ;;
        *)   # Call a "show_help" function to display a synopsis, then exit.
            echo "./generate.sh --license MAXMIND_LICENSE --out /etc/haproxy/geoip2"
            echo ""
            echo "--out          Output directory for subnets"
            echo "--license      A MaxMind.com license key. Get it from maxmind.com -> My Account -> My License Key"
            exit 1
            ;;
    esac
done

mkdir -p "output" "$COUNTRIES" "$CONTINENTS"

if [ -z "$MAXMIND_LICENSE" ]; then
    echo "MaxMind license key must be set via --liecense parameter. See --help for more.";
    exit 1;
fi

# make sure the zip file exists and is recent enough to use
if ! find "$GEOIP_COUNTRIES_ZIP" -mtime -7 2>/dev/null; then
    # remove it if it exists
    rm -f "$GEOIP_COUNTRIES_ZIP"

    # download a new copy
    echo "Downloading https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country-CSV&license_key=xxxxx&suffix=zipGeoLite2-Country-CSV..."

    # abort the script if the download failed
    if ! wget -q -O "$GEOIP_COUNTRIES_ZIP" "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country-CSV&license_key=$MAXMIND_LICENSE&suffix=zip"; then
        echo "Error downloading file"
        exit 1
    fi
fi

unzip -qq -o $GEOIP_COUNTRIES_ZIP

rm -rf $GEOIP_COUNTRIES
mv GeoLite2-Country-CSV_* $GEOIP_COUNTRIES

find "$COUNTRIES"/*.txt -nowarn -delete # delete old entries

echo "Generating files:"

# generate countries/COUNTRYCODE.txt files and fill it with subnets
# generate continents/CONTINENTCODE.txt files and fill it with subnets
while IFS="," read -r geoname_id _locale_code continent_code _continent_name country_iso_code _country_name _is_in_european_union
do
    if [ ! "$country_iso_code" ]; then
        continue
    fi

    if [ "$country_iso_code" = 'country_iso_code' ]; then
        continue
    fi

    # IPv4
    awk -F, -v geoname="$geoname_id" \
        '$2 == geoname { print $1 }' \
        "${GEOIP_COUNTRIES}/GeoLite2-Country-Blocks-IPv4.csv" | \
        tee -a "${COUNTRIES}/${country_iso_code}.txt" >> "${CONTINENTS}/${continent_code}.txt"
    echo "Country ${country_iso_code} in ${continent_code} done."

done < "$GEOIP_COUNTRIES/GeoLite2-Country-Locations-en.csv"

echo "Done."

exit 0
