# Software van derden

Deze testrelease bevat twee versievaste vendor-archieven zodat installatie op
de verouderde Toon 2 zonder compiler of download tijdens installatie werkt.

- Node.js 22.23.2 voor Alpine Linux/ARMv7, Node.js-licentie. Bron en
  licentietekst: https://github.com/nodejs/node/tree/v22.23.2
- Matterbridge 3.10.4, Apache License 2.0.
  Bron: https://github.com/Luligu/matterbridge/tree/v3.10.4
- ICU-gegevens `icudt76l.dat` uit het Alpine-pakket `icu-data-en` 76.1-r1
  (Alpine 3.22, armv7), Unicode License v3 (ICU). Bron:
  https://pkgs.alpinelinux.org/package/v3.22/main/armv7/icu-data-en
- De npm-afhankelijkheden en hun versies staan in `package-lock.json` in het
  Matterbridge-archief. Meegeleverde licentiebestanden blijven in het archief.
- De Alpine-pakketmetadata, inclusief licentievelden, blijft in
  `lib/apk/db/installed` in het Node-runtimearchief.

De lokale `matterbridge-toon`-plugin en Toon-QML vallen onder de MIT-licentie in
de hoofdmap. De checksums staan vast in `scripts/controleer.sh` en
`matterbridge.sh`.
