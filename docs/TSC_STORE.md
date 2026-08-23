# Publiceren in de TSC-testcatalogus

De huidige TSC-helper downloadt app-tags uitsluitend uit
`ToonSoftwareCollective/<folder>`. Voor deze app moet daarom vóór samenvoegen
van de catalogus-PR exact `ToonSoftwareCollective/matterbridge` bestaan met tag
`0.2.1` op de gecontroleerde releasecommit.

Veilige publicatievolgorde:

1. Draai `./scripts/controleer.sh` en controleer dat Git alleen bedoelde bron,
   vendor-archieven en privacyveilige screenshots bevat.
2. Publiceer de gecontroleerde commit en tag eerst in de persoonlijke
   bronrepository; laat TSC die repository daarna importeren of overdragen.
3. Maak de catalogusbranch uitsluitend vanaf de actuele `upstream/test`; merge
   of rebase niet op `main` en gebruik geen force-push.
4. Voeg het fragment uit `ToonRepo-entry.xml` en de drie bestanden uit
   `docs/images` toe aan de catalogus.
5. Merge pas nadat de organisatie-repository en exacte tag via een anonieme
   download zijn gecontroleerd.

De repository bevat bewust geen persistent `home`, selectieconfiguratie,
pairingcode, IP-adres of logbestand. De installer controleert de vendor-
checksums en downloadt tijdens installatie niets.
