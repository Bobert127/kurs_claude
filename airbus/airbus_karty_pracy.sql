select p.nr_ew, p.imie, p.nazwisko,
sum(k_02) G_50,
sum(k_06) G_100,
sum(k_13) G_50_M1,
sum(k_14) G_100_M1,
sum(k_07) nocne,
sum(k_03) "Praca zdalna okazjonalna",
sum(k_04) "Praca zdalna częściowa",
sum(k_05) "NN do wyjaśnienia",
sum(k_08) + sum(k_12) "II zmiana",
sum(k_09) "święto",
sum(k_11) G_50_wprowadzane,
sum(k_10) G_100_wprowadzane
from KP_L_K_PR kp, t_prac p, KP_TYPY_PRAC tp, SL_TYP_PR stp
where kp.data between '26/06/01' and '26/06/30'
and p.prac_id = kp.prac_id
and tp.prac_id = p.prac_id
and stp.id = tp.STPR_ID
AND tp.data_od <= '26/06/30'
AND (tp.data_do IS NULL OR tp.data_do >= '26/06/01')
and stp.nazwa = 'BCW'
group by p.nr_ew, p.imie, p.nazwisko
having (sum(k_02)+ sum(k_06)+ sum(k_13)+ sum(k_14)+ sum(k_07)+ sum(k_03)+ sum(k_04)+ sum(k_05)+ sum(k_08)+ sum(k_09)+ sum(k_11)+ sum(k_10) )> 0
order by p.nazwisko;

---MRO

select p.nr_ew, p.imie, p.nazwisko, case when tp.STPR_ID = 10040 then 'WCW' when tp.STPR_ID = 10041 then 'BCW' end typ_pracownika,
sum(k_02) G_50,
sum(k_06) G_100,
sum(k_13) G_50_M1,
sum(k_14) G_100_M1,
sum(k_07) nocne,
sum(k_03) "Praca zdalna okazjonalna",
sum(k_04) "Praca zdalna częciowa",
sum(k_05) "NN do wyjaśnienia",
sum(k_08) + sum(k_12) "II zmiana",
sum(k_09) "Święto",
sum(k_11) G_50_wprowadzane,
sum(k_10) G_100_wprowadzane
from KP_L_K_PR kp, t_prac p, KP_TYPY_PRAC tp, SL_TYP_PR stp
where kp.data between to_date('26/06/01', 'yy/mm/dd') and to_date('26/06/30', 'yy/mm/dd')
and p.prac_id = kp.prac_id
and tp.prac_id = p.prac_id
and stp.id = tp.STPR_ID
and stp.nazwa = 'WCW'
AND tp.data_od <= to_date('26/06/30', 'yy/mm/dd')
AND (tp.data_do IS NULL OR tp.data_do >= to_date('26/06/01', 'yy/mm/dd'))
AND p.prac_id in
((
select p.prac_id id
from t_prac p
where
akt_dane.mpk(p.prac_id, sysdate-15) in ('16302', '16305', '16306', '16307', '16308')
and akt_dane.stanowisko(p.prac_id, sysdate) not in ('Szef Sekcji Kontroli Jakości')
AND p.data_zatr <= to_date('26/06/30', 'yy/mm/dd')
AND (NVL(p.data_rozw , TO_DATE('2099-12-31', 'YYYY-MM-DD')) >= to_date('26/06/01', 'yy/mm/dd'))


union

select p.prac_id id
from t_prac p
where akt_dane.mpk(p.prac_id, sysdate-15) in ('16010')
and akt_dane.stanowisko(p.prac_id, sysdate) not in ('Manager Działu MRO')
AND p.data_zatr <= sysdate
AND (NVL(p.data_rozw , TO_DATE('2099-01-01', 'YYYY-MM-DD')) >= sysdate)
))
group by p.nr_ew, p.imie, p.nazwisko, tp.STPR_ID
having (sum(k_02)+ sum(k_06)+ sum(k_13)+ sum(k_14)+ sum(k_07)+ sum(k_03)+ sum(k_04)+ sum(k_05)+ sum(k_08)+ sum(k_09)+ sum(k_11)+ sum(k_10) )> 0
order by p.nazwisko;
