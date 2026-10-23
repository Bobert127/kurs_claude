-- =============================================================================
-- HSBC - weryfikacja normy tygodniowej
-- Wersja 5 - nowa, zwarta wersja zapytania (raport na dzien), z tymi samymi
--            zasadami liczenia normy co w wersji 4
--
-- Zmiany wzgledem wersji 4:
--   * Podstawa zapytania zmieniona na kompaktowy wariant "na dzien raportu"
--     (jedna data referencyjna, np. 2026-09-15, zamiast zakresu dni), z
--     obsluga grup czasu pracy (gr_cz_pr / L_GR_CZ_PRACY) i jednym wierszem
--     wynikowym na pracownika/okres (bez rozbicia na tygodnie), z filtrem
--     koncowym "suma_czas_nom > 48".
--   * liczba_tygodni (dni_okresu / 7, wartosc ciagla) zastapiona przez
--     liczba_pelnych_tygodni = FLOOR(dni_okresu / 7) - tydzien = 7 dni
--     liczone od 1. dnia okresu rozliczeniowego.
--   * CZAS_NOM_z_kalendarza sumowany jest teraz wylacznie z dni
--     naleazacych do PELNYCH tygodni okresu (nie z calego okresu).
--   * suma_CZAS_nadgodzin nadal sumowana z CALEGO okresu rozliczeniowego
--     (bez zmian wzgledem wersji wyjsciowej).
--   * Jesli pracownik zostal zatrudniony w trakcie okresu rozliczeniowego
--     (p.data_zatr > poczatek_okresu), pelne tygodnie (i zwiazana z nimi
--     suma CZAS_NOM oraz mianownik normy) sa liczone od zatrudnienia -
--     przy czym siatka tygodni (granice co 7 dni) jest zawsze wyznaczana
--     od 1. dnia okresu rozliczeniowego, a nie od daty zatrudnienia.
--   * Nowe CTE: okres (dodaje liczba_pelnych_tygodni / koniec_pelnych_tygodni)
--     i okres_zatr (przesuniecie startu pelnych tygodni wzgledem data_zatr).
--   * suma_CZAS_NOM = (CZAS_NOM z pelnych tygodni + nadgodziny z calego
--     okresu) / liczba_pelnych_tygodni_pracownika.
-- =============================================================================
SELECT LP, IMIE, NAZWISKO, NR_EW, NR_KARTY, JEDNOSTKA_ORGANIZACYJNA, MPK, STANOWISKO,
       TYP_OKRESU_ROZLICZENIOWEGO, OKRES_ROZLICZENIOWY, CZAS_NOM_z_kalendarza,
       suma_CZAS_nadgodzin, suma_CZAS_NOM, komunikat
