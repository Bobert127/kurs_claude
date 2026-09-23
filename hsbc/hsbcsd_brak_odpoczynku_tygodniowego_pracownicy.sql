-- =====================================================================
-- Nieprzerwany odpoczynek tygodniowy - Wersja 2 (pracownicy)
-- VERSION 3 - scalenie z hsbc_brak_odpoczynku_tygodniowego_optim.sql
-- (jedna, ostateczna wersja pliku; usunieto zduplikowany plik _optim).
-- VERSION 4 - poprawka blednego sumowania roznica_h przy wielu
-- niepowiazanych blokach dni wolnych w jednym tygodniu (patrz nizej).
--
-- Konwencja jak w hsbcsd_brak_odpoczynku_dobowego.sql:
--   * CTE 'parametry' (data_od / data_do) - jedno miejsce na daty,
--     sparametryzowane placeholderami silnika raportu TETA/Konstelacja
--     (^$DATA_OD^, ^$DATA_DO^, ^$P_DATE_FORMAT^), zaokraglone do PELNYCH
--     TYGODNI: TRUNC(..., 'IW') dla data_od, +6 dla data_do - raport
--     zawsze obejmuje pelne tygodnie (pon-nd), niezaleznie od tego, na
--     jaki dzien tygodnia wypada poczatek/koniec okresu rozliczeniowego.
--   * CTE 'pracownicy' - lista prac_id z t_prac z warunkami na osoby
--     ZATRUDNIONE w calym okresie:
--         DATA_ZATR <= data_od
--         AND (DATA_ROZW IS NULL OR DATA_ROZW >= data_do)
--   * Zrodlowe CTE ograniczone przez prac_id IN (SELECT ... FROM pracownicy).
--   * SELECT ... INTO v_* do osadzenia w silniku raportowym, ktory
--     iteruje po wierszach i mapuje kolumny na zmienne v_*.
--
-- ODPOCZYNEK Z UWZGL. DYZUROW I NADGODZIN (jak w raporcie dobowym):
--   Kazdy CIAGLY BLOK dni wolnych (>=2 dni pod rzad) to WLASNY wiersz
--   wyniku - suma_roznic_h to dlugosc NAJDLUZSZEGO ciaglego odcinka
--   odpoczynku W TYM JEDNYM oknie (nie suma po wielu blokach - jesli w
--   tym samym tygodniu jest wiecej niz jeden blok dni wolnych, kazdy
--   dostaje osobny wiersz, patrz VERSION 4 nizej). Dyzury
--   (KP_RCP_WORK_TIME_EVENTS wtet_id=18) oraz zlecone nadgodziny
--   (KP_RCP_ZLEC_NADG_PRAC) PRZERYWAJA odpoczynek - przyciete do okna,
--   dziela je na odcinki, brany jest max. CTE: okna -> aktywnosci ->
--   segmenty -> odp_agg -> pary.
--   Kolumny wyswietlane (zdarzenia_wtet_id_18, zlecone_nadgodziny) sa
--   zawezone do TEGO SAMEGO okna/bloku co obliczenia (dolaczane po
--   prac_id+d1, warunek nachodzenia z_do>k_przed AND z_od<k_po), wiec
--   pokazuja tylko aktywnosci realnie przerywajace TEN KONKRETNY blok
--   odpoczynku.
--
-- ZMIANY W VERSION 3 (najwazniejsze - poprawka bledu z V2):
--   1. valid_pairs: zamiast osobnego, NAKLADAJACEGO SIE NA SIEBIE okna
--      dla kazdej sasiadujacej pary dni (self-join / LEAD(), d1/d1+1),
--      teraz wykrywa CIAGLE BLOKI dni z TYP_DNIA IS NOT NULL (technika
--      "gaps and islands": dni_wolne.grp = dzien_mies - ROW_NUMBER()),
--      i liczy JEDNO okno na caly blok (MIN/MAX(dzien_mies) = d1/d_last).
--      Blad w V2 powodowal, ze przy bloku dluzszym niz 2 dni (np. urlop
--      obok weekendu) te same godziny odpoczynku byly liczone
--      wielokrotnie (raz na kazda sasiadujaca pare dni w bloku) i
--      sumowane w suma_roznic_h, co zawyzalo wynik nawet 10-krotnie.
--   2. okna: koniec okna liczony od d_last + 1 (dzien po calym bloku)
--      zamiast d1 + 2 (co zakladalo zawsze dokladnie 2-dniowy blok).
--   3. Jeden odczyt kalendarza (kal_all) zamiast dwoch osobnych skanow
--      NT_KP_KDR_KALENDARZE_PRAC - kalendarze i kal_base sa teraz
--      tylko filtrami na kal_all.
--   4. suma_roznic_h sformatowane przez TO_CHAR(..., 'FM999999990.00')
--      - zawsze dokladnie 2 miejsca po przecinku w wyniku raportu.
--
-- ZMIANY W VERSION 4 (poprawka bledu z V3):
--   pary_agg sumowal roznica_h (SUM) po WSZYSTKICH blokach dni wolnych
--   (par.d1), ktorych d1 wpadal w dany tydzien. Jesli w tygodniu
--   wystapily DWA niepowiazane ze soba bloki dni wolnych (np. weekend +
--   dluzszy blok typu urlop w tym samym tygodniu), ich godziny byly
--   BLEDNIE SUMOWANE, mimo ze to odrebne okresy odpoczynku - zawyzalo
--   to suma_roznic_h (np. 150h zamiast realnych ~62h dla samego
--   weekendu).
--   PIERWSZA proba poprawki (wybor JEDNEGO bloku o najwiekszej
--   roznica_h na tydzien, przez ROW_NUMBER) okazala sie rowniez bledna:
--   gdy dluzszy, NIEPRZERWANY blok (np. urlop bez zadnych dyzurow/
--   nadgodzin) mial wieksza roznica_h niz krotszy blok faktycznie
--   PRZERWANY przez zlecenie nadgodzin, wygrywal ten dluzszy - w efekcie
--   caly wiersz z rzeczywistym naruszeniem (krotszy, przerwany blok)
--   znikal z wyniku (WHERE wymaga za/na IS NOT NULL).
--   OSTATECZNA poprawka: pary_agg NIE agreguje juz blokow do jednego
--   wiersza na tydzien w zaden sposob (ani SUM, ani "zwyciezca") -
--   KAZDY blok dni wolnych (klucz: prac_id + d1) jest WLASNYM wierszem
--   wyniku, z wlasna, poprawnie dopasowana (po d1) lista zdarzen i
--   nadgodzin. nr_tygodnia to wylacznie etykieta prezentacyjna
--   ("pierwszy dzien tygodnia" / "zakres tygodnia"), nie klucz
--   agregacji - jesli w jednym tygodniu jest wiecej niz jeden blok,
--   raport pokaze dla niego wiecej niz jeden wiersz.
--
-- UWAGA: uruchomione samodzielnie jako zwykly SQL rzuci ORA-01422
-- (wiele wierszy). Ten zapis ma sens WYLACZNIE w kontekscie silnika
-- raportu, ktory obsluguje pobieranie wiersz po wierszu.
-- =====================================================================
SELECT lp,
       imie,
       nazwisko,
       nr_ew,
       nr_karty,
       jednostka_organizacyjna,
       mpk,
       stanowisko,
       okres_rozliczeniowy,
       pierwszy_dzien_okresu_rozliczeniowego,
       pierwszy_dzien_tygodnia,
       zakres_tygodnia,
       odejmowanie,
       suma_roznic_h,
       zdarzenia_wtet_id_18,
       zlecone_nadgodziny

       INTO
       V_lp,
       V_imie,
       V_nazwisko,
       V_nr_ew,
       V_nr_karty,
       V_jednostka_organizacyjna,
       V_mpk,
       V_stanowisko,
       V_okres_rozliczeniowy,
       V_p_d_okresu_rozliczeniowego,
       V_p_d_tygodnia,
       V_zakres_tygodnia,
       V_odejmowanie,
       V_suma_roznic_h,
       V_zdarzenia_wtet_id_18,
       V_zlecone_nadgodziny

