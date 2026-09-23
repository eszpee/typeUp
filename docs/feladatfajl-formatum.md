# A `Gépírás feladatok.xml` szerkezete

Forrás: `feladatok/Gépírás feladatok.xml`. Magyar nyelvű gépírás-tanfolyam feladatgyűjteménye,
az eredeti program neve a gyökérelem alapján „Bexpész” (Backspace). 169 elem: 43 mappa és
126 feladat, minden feladat szerzője (`Copyright`) Rácz Hajnalka.

## Fájlformátum

- UTF-8 BOM-mal, LF sorvégekkel, kb. 282 KB. A behúzás vegyesen tab és szóköz.
- **Lapos lista, hivatkozásokkal.** Minden elem egymás mellett áll a `<Bexpész>/<Items>` alatt,
  a hierarchiát az `<ItemLink Id="…"/>` hivatkozások adják, nem az XML-beágyazás.

```xml
<Bexpész>
  <Items>
    <Item Id ItemType="Folder" Title AutoContinueFromPrevious AutoContinueToNext EvaluateAfterFinish>
      <Items><ItemLink Id="…"/>…</Items>      <!-- a gyerekek, sorrendben -->
    </Item>
    <Item Id ItemType="Task" Title AutoContinueFromPrevious AutoContinueToNext Copyright>
      <Rules …12 attribútum…>
        <AllowedTypingModes><TypingMode>Overwrite</TypingMode><TypingMode>Copy</TypingMode></AllowedTypingModes>
      </Rules>
      <TaskText>…a begépelendő szöveg…</TaskText>
    </Item>
```

- **Azonosítók:** ritkás egész számok, blokkokban: 0–70, 100–112, 121–162, 200–234, 240–248.
  Minden elemnek legfeljebb egy szülője van, tehát a hivatkozások fát alkotnak.
- **Legfelső szint:** 16 elemnek nincs szülője; ezek a tanfolyam fő részei (mappák vagy önálló feladatok).
- A **mappák** csak hivatkozásokat, a **feladatok** csak szabályokat és szöveget tartalmaznak.
- Az elemek sorrendje a fájlban nem számít; a sorrendet a szülő `<Items>` listája határozza meg.

## Attribútumok

### Mappa (`ItemType="Folder"`)

| Attribútum | Jelentés (következtetés) |
|---|---|
| `AutoContinueFromPrevious`, `AutoContinueToNext` | Automatikus továbblépés a sorozatban. 18 mappán `True` (a leckemappák). |
| `EvaluateAfterFinish` | Összesített értékelés a mappa végén. 19 mappán `True` (leckemappák + Dolgozatok). |

### Feladat (`ItemType="Task"`) – `Rules`

Mind a 126 feladatban azonos, tehát ebben a fájlban nem hordoz információt:

- `AreTyposVisible`, `IsAllowedToResume`, `EvaluateAfterFinish`,
  `AllowedToChangeAutoJumpToNextWord`, `RecommendedAutoJumpToNextWord`: mindig `True`
- `RecommendedKeystrokeCountVisibility`: mindig `TypedAndOriginalAutomatic`
- `RecommendedKeystrokeCountFormatting`: mindig `TypedPerOriginal`
- `IsPastingToEndOfNonEditableTextAllowed`: mindig `False` (egy feladatból hiányzik, lásd lent)
- `AllowedTypingModes`: mindig Overwrite és Copy

Változó értékek:

| Attribútum | Értékek | Jelentés (következtetés) |
|---|---|---|
| `RecommendedTypingMode` | Copy 76 / Overwrite 50 | Copy: a mintát nézve máshová gépel. Overwrite: a megjelenített szövegre gépel rá. |
| `CanEdit` | False 48 / True 78 | Mind a 48 `False` soros gyakorlat. Valószínűleg azt jelenti, hogy a hibát nem lehet javítani. |
| `IsEnterRequiredOnLineEnds` | True 118 / False 8 | Kell-e Entert ütni a sorok végén. |
| `IsTaskVisibleBeforeStart` | True 118 / False 8 | Látszik-e a szöveg indítás előtt. |
| `AutoContinueToNext` / `FromPrevious` | True 118 / False 8 | Automatikus továbblépés. |

