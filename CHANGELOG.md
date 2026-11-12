# Wijzigingen

## Niet uitgebracht - reparaties na test op Toon 2 (firmware 6.3.31)

- Service crashte direct na installatie via de TSC Store met `ENOENT: uv_cwd`,
  omdat de werkmap van het TSC-hulpscript niet meer bestond. De service wisselt
  nu eerst naar de eigen thuismap.
- Ontbrekende ICU-gegevens (`icudt76l.dat`) toegevoegd. Zonder dit bestand
  stopte Node na ruim een minuut met `DateTimePatternGeneratorCache ... out of
  memory`.
- Matterbridge zocht `apps/frontend/package.json` in de app-map en stopte met
  `ENOENT`. De service legt nu een koppeling naar `node_modules/matterbridge/apps`.
- De service start Matterbridge nu met de vaste koppelcode en discriminator die
  bij de QR-code in de app horen. Voorheen koos Matterbridge een willekeurige
  code, waardoor de getoonde code en QR-code niet werkten.
- Setpoint van de Toon-thermostaat werd in tienden van graden verstuurd, terwijl
  Toon honderdsten verwacht: 20 °C instellen zette de Toon op 2 °C. Nu in
  honderdsten en afgerond op 0,5 °C.
- De Toon-thermostaat wordt als verwarmingsthermostaat gepubliceerd in plaats
  van als verwarm/koel/auto-thermostaat. Een koel-setpoint of automodus uit de
  controller kon anders het verwarmingssetpoint overschrijven.
- Kiest een controller toch "uit", dan springt de weergave terug naar verwarmen
  in plaats van blijvend "uit" te tonen terwijl de Toon doorverwarmt.

## 0.2.1 - 2026-08-24

- Toon-thermostaat als Matter-thermostaat toegevoegd.
- Selecteerbaar overzicht voor ondersteunde ComfortHub-apparaten toegevoegd.
- Elektrisch vermogen als Matter Electrical Sensor toegevoegd.
- Matter-koppelcode en QR-code op Toon toegevoegd.
- Automatische, lokale TSC-installatie van de ARMv7-service toegevoegd.
- Privacyveilige Store-screenshots en releasecontroles toegevoegd.