FROM (
    WITH
        pracownicy AS (
            SELECT p.prac_id
            FROM t_prac p
            WHERE p.DATA_ZATR <= to_date('2026-09-15', 'yyyy-MM-dd')
              AND (p.DATA_ROZW IS NULL OR p.DATA_ROZW >= to_date('2026-09-15', 'yyyy-MM-dd'))
        ),
        prac_hr AS (
            SELECT /*+ MATERIALIZE */
                   p.prac_id, p.imie, p.nazwisko, p.nr_ew, p.nr_karty, p.data_zatr,
                   LEAST(NVL(p.data_rozw, to_date('2026-09-15', 'yyyy-MM-dd')), to_date('2026-09-15', 'yyyy-MM-dd')) AS data_ref,
                   akt_dane.j_org(p.prac_id, LEAST(NVL(p.data_rozw, to_date('2026-09-15', 'yyyy-MM-dd')), to_date('2026-09-15', 'yyyy-MM-dd'))) AS jednostka_org,
                   akt_dane.mpk(p.prac_id, LEAST(NVL(p.data_rozw, to_date('2026-09-15', 'yyyy-MM-dd')), to_date('2026-09-15', 'yyyy-MM-dd'))) AS mpk,
                   akt_dane.stanowisko(p.prac_id, LEAST(NVL(p.data_rozw, to_date('2026-09-15', 'yyyy-MM-dd')), to_date('2026-09-15', 'yyyy-MM-dd'))) AS stanowisko
            FROM t_prac p
            WHERE p.prac_id IN (SELECT prac_id FROM pracownicy)
        ),
        system_pracy AS (
            SELECT ph.prac_id, b.dlugosc
            FROM prac_hr ph
            JOIN KP_RCP_WORKING_TIME_SYSTEMS scz ON scz.code = akt_dane.work_time_system(ph.prac_id, to_date('2026-09-15', 'yyyy-MM-dd'))
            JOIN KP_RCP_OKRESY_BILANSU b ON b.id = scz.rcok_id
        ),
        -- Tydzien = 7 dni, liczony od 1. dnia okresu rozliczeniowego.
        -- liczba_pelnych_tygodni   - ile pelnych 7-dniowych tygodni zmiesci sie w okresie
        -- koniec_pelnych_tygodni   - ostatni dzien ostatniego pelnego tygodnia
        okres AS (
            SELECT /*+ MATERIALIZE */
                   prac_id, dlugosc, poczatek_okresu, koniec_okresu,
                   FLOOR((koniec_okresu - poczatek_okresu + 1) / 7) AS liczba_pelnych_tygodni,
                   poczatek_okresu
                       + FLOOR((koniec_okresu - poczatek_okresu + 1) / 7) * 7 - 1 AS koniec_pelnych_tygodni
            FROM (
                SELECT sp.prac_id, sp.dlugosc,
                       CASE
                           WHEN sp.dlugosc = 1 THEN TRUNC(to_date('2026-09-15', 'yyyy-MM-dd'), 'MM')
                           WHEN sp.dlugosc = 3 THEN TRUNC(to_date('2026-09-15', 'yyyy-MM-dd'), 'Q')
                       END AS poczatek_okresu,
                       CASE
                           WHEN sp.dlugosc = 1 THEN LAST_DAY(to_date('2026-09-15', 'yyyy-MM-dd'))
                           WHEN sp.dlugosc = 3 THEN LAST_DAY(ADD_MONTHS(TRUNC(to_date('2026-09-15', 'yyyy-MM-dd'), 'Q'), 2))
                       END AS koniec_okresu
                FROM system_pracy sp
            )
        ),
        -- Jesli pracownik zostal zatrudniony w trakcie okresu (p.data_zatr > poczatek_okresu),
        -- pelne tygodnie licz od zatrudnienia - ale siatka tygodni (granice co 7 dni)
        -- jest zawsze wyznaczana od 1. dnia okresu rozliczeniowego.
        -- poczatek_pelnych_tygodni_pracownika - pierwszy dzien pierwszego tygodnia,
        --                                       w ktorym pracownik byl zatrudniony
        --                                       od samego jego poczatku
        okres_zatr AS (
            SELECT /*+ MATERIALIZE */
                   o.prac_id, o.dlugosc, o.poczatek_okresu, o.koniec_okresu,
                   o.liczba_pelnych_tygodni, o.koniec_pelnych_tygodni,
                   o.poczatek_okresu +
                       (CASE
                           WHEN ph.data_zatr > o.poczatek_okresu
                               THEN CEIL((ph.data_zatr - o.poczatek_okresu) / 7)
                           ELSE 0
                       END) * 7 AS poczatek_pelnych_tygodni_pracownika,
                   GREATEST(
                       o.liczba_pelnych_tygodni -
                       (CASE
                           WHEN ph.data_zatr > o.poczatek_okresu
                               THEN CEIL((ph.data_zatr - o.poczatek_okresu) / 7)
                           ELSE 0
                       END),
                       0
                   ) AS liczba_pelnych_tygodni_pracownika
            FROM okres o
            JOIN prac_hr ph ON ph.prac_id = o.prac_id
        ),
        gr_cz_pr AS (
            SELECT /*+ MATERIALIZE */
                   c.prac_id,
                   GREATEST(c.DATA_OD, o.poczatek_okresu) AS seg_od,
                   LEAST(NVL(c.DATA_DO, o.koniec_okresu), o.koniec_okresu) AS seg_do,
                   s.ID AS id
            FROM L_GR_CZ_PRACY c
            JOIN SL_GR_CZ s ON s.ID = c.GR_CZ_ID
            JOIN okres o ON o.prac_id = c.prac_id
            WHERE c.DATA_OD <= o.koniec_okresu
              AND NVL(c.DATA_DO, o.koniec_okresu) >= o.poczatek_okresu
        ),
        -- CZAS_NOM zsumowany wylacznie z dni naleazacych do pelnych tygodni okresu,
        -- liczonych od zatrudnienia gdy pracownik zaczal prace w trakcie okresu
        kal_base AS (
            SELECT kb.prac_id, oz.poczatek_okresu, oz.koniec_okresu,
                   SUM(kb.czas_nom) AS suma_czas_nom_sek
            FROM NT_KP_KDR_KALENDARZE_PRAC kb
            JOIN okres_zatr oz
                 ON  oz.prac_id    = kb.prac_id
                 AND kb.dzien_mies BETWEEN oz.poczatek_pelnych_tygodni_pracownika AND oz.koniec_pelnych_tygodni
            JOIN gr_cz_pr g
                 ON  g.prac_id   = kb.prac_id
                 AND kb.SGRC_ID  = g.id
                 AND kb.dzien_mies BETWEEN g.seg_od AND g.seg_do
            WHERE kb.czas_nom IS NOT NULL
              AND kb.prac_id IN (SELECT prac_id FROM pracownicy)
              -- Staly (literalowy) zakres dat, bezpiecznie obejmujacy zarowno 1-, jak i
              -- 3-miesieczny okres rozliczeniowy wokol daty referencyjnej (biezacy kwartal).
              -- W przeciwienstwie do korelowanego warunku z JOIN-a do okres_zatr, staly
              -- literal ma szanse zostac wcisniety do wnetrza widoku NT_KP_KDR_KALENDARZE_PRAC
              -- (ANTI JOIN wewnatrz widoku rozciaga sie do "konca swiata" dla przypisan grup
              -- czasu pracy bez daty koncowej, co bez tego filtra generuje dziesiatki
              -- milionow wirtualnych wierszy kalendarza).
              AND kb.dzien_mies BETWEEN TRUNC(to_date('2026-09-15', 'yyyy-MM-dd'), 'Q')
                                     AND LAST_DAY(ADD_MONTHS(TRUNC(to_date('2026-09-15', 'yyyy-MM-dd'), 'Q'), 2))
            GROUP BY kb.prac_id, oz.poczatek_okresu, oz.koniec_okresu
        ),
        -- nadgodziny zsumowane z CALEGO okresu rozliczeniowego (nie tylko pelne tygodnie)
        nadgodziny AS (
            SELECT n.prac_id, o.poczatek_okresu, o.koniec_okresu,
                   SUM(n.czas) AS suma_czas_nadg
            FROM KP_RCP_ZLEC_NADG_PRAC n
            JOIN okres o ON o.prac_id = n.prac_id
            WHERE n.data BETWEEN o.poczatek_okresu AND o.koniec_okresu
            GROUP BY n.prac_id, o.poczatek_okresu, o.koniec_okresu
        )
    SELECT ROW_NUMBER() OVER (ORDER BY NLSSORT(p.nazwisko, 'NLS_SORT=POLISH'), NLSSORT(p.imie, 'NLS_SORT=POLISH')) AS lp,
           p.imie, p.nazwisko, p.nr_ew, p.nr_karty, p.jednostka_org AS jednostka_organizacyjna, p.mpk, p.stanowisko,
           CASE
               WHEN o.dlugosc = 1 AND pa_sesje.biezacy_jezyk = 'en' THEN '1 - month settlement period'
               WHEN o.dlugosc = 3 AND pa_sesje.biezacy_jezyk = 'en' THEN '3 - month settlement period'
               WHEN o.dlugosc = 1 THEN '1 - miesięczny okres rozliczeniowy'
               WHEN o.dlugosc = 3 THEN '3 - miesięczny okres rozliczeniowy'
           END AS typ_okresu_rozliczeniowego,
           TO_CHAR(o.poczatek_okresu, 'dd.mm.yyyy') || ' - ' || TO_CHAR(o.koniec_okresu, 'dd.mm.yyyy') AS okres_rozliczeniowy,
           ROUND(kb.suma_czas_nom_sek / 3600, 2) AS CZAS_NOM_z_kalendarza,
           TO_CHAR(ROUND(NVL(na.suma_czas_nadg, 0), 2), 'FM999999990.00', 'NLS_NUMERIC_CHARACTERS=''.,''') AS suma_CZAS_nadgodzin,
           TO_CHAR(
               ROUND(
                   (kb.suma_czas_nom_sek / 3600 + NVL(na.suma_czas_nadg, 0)) / NULLIF(o.liczba_pelnych_tygodni_pracownika, 0),
                   2
               ),
               'FM999999990.00', 'NLS_NUMERIC_CHARACTERS=''.,'''
           ) AS suma_CZAS_NOM,
           CASE WHEN pa_sesje.biezacy_jezyk = 'en'
                THEN 'BREACH – an average of 48 hours weekly in the settlement period exceeded'
                ELSE 'NARUSZENIE - przeciętny tygodniowy czas pracy powyżej 48 godzin w okresie rozliczeniowym'
           END AS komunikat
    FROM prac_hr p
    JOIN okres_zatr o ON o.prac_id = p.prac_id
    JOIN kal_base kb ON kb.prac_id = p.prac_id AND kb.poczatek_okresu = o.poczatek_okresu AND kb.koniec_okresu = o.koniec_okresu
    LEFT JOIN nadgodziny na ON na.prac_id = p.prac_id AND na.poczatek_okresu = o.poczatek_okresu AND na.koniec_okresu = o.koniec_okresu
    WHERE ROUND(
              (kb.suma_czas_nom_sek / 3600 + NVL(na.suma_czas_nadg, 0)) / NULLIF(o.liczba_pelnych_tygodni_pracownika, 0),
              2
          ) > 48
    ORDER BY p.nazwisko, p.imie, o.poczatek_okresu
)
