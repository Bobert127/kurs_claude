-- ============================================================
-- ZAPYTANIE ZOPTYMALIZOWANE
-- INSERT uzywa %ROWTYPE — odporny na dodanie nowych kolumn.
-- ID nowego rekordu pochodzi wylacznie z kp_rczp_seq.nextval.
-- modyfikacja kolumny settled
-- ============================================================

-- ============================================================
-- Blok 1: Insert benefitow dla sobot (TYP_DNIA = 'W')
-- ============================================================
DECLARE
    src_rec   kp_rcp_zlec_nadg_prac%ROWTYPE;
    v_new_id  kp_rcp_zlec_nadg_prac.id%TYPE;
    v_kali_id kp_rcp_zlec_nadg_prac.kali_id%TYPE;

    CURSOR c IS
        SELECT DISTINCT
               CASE WHEN ben.id IS NULL THEN ov.id END AS ov_id,
               ov.prac_id
          FROM nt_kp_kdr_kalendarze_prac        ka
             , t_prac                            prac
             , kp_rcp_zlec_nadg_prac             ov
          LEFT JOIN kp_rcp_zlec_nadg_prac_benefity ben
                 ON ben.ben_id = ov.id
         WHERE ov.kali_id        = ka.id
           AND ov.day_off_in_lieu = 'T'
           AND ov.settled         = 'N'
           AND ka.typ_dnia        = 'W'
           AND ka.prac_id         = prac.prac_id
           AND prac.firm_id       = 100
           AND ( ov.uzasadnienie != 'benefit sobota'
              OR ov.uzasadnienie IS NULL )
           AND ov.data            BETWEEN sysdate - 60 AND sysdate + 60
           AND ov.data            >= DATE '2025-12-01'
           AND ov.czas            = 8
           AND prac.prac_id       = ov.prac_id;

BEGIN
    FOR rec IN c LOOP

        CONTINUE WHEN rec.ov_id IS NULL;

        -- nowe ID z sekwencji pobrane przed skopiowaniem rekordu zrodlowego
        SELECT kp_rczp_seq.nextval
          INTO v_new_id
          FROM dual;

        -- jeden SELECT zamiast ~10 podzapytan do tego samego wiersza
        SELECT *
          INTO src_rec
          FROM kp_rcp_zlec_nadg_prac
         WHERE id = rec.ov_id;

        -- wyznacz wolny dzien sobotni w kalendarzu pracownika
        BEGIN
            SELECT kal.id
              INTO v_kali_id
              FROM nt_kp_kdr_kalendarze_prac kal
                 , l_umowy                   luw
             WHERE kal.typ_dnia    = 'W'
               AND luw.prac_id     = kal.prac_id
               AND luw.data_od    <= sysdate
               AND NVL( luw.data_do, DATE '2099-01-01' ) >= sysdate
               AND kal.dzien_mies  >= luw.data_od
               AND NOT EXISTS (
                       SELECT 1
                         FROM kp_rcp_zlec_nadg_prac z
                        WHERE z.kali_id    = kal.id
                          AND z.prac_id    = kal.prac_id
                          AND kal.typ_dnia = 'W'
                   )
               AND kal.dzien_mies  BETWEEN sysdate - 60 AND sysdate + 30
               AND kal.dzien_mies  < pa_standard.ostatni_dzien_roku(sysdate)
               AND kal.prac_id     = rec.prac_id
               AND ROWNUM         <= 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN v_kali_id := NULL;
        END;

        -- nadpisz tylko pola rozniace sie od rekordu zrodlowego
        src_rec.id           := v_new_id;
        src_rec.uzasadnienie := 'benefit sobota';
        src_rec.kali_id      := v_kali_id;
        src_rec.payment_only := 'N';
        src_rec.settled      := 'N';
        src_rec.guid         := SYS_GUID();

        INSERT INTO kp_rcp_zlec_nadg_prac
        VALUES src_rec;

        INSERT INTO kp_rcp_zlec_nadg_prac_benefity
        VALUES ( kp_rcp_zlec_nadg_prac_benefity_seq.nextval, rec.ov_id );

        COMMIT;

    END LOOP;
END;
/
