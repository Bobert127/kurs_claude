-- Weryfikacja podwójnych MPK
-- Grupowanie po pełnym miesiącu, kolumna "miesiac" w formacie MM-nazwa (np. 04-Kwiecień)

select p.imie, p.nazwisko, p.nr_ew, p.nr_karty,
       to_char(b.data, 'MM-Month', 'NLS_DATE_LANGUAGE=POLISH') as miesiac,
       count(b.id) as ilosc_dni
from   rcp_bilans b, t_prac p
where  b.data between date '2026-04-01' and date '2026-06-30'
and    p.prac_id = b.prac_id
group  by p.imie, p.nazwisko, p.nr_ew, p.nr_karty,
          to_char(b.data, 'MM-Month', 'NLS_DATE_LANGUAGE=POLISH')
having count(b.id) > extract(day from last_day(max(b.data)))
order  by p.nazwisko, miesiac;
