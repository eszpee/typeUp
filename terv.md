# Terv: gépelésgyakorló oldal (`index.html`)

## Kontextus

A `feladatok/Gépírás feladatok.xml` egy régi gépírás-oktató program („Bexpész”) feladatgyűjteménye
(szerkezete: `docs/feladatfajl-formatum.md`). Ehhez készül egy modern, egyfájlos, böngészőben futó
gyakorlóoldal, backend nélkül. A felhasználó betölti az XML-t, kiválaszt egy feladatot, és a minta
alapján begépeli; a program színezi a haladást, számolja a hibákat és az időt, a végén eredményt mutat.
Első körben TDD nélkül készül, a tesztelés Chrome DevTools MCP-vel történik.

## Egyeztetett döntések

- **Egy fájl:** `/Users/eszpee/projects/typeUp/index.html`, beágyazott CSS és JS, külső függőség nélkül.
- **Adatforrás:** a felhasználó minden indításkor maga tölti be az XML-t (fájlválasztó és húzás). A böngészőben
  (localStorage) csak az aranyak és a vidracsalád tárolódik, lásd lent.
- **Feladatválasztó:** lenyitható fa az XML-hierarchia szerint, hierarchikus számozással (pl. `1.15.2`),
  keresőmezővel, amely címre és számra is szűr.
- **Gépelési mód:** csak Copy (fent a minta, lent a beviteli mező). A `RecommendedTypingMode` és a `CanEdit` értékét figyelmen kívül hagyjuk; a backspace mindenhol működik.
- **Hibánál:** a karakter bekerül, pirosra vált, a felhasználó halad tovább vagy visszatöröl.
- **Hibaszámlálás:** minden hibás leütés számít, akkor is, ha később kijavítja.
- **Enter és szóköz:** felcserélhetők, bármelyik elfogadott a másik helyén (az `IsEnterRequiredOnLineEnds` beállítást nem vesszük figyelembe).
- **Idő:** az első leütéssel indul, és az utolsó karakter beírásakor áll meg, akkor is, ha maradt benne hiba.
- **Dolgozatok:** ugyanúgy működnek, mint a többi feladat (az `IsTaskVisibleBeforeStart` értékét nem használjuk).
- **Gépelés közben látszik:** futó idő, hibák száma és egy vékony haladásjelző csík.
- **Eredményképernyő:** idő, hibák száma, leütés/perc, pontosság %, a legtöbbet tévesztett karakterek;
  gombok: „Következő feladat”, „Újra”, „Vissza a listához”.
- **Kabala:** egy SVG-vidra. Gépelés közben figyel, hibánál ijedten néz, befejezéskor hátraszaltót ugrik.
- **Kinézet:** letisztult, kevés színnel, csak világos téma. Nincs billentyűzet-segéd.

## Felépítés (`index.html`)

### Képernyők (egy oldalon, a nézetek között váltunk)

1. **Betöltés:** fájlválasztó gomb és húzási terület, a vidra köszön.
2. **Feladatválasztó:** fa, keresőmező és egy „Másik fájl” gomb.
3. **Gépelés:** fejléc (szám + cím, vissza gomb), statisztika-sáv (idő, hibák, haladás), a minta
   (fent), a `<textarea>` (lent), a vidra az egyik sarokban.
4. **Eredmény:** a mérőszámok, a vidra szaltója és a három gomb.

### JS modulok (egy `<script>`-en belül, függvényekre bontva)

- **`parseCollection(xmlText)`:** `DOMParser`-rel feldolgozza az XML-t, a BOM-ot eltávolítja.
  `Map<id, item>`-et és a gyökérelemek listáját adja vissza. Gyökérelem az, amelyikre semmi nem hivatkozik.
  A gyökérelemek a fájlbeli sorrendben jönnek, a gyerekek az `ItemLink` sorrendjében. A hierarchikus
  számokat itt számolja ki. Az üres szövegű feladatot (234) letiltottként jelöli meg.
- **`renderTree(filter)`:** a fa HTML-je `<details>`/`<summary>` elemekkel. Szűréskor a találatok
  őseit is megjeleníti és kinyitja.
- **Gépelési állapot:** `target`, `typed`, `errors`, `missCounts{char:n}`, `keystrokes`, `startTime`.
  - `matches(expected, typed)`: pontos egyezés, vagy Enter és szóköz egymás helyett.
  - Az `input` eseménynél összehasonlítjuk az új értéket az előzővel. Ha a hossz nőtt, minden új
    karaktert kiértékelünk: hibánál `errors++` és `missCounts[expected]++`. Ha csökkent, az törlés,
    a számlálók maradnak. A `keystrokes` minden bevitt karakternél nő.
  - A mező `maxlength`-e a minta hossza. A beillesztés le van tiltva, a kurzor mindig a végére ugrik
    (kattintás és nyílbillentyűk esetén is), hogy a szöveg közepébe ne lehessen írni.
  - Az első bevitt karakter indítja az időt, egy `setInterval` frissíti a kijelzést. Ha a beírt
    szöveg eléri a minta hosszát, az idő megáll, és jön az eredményképernyő.
- **Minta megjelenítése:** minden karakter egy `<span>`. Állapotok: `done` (visszafogott szín),
  `wrong` (piros háttér vagy szín; a hibás szóköz is látsszon), `current` (aláhúzás vagy villogó
  kurzor), `todo`. A sortörést egy halvány `↵` jel és egy tényleges sortörés mutatja. Csak a
  megváltozott spanokat frissítjük. A minta dobozában automatikusan görgetünk az aktuális karakterhez.
