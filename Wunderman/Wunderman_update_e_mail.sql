-- =====================================================================
-- Wunderman_update_e_mail
-- Aktualizacja adresow e-mail pracownikow na podstawie tabeli aaa_zmina_email.
-- Dopasowanie po nr ewidencyjnym i nr karty.
-- Plik zawiera 3 wersje rozwiazania.
-- =====================================================================


-- ---------------------------------------------------------------------
-- WERSJA 1 (kursorowa, minimalna poprawka)
-- Aktualizacja t_prac.e_mail.
-- ---------------------------------------------------------------------
DECLARE
    a t_prac.prac_id%TYPE;
    b aaa_zmina_email.ADRES_EMAIL%TYPE;
    CURSOR c IS
        select p.prac_id, n.ADRES_EMAIL          -- kolejnosc zgodna z FETCH
        from aaa_zmina_email n, t_prac p
        where p.nr_ew = n.nr_ewidencyjny
          and p.nr_karty = n.nr_karty;
BEGIN
    OPEN c;
    LOOP
        FETCH c INTO a, b;
        EXIT WHEN c%notfound;
        IF a IS NOT NULL THEN
            UPDATE t_prac us
               SET us.e_mail = b
             WHERE us.prac_id = a;
        END IF;
    END LOOP;
    CLOSE c;
    COMMIT;                                       -- commit raz, po petli
END;
/


-- ---------------------------------------------------------------------
-- WERSJA 2 (zbiorcza, zalecana)
-- Aktualizacja t_prac.e_mail jednym poleceniem UPDATE.
-- ---------------------------------------------------------------------
BEGIN
    UPDATE t_prac us
       SET us.e_mail = (
            select n.ADRES_EMAIL
              from aaa_zmina_email n
             where n.nr_ewidencyjny = us.nr_ew
               and n.nr_karty      = us.nr_karty)
     WHERE EXISTS (
            select 1
              from aaa_zmina_email n
             where n.nr_ewidencyjny = us.nr_ew
               and n.nr_karty      = us.nr_karty
               and n.ADRES_EMAIL IS NOT NULL);
    COMMIT;
END;
/


-- ---------------------------------------------------------------------
-- WERSJA 3 (zbiorcza, zalecana)
-- Aktualizacja teta_users.EXTERNAL_ID, dopasowanie przez t_prac
-- (nr ewidencyjny + nr karty -> prac_id).
-- ---------------------------------------------------------------------
BEGIN
    UPDATE teta_users us
       SET us.EXTERNAL_ID = (
            select n.ADRES_EMAIL
              from aaa_zmina_email n, t_prac p
             where p.nr_ew    = n.nr_ewidencyjny
               and p.nr_karty = n.nr_karty
               and p.prac_id  = us.prac_id)
     WHERE EXISTS (
            select 1
              from aaa_zmina_email n, t_prac p
             where p.nr_ew    = n.nr_ewidencyjny
               and p.nr_karty = n.nr_karty
               and p.prac_id  = us.prac_id
               and n.ADRES_EMAIL IS NOT NULL);
    COMMIT;
END;
/
