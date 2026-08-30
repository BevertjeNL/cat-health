# CatHealth stabiliteits- en settingsplan

## Doel

CatHealth betrouwbaarder maken zonder de bewuste single-file-PWA-architectuur
te vervangen. De belangrijkste kwaliteitsgrenzen zijn:

- geen verlies of verdubbeling van medische logs bij offline gebruik;
- geen vermenging van lokale state tussen accounts of huisdieren;
- één gevalideerde toegangspoort voor instellingen;
- voorspelbare refreshes bij account- en huisdierwissels;
- regressietests voor de kritieke state- en synchronisatiestromen.

## Doelarchitectuur

```text
UI-formulieren
    |
    v
gevalideerde settings- en mutatielaag
    |                         |
    v                         v
Neon Data API           accountgebonden IndexedDB
    |                    cache + outbox + syncfouten
    v                         |
Postgres/RLS <---------------+
```

Iedere instelling krijgt expliciet een scope:

| Scope | Voorbeelden | Opslag |
| --- | --- | --- |
| device | weergavestijl vóór login | lokale settingsregistry |
| user | taal, actief huisdier | accountgebonden settingsregistry |
| pet | bewaakte bloedmarkers, herinneringsstatus | huisdiergebonden settingsregistry |
| domain | gewichtsherinnering, streefgewicht | Postgres `pets` |

## Fasen

### 1. Veilige offline synchronisatie

- cache- en outboxrecords namespacen met account-ID;
- alleen records van de actieve gebruiker synchroniseren;
- bij uitloggen waarschuwen voor wachtende wijzigingen;
- afgekeurde mutaties bewaren als herstelbare syncfout;
- inserts voorzien van een stabiele `client_mutation_id`.

### 2. Centrale settingsregistry

- definities met sleutel, scope, standaardwaarde en validator;
- versienummer en migratiepad voor bestaande `localStorage`-waarden;
- `watchMarkers` per huisdier en herinneringsonderdrukking per account/huisdier;
- ongeldige waarden veilig terugzetten naar de standaardwaarde.

### 3. Racevrije state

- refreshgeneratie en vastgelegde `petId` per laadronde;
- verouderde responses negeren;
- `refreshing` altijd via `finally` herstellen;
- zichtbare laatste-sync- en foutstatus.

### 4. Integriteitsregels

- databasechecks voor positieve gewichten, hoeveelheden en termijnen;
- geldige min/max-streefgewichten;
- dezelfde validatieregels in formulier en database;
- alleen idempotente migraties toevoegen.

### 5. Test- en PWA-versteviging

- contracttests voor settingsscopes en outboxrecords;
- regressietests voor accountwissel, retry en huisdierwissel;
- kritieke CDN-runtime lokaal beschikbaar maken voor een koude offline start;
- gecontroleerde updateflow met een zichtbare updatebeschikbaarheid.

## Belangrijkste trade-offs

- De single-file-opzet blijft eenvoudig te deployen, maar vraagt extra discipline
  rond centrale helpers en tests.
- Lokale medische data maakt offline gebruik mogelijk, maar vereist strikte
  accountscoping en een duidelijke logout-lifecycle.
- Een extra mutation-ID kost één kolom en index per offline tabel, maar maakt
  retries aantoonbaar veilig.

## Wanneer heroverwegen

Splits de frontend pas op wanneer meerdere ontwikkelaars gelijktijdig aan
`index.html` werken, afzonderlijke modules zelfstandig releases nodig hebben,
of de regressietests niet meer praktisch tegen het single-file-document kunnen
worden uitgevoerd.
