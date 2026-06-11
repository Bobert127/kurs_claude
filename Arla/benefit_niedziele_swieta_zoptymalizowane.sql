-- ============================================================
-- BLOK 1 : Insert benefitow dla nadgodzin w niedziele / swieta
-- INSERT uzywa %ROWTYPE — odporny na dodanie nowych kolumn.
-- ID nowego rekordu pochodzi wylacznie z kp_rczp_seq.nextval.
-- ============================================================
DECLARE
    src_rec   kp_rcp_zlec_nadg_prac%ROWTYPE;
    v_kali_id kp_rcp_zlec_nadg_prac.kali_id%TYPE;
    v_new_id  kp_rcp_zlec_nadg_prac.id%TYPE;

    CURSOR c IS
        SELECT DISTINCT
               CASE WHEN ben.id IS NULL THEN ov.id END   AS ov_id,
               ov.prac_id,
               ov.day_off_in_lieu,
               ov.hours_off_in_lieu
          FROM nt_kp_kdr_kalendarze_prac        ka
             , t_prac                            prac
             , kp_rcp_zlec_nadg_prac             ov
          LEFT JOIN kp_rcp_zlec_nadg_prac_benefity ben
                 ON ben.ben_id = ov.id
         WHERE ov.kali_id       = ka.id
           AND ka.typ_dnia      IN ('S', 'WS')
           AND ov.payment_only  = 'N'
           AND ( ov.uzasadnienie != 'benefit niedziela i swieto'
              OR ov.uzasadnienie IS NULL )
           AND sysdate          >= ov.data - 60
           AND ov.czas          = 8
           AND prac.prac_id     = ov.prac_id
           AND ov.id            != 41392
           AND ov.id            = 65450
           AND prac.firm_id     = 100;

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

        -- wyznacz wolny dzien w kalendarzu pracownika
        BEGIN
            SELECT kal.id
              INTO v_kali_id
              FROM nt_kp_kdr_kalendarze_prac kal
                 , l_umowy                   luw
             WHERE kal.typ_dnia   IN ('S', 'N')
               AND luw.prac_id    = kal.prac_id
               AND luw.data_od   <= sysdate
               AND NVL( luw.data_do, DATE '2099-01-01' ) >= sysdate
               AND kal.dzien_mies >= luw.data_od
               AND NOT EXISTS (
                       SELECT 1
                         FROM kp_rcp_zlec_nadg_prac z
                        WHERE z.kali_id      = kal.id
                          AND z.prac_id      = kal.prac_id
                          AND kal.typ_dnia   IN ('N', 'S')
                   )
               AND kal.dzien_mies BETWEEN sysdate - 30 AND sysdate + 30
               AND kal.dzien_mies < pa_standard.ostatni_dzien_roku(sysdate)
               AND kal.prac_id    = rec.prac_id
               AND ROWNUM        <= 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_kali_id := NULL;
        END;

        -- nadpisz tylko pola rozniace sie od rekordu zrodlowego
        src_rec.id                := v_new_id;
        src_rec.uzasadnienie      := 'benefit niedziela i swieto';
        src_rec.kali_id           := v_kali_id;
        src_rec.payment_only      := 'N';
        src_rec.day_off_in_lieu   := rec.day_off_in_lieu;
        src_rec.hours_off_in_lieu := rec.hours_off_in_lieu;
        -- pozostale pola hardcoded z oryginalu — uzupelnij wlasciwe nazwy kolumn:
        -- src_rec.<kolumna_poz_9>  := NULL;
        -- src_rec.<utw_przez>      := 'ARLA (unknown)';
        -- src_rec.<kolumna_poz_13> := NULL;
        -- src_rec.<settled>        := 'T';
        src_rec.guid             := SYS_GUID();   -- nowy GUID — wymagany przez KP_RCZP_GUID_UK
        -- src_rec.<typ_nadg>       := '02';

        INSERT INTO kp_rcp_zlec_nadg_prac
        VALUES src_rec;

        INSERT INTO kp_rcp_zlec_nadg_prac_benefity
        VALUES ( kp_rcp_zlec_nadg_prac_benefity_seq.nextval, rec.ov_id );

        COMMIT;

    END LOOP;
END;
/


-- ============================================================
-- BLOK 2 : Zmiana payment_only — pojedynczy UPDATE bez kursora
-- ============================================================
BEGIN

    UPDATE kp_rcp_zlec_nadg_prac ov
       SET ov.payment_only  = 'N'
     WHERE ov.day_off_in_lieu = 'T'
       AND ov.settled         = 'N'
       AND ov.payment_only    = 'T'
       AND sysdate           >= ov.data - 60
       AND ov.czas            = 8
       AND EXISTS (
               SELECT 1
                 FROM t_kal_i ka
                WHERE ka.id  = ov.kali_id
                  AND ka.typ = 'S'
           )
       AND EXISTS (
               SELECT 1
                 FROM t_prac prac
                WHERE prac.prac_id  = ov.prac_id
                  AND prac.firm_id  = 100
           );

    COMMIT;

END;
/
