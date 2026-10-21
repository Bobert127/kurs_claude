CREATE OR REPLACE TRIGGER OPTEAM_CHECK_EMPLOYEE_WORK_DATE
BEFORE INSERT OR UPDATE ON KP_RCP_OVERTIME_AND_TOIL_REQ
FOR EACH ROW
DECLARE
    v_czas_nom    nt_kp_kdr_kalendarze_prac.czas_nom%TYPE;
    v_czas_zlec   NUMBER;
    v_exclude_id  KP_RCP_OVERTIME_AND_TOIL_REQ.ID%TYPE;
BEGIN
    IF :NEW.rczn_id = 16 THEN

        IF UPDATING THEN
            v_exclude_id := :NEW.ID;
        ELSE
            v_exclude_id := NULL;
        END IF;

        SELECT NVL(MAX(k.czas_nom), 0)
        INTO v_czas_nom
        FROM nt_kp_kdr_kalendarze_prac k
        WHERE k.prac_id = :NEW.prac_id
        AND trunc(k.dzien_mies) = trunc(:NEW.CALENDAR_DATE);

        SELECT NVL(SUM(ROUND((z.time_to - z.time_from) * 24, 2)), 0)
        INTO v_czas_zlec
        FROM KP_RCP_OVERTIME_AND_TOIL_REQ Z
        LEFT JOIN PA_WFL_DOC_ASSOCIATIONS DOAS ON Z.GUID = DOAS.DOCUMENT_GUID
        LEFT JOIN NT_PA_WFL_DOKUMENTY DOKU ON DOKU.ID = DOAS.DOKU_ID
        WHERE Z.PRAC_ID = :NEW.PRAC_ID
        AND z.rczn_id = 16
        AND trunc(z.calendar_date) = trunc(:NEW.calendar_date)
        AND (v_exclude_id IS NULL OR Z.ID <> v_exclude_id)
        AND (DOKU.WFL_STDO_KOD IS NULL OR DOKU.WFL_STDO_KOD <> 'U4T_WITHDRAWN_TG');

        IF (ROUND((:NEW.time_to - :NEW.time_from) * 24, 2) + ROUND(v_czas_nom / 3600, 2)) + v_czas_zlec > 13 THEN
            IF pa_sesje.biezacy_jezyk = 'en' THEN
                RAISE_APPLICATION_ERROR(-20001, 'OPTEAM: The total working time during the day (request + scheduled working hours from the calendar) exceeds 13 hours');
            ELSE
                RAISE_APPLICATION_ERROR(-20001, 'OPTEAM: Łączny czas pracy w ciągu dnia (wniosek + norma z kalendarza) przekracza 13 godzin!');
            END IF;
        END IF;

    END IF;
END;
