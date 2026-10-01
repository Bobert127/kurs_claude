-- =============================================================================
-- HSBC - weryfikacja normy tygodniowej (jeden wiersz na nr_ew)
--
-- Konwencja jak w hsbcsd_brak_odpoczynku_tygodniowego_pracownicy.sql:
--   * placeholdery silnika raportu TETA/Konstelacja (^$DATA_OD^, ^$DATA_DO^,
--     ^$P_DATE_FORMAT^).
--   * SELECT ... INTO v_* do osadzenia w silniku raportowym, ktory iteruje
--     po wierszach i mapuje kolumny na zmienne v_*.
--
-- Wynik: jeden wiersz na pracownika (nr_ew) w danym okresie rozliczeniowym
-- (miesiecznym lub kwartalnym) - bez rozbicia na tygodnie. Kolumny
-- pierwszy_dzien_tygodnia / zakres_tygodnia oraz srednia_CZAS_NOM_w_okresie
-- sa zakomentowane - nie maja sensu przy agregacji do jednego wiersza
-- (srednia_CZAS_NOM_w_okresie wyszlaby identyczna z suma_CZAS_NOM).
--
-- CZAS_NOM_z_kalendarza / suma_CZAS_nadgodzin / suma_CZAS_NOM licza PELNE
-- TYGODNIE, zakotwiczone o poczatek_okresu (pierwszy dzien miesiaca/kwartalu
-- pracownika), a NIE o kalendarzowy poniedzialek (ISO) i NIE o literalna
-- DATA_OD/DATA_DO. Przyklad: okres zaczyna sie 01.08.2026 (sobota) ->
-- tygodnie licza sie sobota-piatek; ostatni pelny tydzien zawierajacy koniec
-- miesiaca (31.08.2026, poniedzialek) konczy sie 04.09.2026, wiec dane z
-- 01-04.09 sa WLICZANE do normy tego miesiaca, mimo ze kalendarzowo naleza
-- juz do wrzesnia - inaczej ostatni tydzien okresu znikalby z sumy w calosci
-- (obserwowany blad: 160h zamiast 200h, roznica dokladnie jednego tygodnia
-- normy, gdy ostatni tydzien byl twardo ucinany warunkiem <= koniec_okresu).
--
-- Gorna granica zakresu liczona jest jako MNIEJSZA z dwoch (dwa warunki AND
-- dzialaja jak LEAST): (a) pelny tydzien wyznaczony przez DATA_DO wzgledem
-- poczatek_okresu, (b) pelny tydzien wyznaczony przez koniec_okresu wzgledem
-- poczatek_okresu - dzieki temu nie wychodzimy poza zadany zakres raportu,
-- ale tez nie ucinamy pelnego tygodnia w srodku/na koncu okresu. Ten sam
-- wzor stosowany jest symetrycznie dla kal_base (norma z kalendarza) i dla
-- nadgodziny/nadg_tydz (zlecone nadgodziny), zeby obie wartosci pochodzily
-- z dokladnie tego samego zakresu dat.
-- =============================================================================
SELECT LP, IMIE, NAZWISKO, NR_EW, NR_KARTY, JEDNOSTKA_ORGANIZACYJNA, MPK, STANOWISKO, OKRES_ROZLICZENIOWY,
p_d_okresu_rozliczeniowego, /* pierwszy_dzien_tygodnia, zakres_tygodnia, */ CZAS_NOM_z_kalendarza, suma_CZAS_nadgodzin,
ilosc_tygodni, suma_CZAS_NOM
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
-- v_pierwszy_dzien_tygodnia,
-- v_zakres_tygodnia,
v_czas_nom_z_kalendarza,
v_suma_czas_nadgodzin,
v_ilosc_tygodni,
v_suma_czas_nom
FROM  (

  WITH
        kalendarze AS (
            SELECT
                   k.prac_id, k.dzien_mies
            FROM NT_KP_KDR_KALENDARZE_PRAC k
            WHERE k.TYP_DNIA = 'W'
              AND k.DZIEN_MIES BETWEEN to_date('^$DATA_OD^', '^$P_DATE_FORMAT^') AND to_date('^$DATA_DO^', '^$P_DATE_FORMAT^')
        ),
        prac_hr AS (
            SELECT
                   p.prac_id, p.imie, p.nazwisko, p.nr_ew, p.nr_karty,
                   LEAST(NVL(p.data_rozw, to_date('^$DATA_OD^', '^$P_DATE_FORMAT^')), to_date('^$DATA_OD^', '^$P_DATE_FORMAT^')) AS data_ref, akt_dane.j_org(p.prac_id, LEAST(NVL(p.data_rozw, to_date('^$DATA_OD^', '^$P_DATE_FORMAT^')), to_date('^$DATA_OD^', '^$P_DATE_FORMAT^'))) AS jednostka_org,
                   akt_dane.mpk(p.prac_id, LEAST(NVL(p.data_rozw, to_date('^$DATA_OD^', '^$P_DATE_FORMAT^')), to_date('^$DATA_OD^', '^$P_DATE_FORMAT^'))) AS mpk,
                   akt_dane.stanowisko(p.prac_id, LEAST(NVL(p.data_rozw, to_date('^$DATA_OD^', '^$P_DATE_FORMAT^')), to_date('^$DATA_OD^', '^$P_DATE_FORMAT^'))) AS stanowisko
            FROM t_prac p
            WHERE p.prac_id IN (SELECT prac_id FROM kalendarze)
        ),
        system_pracy AS (
            SELECT
                   ph.prac_id, b.dlugosc
            FROM prac_hr ph
            JOIN KP_RCP_WORKING_TIME_SYSTEMS scz
                 ON scz.code = akt_dane.work_time_system(ph.prac_id, to_date('^$DATA_OD^', '^$P_DATE_FORMAT^'))
            JOIN KP_RCP_OKRESY_BILANSU b ON b.id = scz.rcok_id
        ),
        okres AS (
            SELECT
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
            SELECT
                   prac_id, dzien_mies, czas_nom
            FROM NT_KP_KDR_KALENDARZE_PRAC
            WHERE dzien_mies BETWEEN to_date('^$DATA_OD^', '^$P_DATE_FORMAT^') - 6 AND to_date('^$DATA_DO^', '^$P_DATE_FORMAT^') + 6
              AND prac_id IN (SELECT prac_id FROM kalendarze)
              AND czas_nom IS NOT NULL
        ),
        nadgodziny AS (
            SELECT
                   n.prac_id,
                   n.data,
                   n.czas
            FROM KP_RCP_ZLEC_NADG_PRAC n
            WHERE n.prac_id IN (SELECT prac_id FROM prac_hr)
              AND n.data BETWEEN to_date('^$DATA_OD^', '^$P_DATE_FORMAT^') - 6 AND to_date('^$DATA_DO^', '^$P_DATE_FORMAT^') + 6
        ),
        nadg_tydz AS (
            SELECT
                   n.prac_id,
                   o.poczatek_okresu,
                   FLOOR((n.data - o.poczatek_okresu) / 7) AS nr_tygodnia,
                   SUM(n.czas)                              AS suma_czas_nadg
            FROM nadgodziny n
            JOIN okres o
                 ON  o.prac_id = n.prac_id
                 AND n.data   >= o.poczatek_okresu
                 AND n.data   >= o.poczatek_okresu + 7 * FLOOR((to_date('^$DATA_OD^', '^$P_DATE_FORMAT^') - o.poczatek_okresu) / 7)
                 AND n.data   <= o.poczatek_okresu + 7 * FLOOR((to_date('^$DATA_DO^', '^$P_DATE_FORMAT^') - o.poczatek_okresu) / 7) + 6
                 AND n.data   <= o.poczatek_okresu + 7 * FLOOR((o.koniec_okresu          - o.poczatek_okresu) / 7) + 6
            GROUP BY
                   n.prac_id,
                   o.poczatek_okresu,
                   FLOOR((n.data - o.poczatek_okresu) / 7)
        ),
        czas_nom_agg AS (
            SELECT
                   kb.prac_id,
                   o.poczatek_okresu,
                   o.koniec_okresu,
                   FLOOR((kb.dzien_mies - o.poczatek_okresu) / 7)  AS nr_tygodnia,
                   ROUND(SUM(kb.czas_nom) / 3600, 2)               AS suma_kal_h,
                   ROUND(NVL(MAX(nt.suma_czas_nadg), 0), 2)        AS suma_nadg_h,
                   ROUND(
                       SUM(kb.czas_nom) / 3600
                       + NVL(MAX(nt.suma_czas_nadg), 0),
                       2
                   )                                                AS suma_czas_nom_h
            FROM kal_base kb
            JOIN okres o
                 ON  o.prac_id     = kb.prac_id
                 AND kb.dzien_mies >= o.poczatek_okresu
                 AND kb.dzien_mies >= o.poczatek_okresu + 7 * FLOOR((to_date('^$DATA_OD^', '^$P_DATE_FORMAT^') - o.poczatek_okresu) / 7)
                 AND kb.dzien_mies <= o.poczatek_okresu + 7 * FLOOR((to_date('^$DATA_DO^', '^$P_DATE_FORMAT^') - o.poczatek_okresu) / 7) + 6
                 AND kb.dzien_mies <= o.poczatek_okresu + 7 * FLOOR((o.koniec_okresu          - o.poczatek_okresu) / 7) + 6
            LEFT JOIN nadg_tydz nt
                 ON  nt.prac_id        = kb.prac_id
                 AND nt.poczatek_okresu = o.poczatek_okresu
                 AND nt.nr_tygodnia    = FLOOR((kb.dzien_mies - o.poczatek_okresu) / 7)
            GROUP BY
                   kb.prac_id,
                   o.poczatek_okresu,
                   o.koniec_okresu,
                   FLOOR((kb.dzien_mies - o.poczatek_okresu) / 7)
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
         /*
         TO_CHAR(o.poczatek_okresu + t.nr * 7, '^$P_DATE_FORMAT^') AS  pierwszy_dzien_tygodnia,
         'od ' || TO_CHAR(o.poczatek_okresu + t.nr * 7, '^$P_DATE_FORMAT^')
             || ' do ' || TO_CHAR(
                 LEAST(o.poczatek_okresu + t.nr * 7 + 6, to_date('^$DATA_DO^', '^$P_DATE_FORMAT^')),
                 '^$P_DATE_FORMAT^'
             ) AS zakres_tygodnia,
         */
         ROUND(SUM(cn.suma_kal_h), 2)  AS CZAS_NOM_z_kalendarza,
         ROUND(SUM(cn.suma_nadg_h), 2) AS suma_CZAS_nadgodzin,
         COUNT(*)                      AS ilosc_tygodni,
         ROUND(SUM(cn.suma_czas_nom_h) / COUNT(*), 2) AS suma_CZAS_NOM
         /*
         ,ROUND(AVG(cn.suma_czas_nom_h), 2) AS srednia_CZAS_NOM_w_okresie
         */
  FROM prac_hr p
  JOIN okres o ON o.prac_id = p.prac_id
  JOIN czas_nom_agg cn
         ON  cn.prac_id        = p.prac_id
         AND cn.poczatek_okresu = o.poczatek_okresu
         AND cn.koniec_okresu  = o.koniec_okresu
  GROUP BY
         p.prac_id, p.imie, p.nazwisko, p.nr_ew, p.nr_karty,
         p.jednostka_org, p.mpk, p.stanowisko,
         o.dlugosc, o.poczatek_okresu
  ORDER BY p.nazwisko, p.imie, o.poczatek_okresu
);
