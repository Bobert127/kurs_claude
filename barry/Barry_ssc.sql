select distinct imie, nazwisko, nr_ew, firma, DATA_ZATRUDNIENIA, DATA_ZWOLNIENIA, NAZWA_STANOWISKA, ETAT, JEDN_ORG,
sum(g50) g50, sum(g100) + sum(sred) g100, sum(g_ponadnormatywne) g_ponadnormatywne , sum(nocne) nocne
from
(
       select zn.imie, zn.nazwisko, zn.nr_ew, akt_dane.firma(zn.pracid) firma,
       to_char(zn.DATA_ZATRUDNIENIA, 'YYYY-MM-DD') DATA_ZATRUDNIENIA, to_char(zn.DATA_ZWOLNIENIA, 'YYYY-MM-DD') DATA_ZWOLNIENIA,
       akt_dane.typ_pracownika(pracid, case when zn.DATA_ZATRUDNIENIA > to_date('01.08.2026', 'dd.mm.yyyy') then zn.data_zatrudnienia else TO_DATE('01.08.2026', 'DD.MM.YYYY') end) NAZWA_STANOWISKA,
        akt_dane.stanowisko(pracid, case when zn.DATA_ZATRUDNIENIA > to_date('01.08.2026', 'dd.mm.yyyy') then zn.data_zatrudnienia else TO_DATE('01.08.2026', 'DD.MM.YYYY') end) STANOWISKO,
        akt_dane.wym_et(pracid, case when zn.DATA_ZATRUDNIENIA > to_date('01.08.2026', 'dd.mm.yyyy') then zn.data_zatrudnienia else TO_DATE('01.08.2026', 'DD.MM.YYYY') end) ETAT,
        akt_dane.j_org(pracid, case when zn.DATA_ZATRUDNIENIA > to_date('01.08.2026', 'dd.mm.yyyy') then zn.data_zatrudnienia else TO_DATE('01.08.2026', 'DD.MM.YYYY') end) JEDN_ORG,
       round(sum(zo.CLASSIFIED_SECONDS_11/3600),2) g50,
       round(sum(zo.CLASSIFIED_SECONDS_12/3600),2) g100,
       round(sum(zo.CLASSIFIED_SECONDS_20/3600),2) sred,
       round(sum(zo.CLASSIFIED_SECONDS_30/3600),2) g_ponadnormatywne,
       0 nocne

       from KP_RCP_OVERTIME_PAYMENT ZO
           left join
           (
               select zn1.id pow,
               p.imie imie,
               p.nazwisko nazwisko,
               p.nr_ew nr_ew,
               p.prac_id pracid,
               p.data_zatr data_zatrudnienia,
               p.data_rozw data_zwolnienia
               from KP_RCP_ZLEC_NADG_PRAC zn1, t_prac p
               where p.prac_id = zn1.prac_id
           ) zn on zn.pow = zo.rczp_id

       where zo.calendar_date between '26/08/01' and '26/08/31'
       and akt_dane.firma(zn.pracid) in ('Barry Callebaut SSC sp. z o.o. ')
       group by zn.imie, zn.nazwisko, zn.nr_ew, zn.pracid, zn.DATA_ZATRUDNIENIA, zn.DATA_ZWOLNIENIA

union all

        select p.imie, p.nazwisko, p.nr_ew, akt_dane.firma(p.prac_id) firma,
        to_char(p.data_zatr, 'YYYY-MM-DD') DATA_ZATRUDNIENIA, to_char(p.data_rozw, 'YYYY-MM-DD') DATA_ZWOLNIENIA,
        akt_dane.typ_pracownika(p.prac_id, case when p.data_zatr > to_date('01.08.2026', 'dd.mm.yyyy') then p.data_zatr else TO_DATE('01.08.2026', 'DD.MM.YYYY') end) NAZWA_STANOWISKA,
        akt_dane.stanowisko(p.prac_id, case when p.data_zatr > to_date('01.08.2026', 'dd.mm.yyyy') then p.data_zatr else TO_DATE('01.08.2026', 'DD.MM.YYYY') end) STANOWISKO,
        akt_dane.wym_et(p.prac_id, case when p.data_zatr > to_date('01.08.2026', 'dd.mm.yyyy') then p.data_zatr else TO_DATE('01.08.2026', 'DD.MM.YYYY') end) ETAT,
        akt_dane.j_org(p.prac_id, case when p.data_zatr > to_date('01.08.2026', 'dd.mm.yyyy') then p.data_zatr else TO_DATE('01.08.2026', 'DD.MM.YYYY') end) JEDN_ORG,
        0 g50,
        0 g100,
        0 sred,
        0 g_ponadnormatywne,
        sum(b1.k_041) + sum(b1.k_127) + sum(b1.k_128) nocne
        from rcp_bilans b1, t_prac p
        where b1.data between '26/08/01' and '26/08/31'
        and p.prac_id = b1.prac_id
        and (b1.k_041 > 0 or b1.k_127 > 0 or b1.k_128 > 0)
        and p.firm_id in (181)
        group by p.prac_id, p.imie, p.nazwisko, p.nr_ew, p.data_zatr, p.data_rozw
) dane
group by imie, nazwisko, nr_ew, firma, DATA_ZATRUDNIENIA, DATA_ZWOLNIENIA, NAZWA_STANOWISKA, ETAT, JEDN_ORG
order by 4, 2, 1;