Az előforduló kombinációk:

| db | CanEdit | Mód | Enter | Látható | Tovább | Szöveg |
|---|---|---|---|---|---|---|
| 48 | False | Copy | True | True | True | többsoros |
| 26 | True | Copy | True | True | True | többsoros |
| 21 | True | Overwrite | True | True | True | többsoros |
| 21 | True | Overwrite | True | True | True | egysoros |
| 4 | True | Overwrite | False | False | False | többsoros |
| 4 | True | Overwrite | False | False | False | egysoros |
| 2 | True | Copy | True | True | True | egysoros |

A `False` értékű 8 feladat mind a **Dolgozatok** mappában van (241–248): vizsgafeladatok,
a szöveg indításig rejtett, nem kell Enter, és nincs automatikus továbblépés.

## `TaskText`

- **Soros gyakorlat:** ismétlődő betű- és szósorok (`aaasssddd…`, `dal dal dal…`), soronként Enterrel.
- **Tördelt próza:** kb. 60 karakteres sorok, elválasztással a sorvégeken (`tűn-` / `tek`).
- **Egysoros próza:** a teljes szöveg egyetlen hosszú sor (legfeljebb kb. 6400 karakter).
- Nincs sorvégi szóköz, nincs CR.
- Karakterkészlet: `\n`, szóköz, `!"%'()+,-./0-9:;=?`, angol ABC kis- és nagybetűi,
  `áéíóöőúüű ÁÉÍÓÖŐÚÜŰ`, `§`, `–`, `„ ” “`, `…`.

## A tanfolyam felépítése

```
0   Betűtanulás                              31 lecke
    1. lecke (mappa): alaptartás betűi + szóköz, alaptartás betűi + Enter
    2–14. lecke: egy-egy új betű, a címben az ujjal, pl. „r” betű (bal kéz mutatóujj)
    6., 15–31. lecke (mappa): betűgyakorlat + Szövegmásolás
    31. lecke: backspace-es másolás, jobb kéz kisujj szógyakorlatai
100 Betűkapcsolatok és szógyakorlatok a jobb és bal kéz ujjaira   (ujjanként)
121 Szövegmásolások mozdulatgyakorlattal     Előgyakorlat + Másolási gyakorlat párok
131 Szövegmásolás
134 Szógyakorlatok minden betűhöz            (önálló feladat)
135 Szövegmásolás
137 Betűkapcsolatok                          u, ü, ű, m, n, o, ó betűhöz
145 Szövegmásolás
149 Gyakori betűkapcsolatokat tartalmazó szavak  (önálló feladat)
150 Szövegmásolás mozdulatgyakorlattal
153 Szópéldák a lebegő kéztartás elsajátításához  (önálló feladat)
154 Szövegmásolás
156 Mondatgyakorlatok
159 Szövegmásolás
200 Számjegyek és írásjelek
    Számjegyek: Páratlan számok (1 5 9 3 7), Páros számok (0 4 8 2 6), összegző gyakorlásokkal
    Írásjelek: 1. rész (? ! : „” ( ) + másolások), 2. rész (+ = § % ' / ;)
240 Dolgozatok                               8 vizsgaszöveg (241–248)
```

## Hibák és furcsaságok

- **234** (*Szövegmásolás - Thomas Kyd: Spanyol tragédia (Isabella beszéde)*): üres `<TaskText>`.
- **222**: a cím kétszer szerepel egymás után („kezdő zárójel” …), a szöveg csak egy 63 karakteres sor.
- **68**: hiányzik az `IsPastingToEndOfNonEditableTextAllowed` attribútum, ezért a feldolgozónak
  opcionálisként kell kezelnie.
- **Hiányzó azonosítók:** a 41 és a 71–99 tartomány nincs használatban. A 21. lecke után egyből
  a 22. jön (42), valószínűleg egy elemet töröltek.
- **Ismétlődő címek:** több mappa neve *Szövegmásolás* vagy *Szövegmásolás mozdulatgyakorlattal*,
  ezért az elemeket csak az azonosító alapján lehet egyértelműen megkülönböztetni.
