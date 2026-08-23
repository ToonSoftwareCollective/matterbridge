# Matter Bridge voor Toon 2

Experimentele Toon-app met lokale Matter-bridge voor Google Home en andere
Matter-controllers. In één scrolbaar overzicht kies je welke ondersteunde
apparaten worden gedeeld. Versie 0.2.1 ondersteunt de Toon-thermostaat,
elektrisch vermogen en volledig bekende thermostaten uit de ComfortHub App Bus.

De keuze wordt meteen en blijvend opgeslagen in:

```text
/mnt/data/tsc/matter-bridge.json
```

Het selectiebestand gebruikt schema `nl.toon.matter-bridge/preferences-v1` en
bevat geen adressen, sleutels of wachtwoorden. Een apparaat blijft geselecteerd
als het tijdelijk offline is of als de volgorde in ComfortHub verandert. Een
niet meer aanwezig apparaat verdwijnt automatisch uit het overzicht en uit de
bridge zodra de service de bijgewerkte selectie verwerkt.

De energiemeter deelt het actuele netto elektrische vermogen via het standaard
Matter Electrical Sensor-apparaattype. Afname is positief en teruglevering
negatief. Gasdoorstroming staat alleen als aanvullende lokale informatie in het
Toon-overzicht, omdat deze Matter-versie geen passend ondersteund gasmetertype
heeft.

## Statuscontract voor de bridge-service

De app leest optioneel
`/var/volatile/tmp/toon-matter-bridge/status.json`. De Matter-service publiceert
daarin `running`, `commissioned`, `message`, `pairing_code`, `qr_image` en de
actuele `energy`-status. Zonder dat bestand meldt de app eerlijk dat de service
nog niet actief is; de selectievinkjes blijven wel bruikbaar.

## Installatie via de TSC Store

Bij de eerste start vraagt de QML-app via `external-matterbridge` aan het
bestaande TSC-hulpscript om `matterbridge.sh` uit te voeren. De installer zet de
meegeleverde ARMv7 Node-runtime en Matterbridge-service onder
`/mnt/data/tsc/matter-service`, maakt een bootkoppeling en start de service.
Er wordt tijdens installatie niets van internet gedownload.

De eerste installatie heeft ongeveer 450 MB vrije ruimte op `/mnt/data` nodig.
Matter werkt lokaal op het thuisnetwerk; Google Home toont daarom terecht een
waarschuwing dat dit geen gecertificeerd commercieel Matter-product is.

Zie [docs/INSTALLATIE.md](docs/INSTALLATIE.md) voor installatie, update en
verwijdering. Zie [docs/TSC_STORE.md](docs/TSC_STORE.md) voor publicatie.

## Controleren en verpakken

```sh
./scripts/controleer.sh
./scripts/pakket.sh
```

Het pakket komt in `dist/matterbridge-0.2.1.tar.gz` en bevat de map
`matterbridge`, bestemd voor `/qmf/qml/apps/` op Toon 2.

## Privacy

De repository bevat geen Matter-fabric, Google Home-koppeling, lokaal
IP-adres, Toon-instellingen of logbestanden. Pairingcodes worden uitsluitend op
de Toon zelf getoond. De testrelease gebruikt de openbare Matterbridge-
testcode; dit is geen persoonlijk geheim. De screenshots gebruiken fictieve
data en schermen de koppelcode af.
