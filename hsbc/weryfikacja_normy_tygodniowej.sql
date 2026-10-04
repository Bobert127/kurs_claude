-- =============================================================================
-- HSBC - weryfikacja normy tygodniowej (jeden wiersz na nr_ew)
-- WERSJA 2
--
-- Zmiany wzgledem wersji 1:
--   1. Jeden parametr ^$DATA^ zamiast ^$DATA_OD^/^$DATA_DO^ - dowolna data
--      wewnatrz okresu rozliczeniowego pracownika. Okres (poczatek_okresu /
--      koniec_okresu) wyznaczany jest wprost z tej daty (wg dlugosci systemu
--      pracy: 1 - miesiac, 3 - kwartal), a nie z literalnego zakresu dat.
--   2. Raport zawsze pobiera CALY okres rozliczeniowy pracownika (a nie jego
--      podzbior wyznaczony przez DATA_OD/DATA_DO) - kal_base i nadgodziny sa
--      filtrowane bezposrednio BETWEEN poczatek_okresu AND koniec_okresu,
--      wiec ostatni tydzien okresu konczy sie dokladnie na koncu okresu
--      (uklad 1/7-6/7), bez przycinania czy przelewania sie poza okres.
--   3. Dodana kolumna k_d_okresu_rozliczeniowego (koniec okresu) obok juz
--      istniejacej p_d_okresu_rozliczeniowego (poczatek okresu).
--   4. Usunieta agregacja tygodniowa (nadg_tydz / czas_nom_agg / FLOOR(.../7))
--      - raport i tak pokazuje jeden wiersz na okres, wiec rozbicie na
--      tygodnie bylo zbedne. Przy okazji usuwa to blad w suma_CZAS_NOM:
--      poprzednio liczone jako SUM(cn.suma_czas_nom_h) / COUNT(*), czyli
--      SREDNIA tygodniowa zamiast sumy za caly okres. Teraz kal_base i
--      nadgodziny agreguja sie od razu do jednego wiersza na pracownika i
--      okres, bez dzielenia przez cokolwiek.
--   5. Dobor pracownikow: zamiast drogiego skanu NT_KP_KDR_KALENDARZE_PRAC
--      (TYP_DNIA='W') dla calej firmy w obrebie kwartalu, filtr pracownikow
--      (CTE 'pracownicy') dziala bezposrednio na t_prac.DATA_ZATR/DATA_ROZW
--      wzgledem ^$DATA^ - znaczaco tanszy dostep. Pracownik bez faktycznych
--      danych kalendarzowych w okresie i tak nie trafi do wyniku (INNER JOIN
--      do kal_base).
--   6. Hinty /*+ MATERIALIZE */ na prac_hr i okres - obie CTE sa czytane
--      wielokrotnie w dalszej czesci zapytania; bez wymuszenia materializacji
--      Oracle mogloby przeliczac je (a wraz z nimi drogie wywolania funkcji
--      akt_dane.j_org/mpk/stanowisko/work_time_system) wielokrotnie.
--   7. Potwierdzona jednostka KP_RCP_ZLEC_NADG_PRAC.czas - jest juz w
--      GODZINACH (wzorzec "GODZ_DO + czas/2/24" w innych raportach w repo,
--      gdzie dzielenie przez 24 ma sens tylko dla wartosci godzinowej; tabela
--      ma osobne, jawnie nazwane kolumny CLASSIFIED_SECONDS_*) - w
--      odroznieniu od czas_nom (sekundy, stad /3600) NIE dzielimy go.
--
-- Konwencja jak w hsbcsd_brak_odpoczynku_tygodniowego_pracownicy.sql:
--   * placeholdery silnika raportu TETA/Konstelacja (^$DATA^, ^$P_DATE_FORMAT^).
--   * SELECT ... INTO v_* do osadzenia w silniku raportowym, ktory iteruje
--     po wierszach i mapuje kolumny na zmienne v_*.
-- =============================================================================
SELECT LP, IMIE, NAZWISKO, NR_EW, NR_KARTY, JEDNOSTKA_ORGANIZACYJNA, MPK, STANOWISKO, OKRES_ROZLICZENIOWY,
p_d_okresu_rozliczeniowego, k_d_okresu_rozliczeniowego, CZAS_NOM_z_kalendarza, suma_CZAS_nadgodzin,
suma_CZAS_NOM
INTO v_lp,
v_imie,
v_nazwisko,
v_nr_ew,
v_nr_karty,
v_jednostka_organizacyjna,
v_mpk,
v_stanowisko,
v_okres_rozliczeniowy,
v_p_d_okresu_rozliczeniowego,
v_k_d_okresu_rozliczeniowego,
v_czas_nom_z_kalendarza,
v_suma_czas_nadgodzin,
v_suma_czas_nom
FROM  (

  WITH
        pracownicy AS (
            -- tani filtr zamiast skanu NT_KP_KDR_KALENDARZE_PRAC dla calej firmy:
            -- pracownik zatrudniony na dzien ^$DATA^
            SELECT
                   p.prac_id
            FROM t_prac p
            WHERE p.DATA_ZATR <= to_date('^$DATA^', '^$P_DATE_FORMAT^')
              AND (p.DATA_ROZW IS NULL OR p.DATA_ROZW >= to_date('^$DATA^', '^$P_DATE_FORMAT^'))
        ),
        prac_hr AS (
            SELECT /*+ MATERIALIZE */
                   p.prac_id, p.imie, p.nazwisko, p.nr_ew, p.nr_karty,
                   LEAST(NVL(p.data_rozw, to_date('^$DATA^', '^$P_DATE_FORMAT^')), to_date('^$DATA^', '^$P_DATE_FORMAT^')) AS data_ref,
                   akt_dane.j_org(p.prac_id, LEAST(NVL(p.data_rozw, to_date('^$DATA^', '^$P_DATE_FORMAT^')), to_date('^$DATA^', '^$P_DATE_FORMAT^'))) AS jednostka_org,
                   akt_dane.mpk(p.prac_id, LEAST(NVL(p.data_rozw, to_date('^$DATA^', '^$P_DATE_FORMAT^')), to_date('^$DATA^', '^$P_DATE_FORMAT^'))) AS mpk,
                   akt_dane.stanowisko(p.prac_id, LEAST(NVL(p.data_rozw, to_date('^$DATA^', '^$P_DATE_FORMAT^')), to_date('^$DATA^', '^$P_DATE_FORMAT^'))) AS stanowisko
            FROM t_prac p
            WHERE p.prac_id IN (SELECT prac_id FROM pracownicy)
        ),
        system_pracy AS (
            SELECT
                   ph.prac_id, b.dlugosc
            FROM prac_hr ph
            JOIN KP_RCP_WORKING_TIME_SYSTEMS scz
                 ON scz.code = akt_dane.work_time_system(ph.prac_id, to_date('^$DATA^', '^$P_DATE_FORMAT^'))
            JOIN KP_RCP_OKRESY_BILANSU b ON b.id = scz.rcok_id
        ),
        okres AS (
            -- okres rozliczeniowy wyznaczony wprost z pojedynczej daty ^$DATA^
            SELECT /*+ MATERIALIZE */
                   sp.prac_id, sp.dlugosc,
                   CASE
                       WHEN sp.dlugosc = 1 THEN TRUNC(to_date('^$DATA^', '^$P_DATE_FORMAT^'), 'MM')
                       WHEN sp.dlugosc = 3 THEN TRUNC(to_date('^$DATA^', '^$P_DATE_FORMAT^'), 'Q')
                   END AS poczatek_okresu,
                   CASE
                       WHEN sp.dlugosc = 1 THEN LAST_DAY(to_date('^$DATA^', '^$P_DATE_FORMAT^'))
                       WHEN sp.dlugosc = 3 THEN LAST_DAY(ADD_MONTHS(TRUNC(to_date('^$DATA^', '^$P_DATE_FORMAT^'), 'Q'), 2))
                   END AS koniec_okresu
            FROM system_pracy sp
        ),
        kal_base AS (
            -- suma nominalnego czasu z kalendarza za CALY okres (bez podzialu
            -- na tygodnie - raport pokazuje jeden wiersz na okres)
            SELECT
                   kb.prac_id,
                   o.poczatek_okresu,
                   o.koniec_okresu,
                   SUM(kb.czas_nom) AS suma_czas_nom_sek
            FROM NT_KP_KDR_KALENDARZE_PRAC kb
            JOIN okres o ON o.prac_id = kb.prac_id
            WHERE kb.dzien_mies BETWEEN o.poczatek_okresu AND o.koniec_okresu
              AND kb.czas_nom IS NOT NULL
            GROUP BY kb.prac_id, o.poczatek_okresu, o.koniec_okresu
        ),
        nadgodziny AS (
            -- KP_RCP_ZLEC_NADG_PRAC.czas jest juz w GODZINACH (potwierdzone
            -- wzorcem "GODZ_DO + czas/2/24" w Arla/benefit_nadgodziny_oryginal.sql,
            -- gdzie dzielenie przez 24 ma sens tylko dla wartosci godzinowej;
            -- tabela ma osobne, jawnie nazwane kolumny CLASSIFIED_SECONDS_*) -
            -- w odroznieniu od czas_nom (sekundy) NIE dzielimy przez 3600
            SELECT
                   n.prac_id,
                   o.poczatek_okresu,
                   o.koniec_okresu,
                   SUM(n.czas) AS suma_czas_nadg
            FROM KP_RCP_ZLEC_NADG_PRAC n
            JOIN okres o ON o.prac_id = n.prac_id
            WHERE n.data BETWEEN o.poczatek_okresu AND o.koniec_okresu
            GROUP BY n.prac_id, o.poczatek_okresu, o.koniec_okresu
        )

  SELECT
        ROW_NUMBER() OVER (ORDER BY NLSSORT(p.nazwisko, 'NLS_SORT=POLISH'), NLSSORT(p.imie,'NLS_SORT=POLISH')) AS lp,
         p.imie,
         p.nazwisko,
         p.nr_ew,
         p.nr_karty,
         p.jednostka_org AS  jednostka_organizacyjna,
         p.mpk,
         p.stanowisko,
         CASE o.dlugosc
             WHEN 1 THEN '1 - miesięczny okres rozliczeniowy'
             WHEN 3 THEN '3 - miesięczny okres rozliczeniowy'
         END AS okres_rozliczeniowy,
         TO_CHAR(o.poczatek_okresu, '^$P_DATE_FORMAT^') AS p_d_okresu_rozliczeniowego,
         TO_CHAR(o.koniec_okresu, '^$P_DATE_FORMAT^') AS k_d_okresu_rozliczeniowego,
         ROUND(kb.suma_czas_nom_sek / 3600, 2)                               AS CZAS_NOM_z_kalendarza,
         ROUND(NVL(na.suma_czas_nadg, 0), 2)                                 AS suma_CZAS_nadgodzin,
         ROUND(kb.suma_czas_nom_sek / 3600 + NVL(na.suma_czas_nadg, 0), 2)   AS suma_CZAS_NOM
  FROM prac_hr p
  JOIN okres o ON o.prac_id = p.prac_id
  JOIN kal_base kb
         ON  kb.prac_id        = p.prac_id
         AND kb.poczatek_okresu = o.poczatek_okresu
         AND kb.koniec_okresu  = o.koniec_okresu
  LEFT JOIN nadgodziny na
         ON  na.prac_id        = p.prac_id
         AND na.poczatek_okresu = o.poczatek_okresu
         AND na.koniec_okresu  = o.koniec_okresu
  ORDER BY p.nazwisko, p.imie, o.poczatek_okresu
);
