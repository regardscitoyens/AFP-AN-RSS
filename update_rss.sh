#!/bin/bash

cd $(echo $0 | sed 's#/[^/]*$##')

rss="afp-an.rss"
rooturl="http://hosting.afp.com/clients/assembleenationale/francais/assnat/"
url="$rooturl""index.html"

mkdir -p .cache

touch "$rss" last.html
curl -sL "$url" > recent.html

if ! diff last.html recent.html | grep "^>" > /dev/null; then
    rm -f recent.html
    exit 0
fi

now=$(date -R)
date=""
title=""
link=""

function decode_entities { perl -MHTML::Entities -MEncode -nlpe '$_=encode("utf8", decode_entities($_))'; }

echo "<?xml version=\"1.0\"?>
<rss version=\"2.0\">
 <channel>
  <title>AFP AN RSS</title>
  <link>http://hosting.afp.com/clients/assembleenationale/francais/assnat/index.html</link>
  <description>Les dernières dépèches AFP liées à l'Assemblée nationale</description>
  <pubDate>$now</pubDate>
  <generator>RegardsCitoyens https://github.com/RegardsCitoyens/AFP-AN-RSS</generator>" > $rss

cat recent.html     |
  tr '\n' ' '       |
  sed 's/<table cellspacing=2 cellpading=2 border=0 width="100%">/\n/g' |
  sed 's/\s\+/ /g'  |
  grep "(AFP) - "   |
  while read line; do
    link="$rooturl"$(echo $line | sed 's/^.*href="//' | sed 's/html">.*$/html/')
    id=$(echo $link | sed 's#^.*/assnat/##')
    title=$(echo $line | sed 's/.*<a[^>]\+>//' | sed 's/<\/a>.*$//' | decode_entities)
    if ! [ -s ".cache/$id" ]; then
      curl -sL "$link" > ".cache/$id"
    fi
    content=$(grep "<font face=" ".cache/$id"   |
              sed 's/<\/\?[a-z]\+[^>]*>/ /g'    |
              decode_entities                   |
              sed 's/\s\+/ /g')
    desc=$(echo $content | sed 's/^.*heure de Paris - //i')
    day=$(echo $content | sed 's/ heure de Paris - .*$//i' | sed 's/Paris, //i' | sed 's/(AFP) - //i' |
            sed 's/^\([0-9]\+\) \([a-z]\+\) 20\([0-9]\+\) \([0-9]\+\)h\([0-9]\+\)/\2 \1 20\3 \4:\5/i' |
            sed 's/avr/apr/i' | sed 's/fév/feb/i' | sed 's/mai/may/i' | sed 's/juin/jun/i' |
            sed 's/juil/jul/i' | sed 's/août/aug/i' | sed 's/déc/dec/i')
    date=$(date -R -d "$day")
    echo "  <item>
   <title>$title</title>
   <link>$link</link>
   <description><![CDATA[$desc]]></description>
   <pubDate>$date</pubDate>
  </item>" >> $rss
    done

echo " </channel>
</rss>" >> $rss

mv -f last.html lastold.html
mv -f recent.html last.html

git commit $rss -m "update rss"
git push