FROM (
WITH
    parametry AS (
        SELECT  TRUNC(to_date('^$DATA_OD^', '^$P_DATE_FORMAT^'), 'IW')     AS data_od,
                TRUNC(to_date('^$DATA_DO^', '^$P_DATE_FORMAT^'), 'IW') + 6 AS data_do
        FROM dual
    ),
    pracownicy AS (
        SELECT /*+ MATERIALIZE */ prac.prac_id AS prac_id
        FROM t_prac prac
        CROSS JOIN parametry prm
        WHERE prac.DATA_ZATR <= prm.data_od
          AND (prac.DATA_ROZW IS NULL OR prac.DATA_ROZW >= prm.data_do)
    ),
    kal_all AS (
        SELECT /*+ MATERIALIZE */
               k.id, k.prac_id, k.dzien_mies, k.typ_dnia, k.czas_do, k.czas_od
        FROM NT_KP_KDR_KALENDARZE_PRAC k
        CROSS JOIN parametry prm
        WHERE k.DZIEN_MIES BETWEEN prm.data_od AND prm.data_do
          AND k.prac_id IN (SELECT prac_id FROM pracownicy)
    ),
    kalendarze AS (
        SELECT id, prac_id, dzien_mies
        FROM kal_all
        WHERE typ_dnia = 'W'
    ),
    prac_hr AS (
        SELECT /*+ MATERIALIZE */
               p.prac_id, p.imie, p.nazwisko, p.nr_ew, p.nr_karty,
               LEAST(NVL(p.data_rozw, prm.data_do), prm.data_do) AS data_ref,
               akt_dane.j_org(p.prac_id,
                   LEAST(NVL(p.data_rozw, prm.data_do), prm.data_do)) AS jednostka_org,
               akt_dane.mpk(p.prac_id,
                   LEAST(NVL(p.data_rozw, prm.data_do), prm.data_do)) AS mpk,
               akt_dane.stanowisko(p.prac_id,
                   LEAST(NVL(p.data_rozw, prm.data_do), prm.data_do)) AS stanowisko
        FROM t_prac p
        CROSS JOIN parametry prm
        WHERE p.prac_id IN (SELECT prac_id FROM kalendarze)
    ),
    system_pracy AS (
        SELECT ph.prac_id, b.dlugosc
        FROM prac_hr ph
        CROSS JOIN parametry prm
        JOIN KP_RCP_WORKING_TIME_SYSTEMS scz
             ON scz.code = akt_dane.work_time_system(ph.prac_id, prm.data_do)
        JOIN KP_RCP_OKRESY_BILANSU b ON b.id = scz.rcok_id
    ),
    okres AS (
        SELECT /*+ MATERIALIZE */
               k.prac_id, sp.dlugosc,
               CASE
                   WHEN sp.dlugosc = 1 THEN TRUNC(k.dzien_mies, 'MM')
                   WHEN sp.dlugosc = 3 THEN TRUNC(k.dzien_mies, 'Q')
               END AS poczatek_okresu,
               CASE
                   WHEN sp.dlugosc = 1 THEN LAST_DAY(k.dzien_mies)
                   WHEN sp.dlugosc = 3 THEN LAST_DAY(ADD_MONTHS(TRUNC(k.dzien_mies, 'Q'), 2))
               END AS koniec_okresu
        FROM kalendarze k
        JOIN system_pracy sp ON sp.prac_id = k.prac_id
        GROUP BY
               k.prac_id, sp.dlugosc,
               CASE
                   WHEN sp.dlugosc = 1 THEN TRUNC(k.dzien_mies, 'MM')
                   WHEN sp.dlugosc = 3 THEN TRUNC(k.dzien_mies, 'Q')
               END,
               CASE
                   WHEN sp.dlugosc = 1 THEN LAST_DAY(k.dzien_mies)
                   WHEN sp.dlugosc = 3 THEN LAST_DAY(ADD_MONTHS(TRUNC(k.dzien_mies, 'Q'), 2))
               END
    ),
    kal_base AS (
        SELECT /*+ MATERIALIZE */
               ka.prac_id, ka.dzien_mies, ka.typ_dnia, ka.czas_do, ka.czas_od
        FROM kal_all ka
        WHERE ka.prac_id IN (SELECT prac_id FROM prac_hr)
    ),
    dni_wolne AS (
        SELECT prac_id, dzien_mies,
               dzien_mies - ROW_NUMBER() OVER (PARTITION BY prac_id ORDER BY dzien_mies) AS grp
        FROM kal_base
        WHERE typ_dnia IS NOT NULL
    ),
    -- Blok CIAGLYCH dni wolnych (>=2 dni pod rzad) liczony JEDEN RAZ,
    -- zamiast osobnego, nakladajacego sie okna dla kazdej sasiadujacej
    -- pary dni w tym samym bloku (co powodowalo wielokrotne liczenie
    -- tych samych godzin przy blokach dluzszych niz 2 dni, np. urlop).
    valid_pairs AS (
        SELECT /*+ MATERIALIZE */
               prac_id,
               MIN(dzien_mies) AS d1,
               MAX(dzien_mies) AS d_last
        FROM dni_wolne
        GROUP BY prac_id, grp
        HAVING COUNT(*) >= 2
    ),
    zdarzenia AS (
        SELECT /*+ MATERIALIZE */
               z.prac_id,
               z.workday_date,
               TO_CHAR(z.date_time_from, 'HH24:MI') AS z_godz_od,
               TO_CHAR(z.date_time_to,   'HH24:MI') AS z_godz_do,
               z.date_time_from                      AS z_od_dt,
               z.date_time_to                        AS z_do_dt
        FROM KP_RCP_WORK_TIME_EVENTS z
        CROSS JOIN parametry prm
        WHERE z.wtet_id = 18
          AND z.prac_id     IN (SELECT prac_id FROM prac_hr)
          AND z.workday_date BETWEEN prm.data_od AND prm.data_do
    ),
    nadgodziny AS (
        SELECT /*+ MATERIALIZE */
               n.prac_id,
               n.data,
               TO_CHAR(n.godz_od, 'HH24:MI')                  AS n_godz_od,
               TO_CHAR(n.godz_do, 'HH24:MI')                  AS n_godz_do,
               TRUNC(n.data) + (n.godz_od - TRUNC(n.godz_od)) AS n_od_dt,
               TRUNC(n.data) + (n.godz_do - TRUNC(n.godz_do)) AS n_do_dt
        FROM KP_RCP_ZLEC_NADG_PRAC n
        CROSS JOIN parametry prm
        WHERE n.prac_id IN (SELECT prac_id FROM prac_hr)
          AND n.data    BETWEEN prm.data_od AND prm.data_do
    ),
    okna AS (
        SELECT vp.prac_id, vp.d1,
               TRUNC(k_przed.dzien_mies) + (k_przed.czas_do - TRUNC(k_przed.czas_do)) AS k_przed_dt,
               TRUNC(k_po.dzien_mies)    + (k_po.czas_od    - TRUNC(k_po.czas_od))    AS k_po_dt
        FROM valid_pairs vp
        LEFT JOIN kal_base k_przed
             ON  k_przed.prac_id    = vp.prac_id
             AND k_przed.dzien_mies = vp.d1 - 1
        LEFT JOIN kal_base k_po
             ON  k_po.prac_id    = vp.prac_id
             AND k_po.dzien_mies = vp.d_last + 1
    ),
    aktywnosci AS (
        SELECT o.prac_id, o.d1, o.k_przed_dt, o.k_po_dt,
               GREATEST(z.z_od_dt, o.k_przed_dt) AS a_od,
               LEAST   (z.z_do_dt, o.k_po_dt)    AS a_do
        FROM okna o
        JOIN zdarzenia z
             ON  z.prac_id  = o.prac_id
             AND z.z_do_dt  > o.k_przed_dt
             AND z.z_od_dt  < o.k_po_dt
        UNION ALL
        SELECT o.prac_id, o.d1, o.k_przed_dt, o.k_po_dt,
               GREATEST(n.n_od_dt, o.k_przed_dt) AS a_od,
               LEAST   (n.n_do_dt, o.k_po_dt)    AS a_do
        FROM okna o
        JOIN nadgodziny n
             ON  n.prac_id  = o.prac_id
             AND n.n_do_dt  > o.k_przed_dt
             AND n.n_od_dt  < o.k_po_dt
    ),
    segmenty AS (
        SELECT prac_id, d1, k_przed_dt, k_po_dt, a_od, a_do,
               (a_od - COALESCE(
                    MAX(a_do) OVER (PARTITION BY prac_id, d1 ORDER BY a_od, a_do
                                    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING),
                    k_przed_dt)) * 24 AS gap_przed_h
        FROM aktywnosci
    ),
    odp_agg AS (
        SELECT prac_id, d1,
               GREATEST(MAX(gap_przed_h), (MAX(k_po_dt) - MAX(a_do)) * 24) AS roznica_h
        FROM segmenty
        GROUP BY prac_id, d1
    ),
    pary AS (
        SELECT /*+ MATERIALIZE */
               o.prac_id, o.d1,
               o.k_przed_dt, o.k_po_dt,
               TO_CHAR(o.k_przed_dt, 'dd-mm-yyyy HH24:MI')
                   || ' - '
                   || TO_CHAR(o.k_po_dt, 'dd-mm-yyyy HH24:MI') AS odejmowanie,
               ROUND(NVL(oa.roznica_h, (o.k_po_dt - o.k_przed_dt) * 24), 2) AS roznica_h
        FROM okna o
        LEFT JOIN odp_agg oa
               ON oa.prac_id = o.prac_id
              AND oa.d1      = o.d1
        WHERE o.k_po_dt IS NOT NULL
    ),
    -- W obrebie JEDNEGO tygodnia moga wystapic DWA (lub wiecej)
    -- niepowiazane ze soba bloki dni wolnych (np. weekend + osobny,
    -- dluzszy blok typu urlop w tym samym tygodniu). Kazdy taki blok to
    -- ODREBNE okno odpoczynku z WLASNYMI, przerywajacymi je zdarzeniami
    -- (dyzury/nadgodziny) - nie wolno ich ani sumowac (SUM zawyzalo
    -- wynik), ani wybierac "zwycieskiego" bloku per tydzien (to gubilo
    -- wiersze/zdarzenia dla bloku, ktory akurat NIE mial najwiekszej
    -- roznica_h, np. gdy dluzszy, nieprzerwany blok "wygrywal" z
    -- krotszym blokiem faktycznie przerwanym przez zlecenie). Dlatego
    -- kazdy blok (pary, klucz: prac_id+d1) zostaje WLASNYM wierszem
    -- wyniku; nr_tygodnia to tylko etykieta, do ktorej "kolumny
    -- tygodnia" nalezy dany blok - zdarzenia/nadgodziny sa dolaczane
    -- PER BLOK (po d1), nie per tydzien.
    pary_agg AS (
        SELECT par.prac_id,
               par.d1,
               par.k_przed_dt,
               par.k_po_dt,
               o.poczatek_okresu,
               FLOOR((par.d1 - o.poczatek_okresu) / 7) AS nr_tygodnia,
               par.odejmowanie,
               ROUND(par.roznica_h, 2) AS suma_roznica_h
        FROM pary par
        JOIN okres o
             ON  o.prac_id  = par.prac_id
             AND par.d1    >= o.poczatek_okresu
             AND par.d1    <= o.koniec_okresu
    ),
    zdarzenia_agg AS (
        SELECT ze.prac_id,
               pa.d1,
               LISTAGG(
                   TO_CHAR(ze.workday_date, 'DD-MM-YYYY')
                       || ' ' || ze.z_godz_od || '-' || ze.z_godz_do,
                   ', '
               ) WITHIN GROUP (ORDER BY ze.workday_date) AS z_zdarzenia
        FROM zdarzenia ze
        JOIN pary_agg pa
             ON  pa.prac_id = ze.prac_id
             AND ze.z_do_dt > pa.k_przed_dt
             AND ze.z_od_dt < pa.k_po_dt
        GROUP BY ze.prac_id, pa.d1
    ),
    nadgodziny_agg AS (
        SELECT n.prac_id,
               pa.d1,
               LISTAGG(
                   TO_CHAR(n.data, 'DD-MM-YYYY')
                       || ' ' || n.n_godz_od || '-' || n.n_godz_do,
                   ', '
               ) WITHIN GROUP (ORDER BY n.data)          AS n_nadgodziny
        FROM nadgodziny n
        JOIN pary_agg pa
             ON  pa.prac_id = n.prac_id
             AND n.n_do_dt  > pa.k_przed_dt
             AND n.n_od_dt  < pa.k_po_dt
        GROUP BY n.prac_id, pa.d1
    )

SELECT
      ROW_NUMBER() OVER (ORDER BY NLSSORT(p.nazwisko, 'NLS_SORT=POLISH'), NLSSORT(p.imie,'NLS_SORT=POLISH')) AS lp,
       p.imie,
       p.nazwisko,
       p.nr_ew,
       p.nr_karty,
       p.jednostka_org AS jednostka_organizacyjna,
       p.mpk,
       p.stanowisko,
       CASE o.dlugosc
           WHEN 1 THEN '1 - miesięczny okres rozliczeniowy'
           WHEN 3 THEN '3 - miesięczny okres rozliczeniowy'
       END AS okres_rozliczeniowy,
       TO_CHAR(o.poczatek_okresu, 'DD-MM-YYYY')
           AS pierwszy_dzien_okresu_rozliczeniowego,
       TO_CHAR(o.poczatek_okresu + t.nr * 7, 'DD-MM-YYYY')
           AS pierwszy_dzien_tygodnia,
       'od ' || TO_CHAR(o.poczatek_okresu + t.nr * 7, 'DD-MM-YYYY')
           || ' do ' || TO_CHAR(
               LEAST(o.poczatek_okresu + t.nr * 7 + 6, prm.data_do),
               'DD-MM-YYYY'
           ) AS zakres_tygodnia,
       pa.odejmowanie    AS odejmowanie,
       TO_CHAR(pa.suma_roznica_h, 'FM999999990.00') AS suma_roznic_h,
       za.z_zdarzenia    AS zdarzenia_wtet_id_18,
       na.n_nadgodziny   AS zlecone_nadgodziny
FROM prac_hr p
CROSS JOIN parametry prm
JOIN okres o ON o.prac_id = p.prac_id
JOIN (
    SELECT LEVEL - 1 AS nr
    FROM DUAL
    CONNECT BY LEVEL <= 26
) t ON o.poczatek_okresu + t.nr * 7 BETWEEN prm.data_od AND prm.data_do
LEFT JOIN pary_agg pa
       ON  pa.prac_id        = p.prac_id
       AND pa.poczatek_okresu = o.poczatek_okresu
       AND pa.nr_tygodnia    = t.nr
LEFT JOIN zdarzenia_agg za
       ON  za.prac_id = pa.prac_id
       AND za.d1      = pa.d1
LEFT JOIN nadgodziny_agg na
       ON  na.prac_id = pa.prac_id
       AND na.d1      = pa.d1
WHERE  pa.odejmowanie IS NOT NULL
  AND (za.prac_id IS NOT NULL OR na.prac_id IS NOT NULL)
ORDER BY p.nazwisko, p.imie, o.poczatek_okresu, t.nr
);