- **Eredmény:**
  - leütés/perc = `keystrokes / perc`, ahol a törlés nem számít leütésnek;
  - pontosság = `(keystrokes − errors) / keystrokes`;
  - a legtöbbet tévesztett karakterek: a 5 leggyakoribb, a szóköz és a sortörés olvasható néven.
- **Vidra:** inline SVG, CSS-osztályokkal: `idle` (pislog), `typing` (figyel), `oops` (hibánál rövid
  animáció), `flip` (360°-os hátraszaltó ugrással, `@keyframes`).
- **Következő feladat:** a fa bejárási sorrendjében a következő, nem üres feladat.

### Stílus

Semleges háttér (törtfehér), egy kiemelő szín (a vidra barnája vagy egy csendes türkiz), piros csak
a hibákhoz. Rendszerbetűtípus, a mintához monospace. Tágas térközök és lekerekített kártyák.
Asztali gépre készül, de keskeny ablakban se törjön szét.

## Aranyak és vidracsalád (#4)

- **Sor:** a sortörésig tartó rész, a sortöréssel együtt. A 80 karakternél hosszabb sort szóhatáron kb.
  60 karakteres darabokra vágjuk (`goldLines`), így az egysoros próza is rendszeresen ad aranyat, és az
  eredmény nem függ az ablak szélességétől.
- **Hibátlan (szigorú):** a sorban egyetlen hibás leütés sem volt, a kijavított hiba is számít.
- **Kifizetés:** a sor utolsó karakterének (a sorvégi Enternek) leütésekor azonnal jár 1 arany, és az
  arany Befejezésnél, Újrakezdésnél vagy kilépésnél is megmarad. Egy sor feladatonként egyszer fizet,
  visszatörlés és újragépelés után sem jár érte újra arany. Ugyanaz a feladat újra megoldva ismét ad aranyat.
- **Mintafeladat:** nem ad aranyat, a számláló nem is látszik.
- **Gépelés közben:** a sor végéből egy érme repül a vidrához, a vidra elrakja (`stash` póz), a statisztika-sáv
  „Arany” számlálója (a teljes pénztárca) ekkor nő. Az eredményképernyőn „+N arany” látszik.
- **Vidracsalád nézet:** a főoldalról és a feladatlistáról a „Vidracsalád” gombbal érhető el, a „Vissza” oda visz,
  ahonnan jöttünk. Fent egy SVG-jelenet a vidrával és a megvett tárgyakkal, alatta a bolt.
- **Bolt:** tárgyanként 3 szint (vásárlás + 2 fejlesztés), egyre drágábban, a magasabb szint többet/szebbet ad.
  A függő tárgyhoz a feltétel tárgyból legalább egy szint kell.

  | Tárgy | 1. | 2. | 3. | Függőség |
  |---|---|---|---|---|
  | Kavicsok | 1 | 2 | 3 | – |
  | Virágok | 1 | 2 | 3 | – |
  | Nádas | 2 | 3 | 5 | – |
  | Tó | 2 | 4 | 8 | – |
  | Hal | 5 | 10 | 20 | Tó |
  | Fa | 8 | 17 | 33 | – |
  | Csónak | 13 | 25 | 50 | Tó |
  | Vidravár | 17 | 33 | 67 | Nádas |
  | Új vidra | 13 | 21 | 33 | Vidravár |
  | Égbolt | 25 | 50 | 100 | – |

- **Tárolás:** localStorage, `typeUp.v1` kulcs, `{ gold, items: { id: szint } }`, egyetlen közös pénztárca.
  A felhasználónkénti szétválasztás a #8 (Felhasználókezelés) feladata.
- **Nullázás:** a családnézet alján kétlépéses gomb; a megerősítés kiírja, hogy az aranyakat és a vidracsaládot is törli.

## Ellenőrzés (Chrome DevTools MCP)

1. `new_page` a `file:///Users/eszpee/projects/typeUp/index.html` oldalra, `take_screenshot`.
2. `upload_file` a fájlválasztóba (`feladatok/Gépírás feladatok.xml`). A fának 16 gyökérelemet kell
   mutatnia, a keresésnek („vessző”, „1.15”) szűrnie kell.
3. Az 1.1-es feladat megnyitása. `type_text` a helyes szöveggel, majd `take_snapshot` vagy
   `evaluate_script`: a karakterek `done` állapotban, a számláló 0 hibát mutat.
4. Hibás karakter beírása: piros jelölés, a hibaszám 1. Backspace (`press_key`) és javítás után
   a jelölés eltűnik, a hibaszám 1 marad.
5. Sorvégen az Enter és a szóköz is elfogadott, és szóköz helyén az Enter is.
6. Rövid feladat végiggépelése (pl. „vessző”, 215 karakter, `evaluate_script`-tel a textarea
   feltöltése és `input` esemény): az idő megáll, megjelenik az eredményképernyő, a vidra szaltót ugrik.
   A „Következő feladat” a következő fa-elemre lép.
7. `list_console_messages`: nincs hiba. Beillesztés-kísérlet: nem kerül be semmi.
8. Egysoros, hosszú prózafeladatnál (pl. 147) a minta dobozának görgetése követi a kurzort.
