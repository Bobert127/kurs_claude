-- ============================================================
-- ZAPYTANIE ZOPTYMALIZOWANE
-- INSERT uzywa %ROWTYPE — odporny na dodanie nowych kolumn.
-- ID nowego rekordu pochodzi wylacznie z kp_rczp_seq.nextval.
-- Pola zalezne od siebie (godz, approved) zapisane w zmiennych
-- pomocniczych przed nadpisaniem src_rec.
-- ============================================================
DECLARE
    src_rec                kp_rcp_zlec_nadg_prac%ROWTYPE;
    v_new_id               kp_rcp_zlec_nadg_prac.id%TYPE;
    v_godz_do_src          kp_rcp_zlec_nadg_prac.godz_do%TYPE;
    v_approved_time_to_src kp_rcp_zlec_nadg_prac.approved_time_to%TYPE;

    CURSOR c IS
        SELECT DISTINCT
               CASE WHEN ben.id IS NULL THEN ov.id END AS ov_id,
               ov.czas
          FROM nt_kp_kdr_kalendarze_prac        ka
             , t_prac                            prac
             , kp_rcp_zlec_nadg_prac             ov
          LEFT JOIN kp_rcp_zlec_nadg_prac_benefity ben
                 ON ben.ben_id = ov.id
         WHERE ov.kali_id        = ka.id
           AND ov.hours_off_in_lieu = 'T'
           AND ov.rczn_id        IN (31, 32)
           AND ka.typ_dnia       IS NULL
           AND ov.payment_only   = 'N'
           AND prac.prac_id      = ov.prac_id
        -- AND ov.id             = 11520
           AND prac.firm_id      = 100
           AND sysdate           >= ov.data - 60
           AND ( ov.uzasadnienie != 'benefit nadgodziny'
              OR ov.uzasadnienie IS NULL );

BEGIN
    FOR rec IN c LOOP

        CONTINUE WHEN rec.ov_id IS NULL;

        -- nowe ID z sekwencji pobrane przed skopiowaniem rekordu zrodlowego
        SELECT kp_rczp_seq.nextval
          INTO v_new_id
          FROM dual;

        -- jeden SELECT zamiast ~15 podzapytan do tego samego wiersza
        SELECT *
          INTO src_rec
          FROM kp_rcp_zlec_nadg_prac
         WHERE id = rec.ov_id;

        -- zapisz oryginalne wartosci przed nadpisaniem (zaleznosci miedzy polami)
        v_godz_do_src          := src_rec.godz_do;
        v_approved_time_to_src := src_rec.approved_time_to;

        -- nadpisz tylko pola rozniace sie od rekordu zrodlowego
        src_rec.id                    := v_new_id;
        src_rec.uzasadnienie          := 'benefit nadgodziny';
        src_rec.payment_only          := 'N';
        src_rec.godz_od               := v_godz_do_src;
        src_rec.godz_do               := v_godz_do_src + rec.czas / 2 / 24;
        src_rec.czas                  := src_rec.czas / 2;
        src_rec.approved_time_from    := v_approved_time_to_src;
        src_rec.approved_time_to      := v_approved_time_to_src + rec.czas / 2 / 24;
        src_rec.approved_hours        := src_rec.approved_hours / 2;
        src_rec.classified_seconds_01 := src_rec.classified_seconds_01 / 2;
        src_rec.classified_seconds_02 := src_rec.classified_seconds_02 / 2;
        src_rec.classified_seconds_03 := src_rec.classified_seconds_03 / 2;
        src_rec.classified_seconds_04 := src_rec.classified_seconds_04 / 2;
        src_rec.classified_seconds_05 := src_rec.classified_seconds_05 / 2;
        src_rec.classified_seconds_10 := src_rec.classified_seconds_10 / 2;
        src_rec.classified_seconds_11 := src_rec.classified_seconds_11 / 2;
        src_rec.classified_seconds_12 := src_rec.classified_seconds_12 / 2;
        src_rec.classified_seconds_20 := src_rec.classified_seconds_20 / 2;
        src_rec.classified_seconds_21 := src_rec.classified_seconds_21 / 2;
        src_rec.classified_seconds_24 := src_rec.classified_seconds_24 / 2;
        src_rec.classified_seconds_30 := src_rec.classified_seconds_30 / 2;
        src_rec.classified_seconds_31 := src_rec.classified_seconds_31 / 2;
        src_rec.classified_seconds_32 := src_rec.classified_seconds_32 / 2;
        src_rec.classified_seconds_33 := src_rec.classified_seconds_33 / 2;
        src_rec.classified_seconds_34 := src_rec.classified_seconds_34 / 2;
        src_rec.classified_seconds_35 := src_rec.classified_seconds_35 / 2;
        src_rec.classified_seconds_36 := src_rec.classified_seconds_36 / 2;
        src_rec.guid                  := SYS_GUID();
        -- pozostale pola hardcoded z oryginalu — uzupelnij wlasciwe nazwy kolumn:
        -- src_rec.<kolumna_poz_9>  := NULL;
        -- src_rec.<utw_przez>      := 'ARLA (unknown)';
        -- src_rec.<kolumna_poz_13> := NULL;
        -- src_rec.<settled>        := 'T';
        -- src_rec.<typ_nadg>       := '02';

        INSERT INTO kp_rcp_zlec_nadg_prac
        VALUES src_rec;

        INSERT INTO kp_rcp_zlec_nadg_prac_benefity
        VALUES ( kp_rcp_zlec_nadg_prac_benefity_seq.nextval, rec.ov_id );

        COMMIT;

    END LOOP;
END;
/
