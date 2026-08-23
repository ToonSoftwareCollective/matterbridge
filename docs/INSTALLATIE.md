# Installatie en beheer

## Via de TSC-testcatalogus

1. Installeer Matter Bridge op een Toon 2 met minimaal 450 MB vrije ruimte op
   `/mnt/data`.
2. Open de app eenmaal. De app vraagt automatisch de lokale service-installatie
   aan via het bestaande TSC-hulpscript.
3. Wacht maximaal twee minuten. Kies daarna alleen de apparaten die je wilt
   delen en scan de QR-code met Google Home.

De service start voortaan tijdens het opstarten via
`/etc/rc5.d/S99toon-matter`. Een update behoudt selecties en de bestaande
Matter-fabric.

## Ondersteund in 0.2.1

- Toon-thermostaat als Matter-thermostaat.
- Volledig bekende ComfortHub-thermostaten met vaste ID.
- Actueel elektrisch afname- of terugleververmogen als Matter-sensor.

Gasdoorstroming is alleen lokale informatie in het Toon-overzicht. Ventilatie
kan zichtbaar zijn wanneer ComfortHub die volledig beschrijft, maar wordt in
deze testversie nog niet als Matter-endpoint gepubliceerd.

## Verwijderen

De TSC-verwijderactie roept `matterbridge.sh uninstall` aan. Dit stopt de
service en verwijdert ook de lokale Matter-fabric. Daarna is opnieuw koppelen
nodig als de app later opnieuw wordt geïnstalleerd.