-- =====================================================================
-- ZMIANY W VERSION 5 (modyfikacja obliczenia przerwy tygodniowej):
--   pary_agg wczesniej agregowal blok(i) dni wolnych do JEDNEGO wiersza
--   na tydzien - najpierw przez SUM(roznica_h) po wszystkich blokach
--   (co zawyzalo wynik przy dwoch niepowiazanych blokach w tym samym
--   tygodniu), potem przez wybor JEDNEGO "zwycieskiego" bloku o
--   najwiekszej roznica_h (co z kolei gubilo caly wiersz, gdy dluzszy,
--   nieprzerwany blok wygrywal z krotszym blokiem faktycznie
--   przerwanym przez zlecenie/dyzur - a to wlasnie ten drugi stanowil
--   realne naruszenie).
--   Ostateczne rozwiazanie: pary_agg NIE agreguje juz blokow dni
--   wolnych w zaden sposob - kazdy ciagly blok (klucz: prac_id + d1)
--   jest wlasnym wierszem wyniku, z wlasna lista zdarzen/nadgodzin
--   dolaczana PER BLOK (join po d1), a nie per tydzien. nr_tygodnia
--   pozostaje wylacznie etykieta prezentacyjna ("pierwszy dzien
--   tygodnia" / "zakres tygodnia") - jesli w jednym tygodniu wystapi
--   wiecej niz jeden blok z realnym naruszeniem, raport pokaze dla
--   niego wiecej niz jeden wiersz, zamiast gubic informacje.
-- =====================================================================
