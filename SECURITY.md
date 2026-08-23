# Beveiliging en privacy

Meld kwetsbaarheden niet in een openbaar issue. Neem privé contact op met de
repository-eigenaar via het beveiligingskanaal van GitHub.

De app werkt lokaal. Selecties staan in `/mnt/data/tsc/matter-bridge.json` en de
Matter-fabric staat onder `/mnt/data/tsc/matter-service/home`; beide horen nooit
in Git, screenshots of supportlogs. De testrelease gebruikt de openbare
Matterbridge-testcode. Gebruik hem alleen op een vertrouwd lokaal netwerk en
rond koppelen direct af.

De service opent op de Toon alleen de lokale UDP-poorten voor Matter (5540) en
mDNS (5353), inclusief noodzakelijke IPv6-neighbour-discovery. De installer
downloadt geen uitvoerbare code tijdens installatie en controleert de SHA-256
van beide meegeleverde vendor-archieven.
