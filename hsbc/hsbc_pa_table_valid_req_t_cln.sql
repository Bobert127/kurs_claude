create or replace TYPE BODY pa_table_valid_req_t_cln AS

  OVERRIDING MEMBER PROCEDURE validate_row
  (
    p_id             IN NUMBER,
    p_table_name     IN VARCHAR2,
    p_action_area    IN VARCHAR2,
    po_error_message OUT VARCHAR2
  ) IS

    v_language VARCHAR2(10);

    ------------------------------------------------------------------
    -- KP_RCP_WORKTIME_EVENT_REQUESTS
    ------------------------------------------------------------------
    v_wtet_id            KP_RCP_WORKTIME_EVENT_REQUESTS.wtet_id%TYPE;
    v_workday_date_from  KP_RCP_WORKTIME_EVENT_REQUESTS.workday_date_from%TYPE;
    v_workday_date_to    KP_RCP_WORKTIME_EVENT_REQUESTS.workday_date_to%TYPE;
    v_mpk_id             KP_RCP_WORKTIME_EVENT_REQUESTS.mpk_id%TYPE;
    v_prac_id_wter       KP_RCP_WORKTIME_EVENT_REQUESTS.prac_id%TYPE;
    v_document_date      KP_RCP_WORKTIME_EVENT_REQUESTS.document_date%TYPE;
    v_start_date_time    KP_RCP_WORKTIME_EVENT_REQUESTS.start_date_time%TYPE;
    v_end_date_time      KP_RCP_WORKTIME_EVENT_REQUESTS.end_date_time%TYPE;
    v_is_hourly          KP_RCP_WORKTIME_EVENT_REQUESTS.is_hourly%TYPE;
    v_kup_date_od        L_DOD.data_od%TYPE;
    v_kup_date_do        L_DOD.data_do%TYPE;
    v_id_dws            KP_RCP_WORK_TIME_EVENT_TYPES.id%TYPE; --ADYRKA
    v_id_dws_korekta    KP_RCP_WORK_TIME_EVENT_TYPES.id%TYPE; --ADYRKA

    ------------------------------------------------------------------
    -- KP_RCP_WORK_TIME_EVENTS
    ------------------------------------------------------------------
    v_workday_date_lv   KP_RCP_WORK_TIME_EVENTS.WORKDAY_DATE%TYPE;

    ------------------------------------------------------------------
    -- KP_REQ_DECLARATION_REQUESTS
    ------------------------------------------------------------------
    v_decl_id      KP_REQ_DECLARATION_REQUESTS.decl_id%TYPE;
    v_prac_id      KP_REQ_DECLARATION_REQUESTS.prac_id%TYPE;
    v_date_from    KP_REQ_DECLARATION_REQUESTS.date_from%TYPE;
    v_date_to      KP_REQ_DECLARATION_REQUESTS.date_to%TYPE;
    v_dean_id      KP_REQ_DECLARATION_REQUESTS.dean_id%TYPE;

    v_data_rozw    T_PRAC.data_rozw%TYPE;
    v_pierwszy_dzien_biezacego_mies DATE;
    v_pierwszy_dzien_kolejnego_mies DATE;

    v_akcja              NUMBER;
    v_gs_nazwa           VARCHAR2(100);
    v_data_do            DATE;
    v_nast_nazwa         VARCHAR2(100);
    v_nowa_nazwa         VARCHAR2(100);
    v_nowa_nast_nazwa    VARCHAR2(100);
    v_nowa_nast_data_do  DATE;

    v_found              BOOLEAN := FALSE;
    v_istnieje_kalendarz CHAR(1);
    v_liczba_wpisow      NUMBER;

    ------------------------------------------------------------------
    -- KP_RCP_OVERTIME_AND_TOIL_REQ
    ------------------------------------------------------------------
    v_ot_request_type   KP_RCP_OVERTIME_AND_TOIL_REQ.request_type%TYPE;
    v_ot_prac_id        KP_RCP_OVERTIME_AND_TOIL_REQ.prac_id%TYPE;
    v_ot_calendar_date  KP_RCP_OVERTIME_AND_TOIL_REQ.calendar_date%TYPE;
    v_ot_data_zn        DATE;
    v_ot_data_do        DATE;

    ------------------------------------------------------------------
    -- KP_REQ_REQUEST
    ------------------------------------------------------------------
    v_req_type              KP_REQ_REQUEST.type%TYPE;
    v_applicant_osby_id     KP_REQ_REQUEST.applicant_osby_id%TYPE;
    v_blocked               NUMBER;

    ------------------------------------------------------------------
    -- KP_L_KODY_UBEZP
    ------------------------------------------------------------------
    V_TYT_UBEZP_NIEPELN_ID   KP_L_KODY_UBEZP.TYT_UBEZP_NIEPELN_ID%TYPE;

    ------------------------------------------------------------------
    -- KP_KDR_EMPL_DECLARATIONS
    ------------------------------------------------------------------
    v_oswiadczenie      KP_KDR_EMPL_DECLARATIONS.ID%TYPE;

    ------------------------------------------------------------------
     -- KP_RCP_LEAVE_REQUESTS
    ------------------------------------------------------------------
    v_data_od_a         KP_RCP_LEAVE_REQUESTS.DATE_FROM%TYPE;
    v_data_do_a         KP_RCP_LEAVE_REQUESTS.DATE_TO%TYPE;

    ------------------------------------------------------------------
    -- KP_REQ_HR_REQUESTS
    ------------------------------------------------------------------
    CURSOR c_hr_req IS
      SELECT * FROM kp_req_hr_requests WHERE krrq_id = p_id;
    r_hrre kp_req_hr_requests%ROWTYPE;

    v_hrrc_id KP_REQ_HR_REQUESTS.hrrc_id%TYPE;
    v_subject KP_REQ_HR_REQUESTS.subject%TYPE;

    v_pos1      PLS_INTEGER;
    v_pos2      PLS_INTEGER;
    v_pos3      PLS_INTEGER;
    v_nr        VARCHAR2(50);
    v_data_txt  VARCHAR2(50);
    v_od_txt    VARCHAR2(50);
    v_do_txt    VARCHAR2(50);
    v_data      DATE;
    v_data_min  DATE;
    v_data_max  DATE;

    PROCEDURE set_error
    (
      p_msg_pl IN VARCHAR2,
      p_msg_en IN VARCHAR2
    ) IS
    BEGIN
      IF v_language = 'en' THEN
        po_error_message := p_msg_en;
      ELSIF v_language = 'pl' THEN
        po_error_message := p_msg_pl;
      ELSE
        po_error_message := p_msg_pl;
      END IF;
    END;

  BEGIN
    po_error_message := NULL;

    BEGIN
      v_language := pa_sesje.biezacy_jezyk;
    EXCEPTION
      WHEN OTHERS THEN
        v_language := 'pl';
    END;

    ------------------------------------------------------------------
    -- KP_REQ_HR_REQUESTS
    ------------------------------------------------------------------
    IF p_action_area = 'HrRequestDetail' THEN

      OPEN c_hr_req;
      FETCH c_hr_req INTO r_hrre;

      IF c_hr_req%FOUND THEN

        v_hrrc_id := r_hrre.hrrc_id;
        v_subject := r_hrre.subject;

        IF v_subject IS NULL THEN
          set_error(
            p_msg_pl => 'Pole TEMAT jest wymagane.',
            p_msg_en => 'The SUBJECT field is required.'
          );
          CLOSE c_hr_req;
          RETURN;
        END IF;

        IF v_hrrc_id = 65 THEN
          v_pos1 := INSTR(v_subject, ';');

          IF v_pos1 = 0 OR INSTR(v_subject, ';', v_pos1 + 1) > 0 THEN
            set_error(
              p_msg_pl => 'Nieprawidłowy format. Wymagany: 00001234;2025-12',
              p_msg_en => 'Invalid format. Required: 00001234;2025-12'
            );
            CLOSE c_hr_req;
            RETURN;
          END IF;

          v_nr       := SUBSTR(v_subject, 1, v_pos1 - 1);
          v_data_txt := SUBSTR(v_subject, v_pos1 + 1);

          IF NOT REGEXP_LIKE(v_nr, '^[0-9]{8}$') THEN
            set_error(
              p_msg_pl => 'Numer musi mieć dokładnie 8 cyfr, np. 00001234.',
              p_msg_en => 'The number must be exactly 8 digits, e.g., 00001234.'
            );
            CLOSE c_hr_req;
            RETURN;
          END IF;

          IF NOT REGEXP_LIKE(v_data_txt, '^[0-9]{4}-[0-9]{2}$') THEN
            set_error(
              p_msg_pl => 'Nieprawidłowy format daty. Wymagany: RRRR-MM, np. 2025-12.',
              p_msg_en => 'Invalid date format. Required: YYYY-MM, e.g., 2025-12.'
            );
            CLOSE c_hr_req;
            RETURN;
          END IF;

          BEGIN
            v_data := TO_DATE(v_data_txt || '-01', 'YYYY-MM-DD');
          EXCEPTION
            WHEN OTHERS THEN
              set_error(
                p_msg_pl => 'Podana data jest nieprawidłowa.',
                p_msg_en => 'The provided date is invalid.'
              );
              CLOSE c_hr_req;
              RETURN;
          END;

          v_data_min := TRUNC(ADD_MONTHS(SYSDATE, -2), 'MM');
          v_data_max := TRUNC(SYSDATE, 'MM');

        ELSE
          v_pos1 := INSTR(v_subject, ';');
          v_pos2 := INSTR(v_subject, ';', v_pos1 + 1);
          v_pos3 := INSTR(v_subject, ';', v_pos2 + 1);

          IF v_pos1 = 0 OR v_pos2 = 0 OR v_pos3 = 0 OR INSTR(v_subject, ';', v_pos3 + 1) > 0 THEN
            set_error(
              p_msg_pl => 'Nieprawidłowy format. Wymagany: NR_EW;RRRR-MM-DD;GG:MM;GG:MM',
              p_msg_en => 'Invalid format. Required: ID_NUM;YYYY-MM-DD;HH:MI;HH:MI'
            );
            CLOSE c_hr_req;
            RETURN;
          END IF;

          v_nr       := SUBSTR(v_subject, 1, v_pos1 - 1);
          v_data_txt := SUBSTR(v_subject, v_pos1 + 1, v_pos2 - v_pos1 - 1);
          v_od_txt   := SUBSTR(v_subject, v_pos2 + 1, v_pos3 - v_pos2 - 1);
          v_do_txt   := SUBSTR(v_subject, v_pos3 + 1);

          IF NOT REGEXP_LIKE(v_nr, '^[0-9]{8}$') THEN
            set_error(
              p_msg_pl => 'Numer musi mieć 8 cyfr.',
              p_msg_en => 'The number must have 8 digits.'
            );
            CLOSE c_hr_req;
            RETURN;
          END IF;

          BEGIN
            v_data := TO_DATE(v_data_txt, 'YYYY-MM-DD');
          EXCEPTION
            WHEN OTHERS THEN
              set_error(
                p_msg_pl => 'Błędna data. Wymagany format RRRR-MM-DD.',
                p_msg_en => 'Invalid date. Required format: YYYY-MM-DD.'
              );
              CLOSE c_hr_req;
              RETURN;
          END;

          IF NOT REGEXP_LIKE(v_od_txt, '^([01][0-9]|2[0-3]):[0-5][0-9]$')
             OR NOT REGEXP_LIKE(v_do_txt, '^([01][0-9]|2[0-3]):[0-5][0-9]$') THEN
            set_error(
              p_msg_pl => 'Błędny format godzin GG:MM.',
              p_msg_en => 'Invalid time format HH:MI.'
            );
            CLOSE c_hr_req;
            RETURN;
          END IF;

          v_data_min := TRUNC(ADD_MONTHS(SYSDATE, -5), 'MM');
          v_data_max := LAST_DAY(ADD_MONTHS(SYSDATE, -3));
        END IF;

        IF v_data < v_data_min OR v_data > v_data_max THEN
          set_error(
            p_msg_pl => 'Data poza dozwolonym okresem. Wprowadzono: ' || v_data_txt || '. ' ||
                       'Dozwolony zakres od: ' || TO_CHAR(v_data_min, 'YYYY-MM') || ' do: ' || TO_CHAR(v_data_max, 'YYYY-MM') || '.',
            p_msg_en => 'Date out of allowed range. Entered: ' || v_data_txt || '. ' ||
                       'Allowed range from: ' || TO_CHAR(v_data_min, 'YYYY-MM') || ' to: ' || TO_CHAR(v_data_max, 'YYYY-MM') || '.'
          );
          CLOSE c_hr_req;
          RETURN;
        END IF;

      END IF;

      CLOSE c_hr_req;
      RETURN;

    END IF;

    ------------------------------------------------------------------
    -- KP_RCP_WORKTIME_EVENT_REQUESTS
    ------------------------------------------------------------------
    IF UPPER(p_table_name) = 'KP_RCP_WORKTIME_EVENT_REQUESTS' THEN

      BEGIN
        SELECT wtet_id,
               workday_date_from,
               workday_date_to,
               mpk_id,
               prac_id,
               document_date,
               start_date_time,
               end_date_time,
               is_hourly
          INTO v_wtet_id,
               v_workday_date_from,
               v_workday_date_to,
               v_mpk_id,
               v_prac_id_wter,
               v_document_date,
               v_start_date_time,
               v_end_date_time,
               v_is_hourly
          FROM KP_RCP_WORKTIME_EVENT_REQUESTS
         WHERE id = p_id;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          RETURN;
      END;

      BEGIN --ADYRKA
        SELECT id
        INTO v_id_dws
        FROM KP_RCP_WORK_TIME_EVENT_TYPES where code = (select KOLUMNA2 from oe_pozycje_grupy where grob_id = 249 and kolumna1 = 'KOD DWŚ' );
          EXCEPTION
          WHEN NO_DATA_FOUND THEN
          RETURN;
      END;

      BEGIN --ADYRKA
        SELECT id
        INTO v_id_dws_korekta
        FROM KP_RCP_WORK_TIME_EVENT_TYPES where code = (select KOLUMNA2 from oe_pozycje_grupy where grob_id = 249 and kolumna1 = 'KOD KOREKTY DWŚ' );
          EXCEPTION
          WHEN NO_DATA_FOUND THEN
          RETURN;
      END;

         BEGIN --RTRZ
            select n.TYT_UBEZP_NIEPELN_ID
            INTO V_TYT_UBEZP_NIEPELN_ID
            from KP_L_KODY_UBEZP n
            where n.data_od <= SYSDATE
            AND (n.data_do IS NULL OR n.data_do >= SYSDATE)
            and n.TYT_UBEZP_NIEPELN_ID > 0
            AND N.PRAC_ID = v_prac_id_wter;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            V_TYT_UBEZP_NIEPELN_ID := 0;
          END;

         BEGIN --RTRZ
            select o.ID
            into v_oswiadczenie
            from KP_KDR_EMPL_DECLARATIONS o, KP_KDR_EMPL_DECL_PERIODS d, KP_SLO_DECLARATION_ANSWERS a
            where o.decl_id = 7
            and o.id = d.edec_id
            and d.date_from <= SYSDATE
            AND (d.date_to IS NULL OR d.date_to >= SYSDATE)
            AND A.DECL_ID = O.DECL_ID
            AND A.CODE = 'T'
            AND O.PRAC_ID = v_prac_id_wter;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_oswiadczenie := 0;
          END;

      ------------------------------------------------------------------
      -- wtet_id = 18
      ------------------------------------------------------------------

        IF v_wtet_id = 18 AND V_TYT_UBEZP_NIEPELN_ID IN (2,3,4,5) AND v_oswiadczenie = 0
            THEN
            set_error(
                p_msg_pl => 'W związku z brakiem zgody na pracę w godzinach nadliczbowych niemożliwa jest ewidencja dyżuru',
                p_msg_en => 'In the absence of approval for overtime work, the on-call duty cannot be recorded in the working time records'
            );
        END IF;

      ------------------------------------------------------------------
      -- wtet_id = 13
      ------------------------------------------------------------------
      IF v_wtet_id = 13 THEN

        IF v_workday_date_to IS NOT NULL
           AND TRUNC(v_workday_date_to) > LAST_DAY(TRUNC(SYSDATE)) THEN
          set_error(
            p_msg_pl => 'HSBC: Data "Koniec" musi być mniejsza lub równa końcowi bieżącego miesiąca!',
            p_msg_en => 'HSBC: "Date to" date must be less than or equal to the end of the current month!'
          );
          RETURN;
        END IF;

        IF v_workday_date_from IS NOT NULL
           AND v_workday_date_to IS NOT NULL THEN

          IF TRUNC(v_workday_date_to, 'MM') <> TRUNC(v_workday_date_from, 'MM') THEN
            set_error(
              p_msg_pl => 'HSBC: Data "Koniec" musi znajdować się w tym samym miesiącu kalendarzowym co data "Początek"!',
              p_msg_en => 'HSBC: "Date to" must be within the same calendar month as "Date from"!'
            );
            RETURN;
          END IF;

        END IF;
      END IF;

      ------------------------------------------------------------------
      -- wtet_id IN (22, 25) — KUP / prace twórcze
      ------------------------------------------------------------------
      IF v_wtet_id IN (22, 25) THEN

        BEGIN
          SELECT data_od, data_do
            INTO v_kup_date_od, v_kup_date_do
            FROM L_DOD
           WHERE prac_id = v_prac_id_wter
             AND dod_id  = 10082
             AND data_od <= SYSDATE
             AND (data_do IS NULL OR data_do >= SYSDATE);
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_kup_date_od := NULL;
            v_kup_date_do := NULL;
        END;

        IF v_wtet_id = 22 AND v_kup_date_od IS NULL THEN
          set_error(
            p_msg_pl => 'HSBC: Nie jesteś uprawniony do ewidencjonowania pracy twórczej. Zapoznaj się z materiałami w HRDirect (Structure of author costs Regulations) i skonsultuj temat z przełożonym',
            p_msg_en => 'HSBC: You are not authorized to record creative work. Please read the information available in HRDirect (Structure of author costs Regulations) and verify the case with your manager'
          );
          RETURN;
        END IF;

        IF v_wtet_id = 25 AND v_kup_date_od IS NOT NULL THEN

          IF v_workday_date_from IS NOT NULL
             AND v_workday_date_from <= v_kup_date_od THEN
            set_error(
              p_msg_pl => 'HSBC: Data początku zgłoszenia nie może być wcześniejsza niż początek zgody na pracę twórczą',
              p_msg_en => 'HSBC: The start date of your submission cannot be earlier than the start date of the creative work agreement'
            );
            RETURN;
          END IF;

          IF v_kup_date_do IS NOT NULL
             AND v_workday_date_to IS NOT NULL
             AND v_workday_date_to >= v_kup_date_do THEN
            set_error(
              p_msg_pl => 'HSBC: Data "Koniec" musi być wcześniejsza niż koniec zgody na pracę twórczą (autorskie KUP)',
              p_msg_en => 'HSBC: The "End" date must be earlier than the end date of the consent for Creative work (author''s KUP)'
            );
            RETURN;
          END IF;

        END IF;

      END IF;

      ------------------------------------------------------------------
      -- wtet_id = 22 — Prace badawczo-rozwojowe
      ------------------------------------------------------------------
      IF v_wtet_id = 22 THEN

        IF v_mpk_id IS NULL
           OR v_mpk_id NOT IN (2328, 11012, 15854, 16392) THEN
          set_error(
            p_msg_pl => 'HSBC: Nie masz uprawnień do składania wniosku o Prace badawczo rozwojowe',
            p_msg_en => 'HSBC: You are not authorized to submit an application for Research and development work'
          );
          RETURN;
        END IF;

        DECLARE
          v_emp_mpk_code VARCHAR2(50);
        BEGIN
          v_emp_mpk_code := akt_dane.mpk(v_prac_id_wter, SYSDATE);

          IF v_emp_mpk_code IS NULL
             OR v_emp_mpk_code NOT IN ('4WR7509811', '5000000835', '5000000417', '9098140301', '5000000696') THEN
            set_error(
              p_msg_pl => 'HSBC: Nie masz uprawnień do składniania Prac badawczo rozwojowych!',
              p_msg_en => 'HSBC: You are not authorized to submit Research and Development Works'
            );
            RETURN;
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            set_error(
              p_msg_pl => 'HSBC: Błąd weryfikacji uprawnień MPK. Skontaktuj się z działem HR.',
              p_msg_en => 'HSBC: MPK authorization check failed. Please contact the HR Department.'
            );
            RETURN;
        END;

        IF v_workday_date_to IS NOT NULL
           AND v_workday_date_to > LAST_DAY(SYSDATE) THEN
          set_error(
            p_msg_pl => 'HSBC: Data końca zgłoszenia nie może przekraczać bieżącego miesiąca',
            p_msg_en => 'HSBC: The end date of your submission cannot exceed the current month'
          );
          RETURN;
        END IF;

--        IF v_document_date IS NOT NULL
--           AND v_workday_date_to IS NOT NULL
--           AND v_document_date > LAST_DAY(v_workday_date_to) + 4 THEN
--          set_error(
--            p_msg_pl => 'HSBC: Brak możliwości akceptacji wniosku, przekroczony termin na akceptację',
--            p_msg_en => 'HSBC: Acceptance not possible, deadline for acceptance has been exceeded'
--          );
--          RETURN;
--        END IF;

      END IF;

      ------------------------------------------------------------------
      -- wtet_id IN (29, 32) — DW za 01.11.2025 / korekta
      -- TODO: Wyłączone 2026-04-24. Walidacja dotyczy święta 01.11.2025
      --       i korekty w grudniu 2025.
      --       Kod pozostaje jako szablon na przyszłe miesiące (daty i warunki
      --       wymagają aktualizacji przed ponownym włączeniem).
      ------------------------------------------------------------------
        -- WALIDATORY DWŚ - ADYRKA

      IF v_wtet_id IN (v_id_dws, v_id_dws_korekta) THEN

        DECLARE
          v_prac_id_loc      KP_RCP_WORKTIME_EVENT_REQUESTS.prac_id%TYPE;
          v_start_dt         KP_RCP_WORKTIME_EVENT_REQUESTS.start_date_time%TYPE;
          v_end_dt           KP_RCP_WORKTIME_EVENT_REQUESTS.end_date_time%TYPE;

          v_okres_rozl        KP_RCP_OKRESY_BILANSU.dlugosc%TYPE;
          v_data_zatr         T_PRAC.data_zatr%TYPE;
          v_data_rozw_loc     T_PRAC.data_rozw%TYPE;

          v_typ_dnia          HRK_HARMONOGRAMY_PRAC_KLN.typ%TYPE;
          v_godz_od           HRK_HARMONOGRAMY_PRAC_KLN.godz_od%TYPE;
          v_godz_do           HRK_HARMONOGRAMY_PRAC_KLN.godz_do%TYPE;

          v_dzien_swieta      DATE; --ADYRKA
          v_firm_dw           DATE; --ADYRKA
          v_data_startu_odb   DATE; --ADYRKA
          v_data_konca_odb    DATE; --ADYRKA
          v_dws_wystawione      NUMBER; --ADYRKA
          v_dws_wystawione_kor  NUMBER; --ADYRKA
          v_nazwa_mies_pl       t_prac.t_01%TYPE;
          v_nazwa_mies_en       t_prac.t_01%TYPE;
          v_nazwa_wniosku_pl    t_prac.t_01%TYPE;
          v_nazwa_wniosku_en    t_prac.t_01%TYPE;
          v_nazwa_korekty_pl    t_prac.t_01%TYPE;
          v_nazwa_korekty_en    t_prac.t_01%TYPE;
          v_miesiac_swieta      t_prac.n_01%TYPE;

        BEGIN
          v_prac_id_loc := v_prac_id_wter;
          v_start_dt    := v_start_date_time;
          v_end_dt      := v_end_date_time;

          IF v_start_dt IS NULL OR v_end_dt IS NULL THEN
            RETURN;
          END IF;


      BEGIN --ADYRKA
        SELECT  kolumna6 v_dzien_swieta,
                EXTRACT(MONTH FROM kolumna6) v_miesiac_swieta,
                TO_CHAR(kolumna6, 'Month', 'NLS_DATE_LANGUAGE = ENGLISH') v_nazwa_mies_en,
                CASE EXTRACT(MONTH FROM kolumna6)
                  WHEN 1 THEN 'w styczniu'
                  WHEN 2 THEN 'w lutym'
                  WHEN 3 THEN 'w marcu'
                  WHEN 4 THEN 'w kwietniu'
                  WHEN 5 THEN 'w maju'
                  WHEN 6 THEN 'w czerwcu'
                  WHEN 7 THEN 'w lipcu'
                  WHEN 8 THEN 'w sierpniu'
                  WHEN 9 THEN 'we wrześniu'
                  WHEN 10 THEN 'w październiku'
                  WHEN 11 THEN 'w listopadzie'
                  WHEN 12 THEN 'w grudniu'
                END v_nazwa_mies_pl
        INTO v_dzien_swieta, v_miesiac_swieta, v_nazwa_mies_en, v_nazwa_mies_pl
        FROM oe_pozycje_grupy where grob_id = 249 and kolumna1 = 'DZIEŃ ŚWIĘTA';
          EXCEPTION
          WHEN NO_DATA_FOUND THEN
          RETURN;
      END;

      BEGIN --ADYRKA
        SELECT kolumna6
        INTO  v_firm_dw
        FROM oe_pozycje_grupy where grob_id = 249 and kolumna1 = 'DW_WZORCOWY';
          EXCEPTION
          WHEN NO_DATA_FOUND THEN
          RETURN;
      END;

      BEGIN --ADYRKA
        SELECT kolumna6, kolumna7
        INTO v_data_startu_odb, v_data_konca_odb
        FROM oe_pozycje_grupy where grob_id = 249 and kolumna1 = 'OKRES';
          EXCEPTION
          WHEN NO_DATA_FOUND THEN
          RETURN;
      END;

      BEGIN --ADYRKA
        SELECT name, name_en
        INTO v_nazwa_wniosku_pl, v_nazwa_wniosku_en
        FROM KP_RCP_WORK_TIME_EVENT_TYPES where code = (select KOLUMNA2 from oe_pozycje_grupy where grob_id = 249 and kolumna1 = 'KOD DWŚ' );
          EXCEPTION
          WHEN NO_DATA_FOUND THEN
          RETURN;
      END;

      BEGIN --ADYRKA
        SELECT name, name_en
        INTO v_nazwa_korekty_pl, v_nazwa_korekty_en
        FROM KP_RCP_WORK_TIME_EVENT_TYPES where code = (select KOLUMNA2 from oe_pozycje_grupy where grob_id = 249 and kolumna1 = 'KOD KOREKTY DWŚ' );
          EXCEPTION
          WHEN NO_DATA_FOUND THEN
          RETURN;
      END;

          BEGIN --ADYRKA
            SELECT CASE WHEN rcok.rodzaj = 'M' THEN rcok.dlugosc ELSE 1 END
              INTO v_okres_rozl
              FROM KP_RCP_EMPLOYEE_WOTS ewo, KP_RCP_WORKING_TIME_SYSTEMS wots, KP_RCP_OKRESY_BILANSU rcok
             WHERE ewo.prac_id = v_prac_id_loc
               AND V_FIRM_DW BETWEEN ewo.date_from AND NVL(ewo.date_to, DATE '2099-12-31')
               AND ewo.wots_id = wots.id
               AND wots.rcok_id = rcok.id;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_okres_rozl := NULL;
          END;

          BEGIN
            SELECT data_zatr, data_rozw
              INTO v_data_zatr, v_data_rozw_loc
              FROM t_prac
             WHERE prac_id = v_prac_id_loc;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_data_zatr := NULL;
              v_data_rozw_loc := NULL;
          END;

          BEGIN
            SELECT typ, godz_od, godz_do
              INTO v_typ_dnia, v_godz_od, v_godz_do
              FROM HRK_HARMONOGRAMY_PRAC_KLN
             WHERE prac_id = v_prac_id_loc
               AND TRUNC(kal_dzien_mies,'DD') = TRUNC(v_start_dt,'DD');
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_typ_dnia := NULL;
              v_godz_od := NULL;
              v_godz_do := NULL;
          END;
---
    SELECT --sprawdzamy czy byl wystawiony DWS
    (
        SELECT COUNT(*)
        FROM KP_RCP_WORK_TIME_EVENTS
        WHERE wtet_id = v_id_dws
          AND prac_id = v_prac_id_loc
          AND date_time_from BETWEEN v_data_startu_odb AND v_data_konca_odb
    )
    +
    (
        SELECT COUNT(*)
        FROM KP_RCP_WORKTIME_EVENT_REQUESTS
        WHERE wtet_id = v_id_dws
          AND prac_id = v_prac_id_loc
          AND start_date_time BETWEEN v_data_startu_odb AND v_data_konca_odb
          AND Pa_Wfl_Doku_Sql.Current_Document_State(p_document_guid=>GUID) <> 'U4T_WITHDRAWN_TG'
    )
    INTO v_dws_wystawione
    FROM dual;
---
    SELECT --KOREKTY DWS, sprawdzamy ile bylo wystawionych
    (
        SELECT COUNT(*)
        FROM KP_RCP_WORK_TIME_EVENTS
        WHERE wtet_id = v_id_dws_korekta
          AND prac_id = v_prac_id_loc
          AND date_time_from BETWEEN v_data_startu_odb AND v_data_konca_odb
    )
    +
    (
        SELECT COUNT(*)
        FROM KP_RCP_WORKTIME_EVENT_REQUESTS
        WHERE wtet_id = v_id_dws_korekta
          AND prac_id = v_prac_id_loc
          AND start_date_time BETWEEN v_data_startu_odb AND v_data_konca_odb
          AND Pa_Wfl_Doku_Sql.Current_Document_State(p_document_guid=>GUID) <> 'U4T_WITHDRAWN_TG'
    )
    INTO v_dws_wystawione_kor
    FROM dual;
---
------------------------------WLASCIWE WALIDATORY

          IF v_wtet_id in (v_id_dws, v_id_dws_korekta)
          AND (v_okres_rozl IS NULL OR TO_CHAR(v_okres_rozl) = '1')
          AND EXTRACT(MONTH FROM v_start_dt) <> v_miesiac_swieta THEN
            set_error( --1
              p_msg_pl => 'HSBC:  Masz 1-miesięczny okres rozliczeniowy. Wolne za 15.08.2026 możesz odebrać jedynie w sierpniu.',
              p_msg_en => 'HSBC:  You have a one-month settlement period. You can only collect your time off from 15/08/2026, in August.'
            );
            RETURN;
          END IF;

          IF v_wtet_id in (v_id_dws, v_id_dws_korekta) AND v_typ_dnia IS NULL and (TO_CHAR(v_start_dt,'HH24:MI') <> v_godz_od OR TO_CHAR(v_end_dt,'HH24:MI') <> v_godz_do) THEN
            set_error( --2  --BO musi byc dokladnie w godzinach pracy i na caly dzien pracy
              p_msg_pl => 'HSBC: Zgłoszenie nie może wykraczać poza godziny pracy (od ' || v_godz_od || ' do ' || v_godz_do || ').',
              p_msg_en => 'HSBC: Your request can not exceed scheduled working hours (from ' || v_godz_od || ' to ' || v_godz_do || ').'
            );
            RETURN;
          END IF;

          IF v_wtet_id in (v_id_dws, v_id_dws_korekta) AND v_typ_dnia IS NOT NULL THEN --nowe parametry zdarzenia tez to powinny zabezpieczyc
            set_error( --3
              p_msg_pl => 'HSBC:  Ten dzień jest już twoim dniem wolnym.',
              p_msg_en => 'HSBC:  This day is now your day off.'
            );
            RETURN;
          END IF;

          IF v_wtet_id in (v_id_dws, v_id_dws_korekta) AND TRUNC(v_start_dt,'DD') <> TRUNC(v_end_dt,'DD') THEN --jednak same limity powinny tez to zabezpieczyc
            set_error( --4
              p_msg_pl => 'HSBC:   Data od i data do muszą być takie same.',
              p_msg_en => 'HSBC:   Date from and date to must be the same..'
            );
            RETURN;
          END IF;

          IF v_wtet_id in (v_id_dws, v_id_dws_korekta)  AND v_data_zatr IS NOT NULL AND v_data_zatr > v_dzien_swieta THEN --jednak same limity powinny tez to zabezpieczyc
            set_error( --5
              p_msg_pl => 'HSBC:  Nie przysługuje ci to wolne. Zostałeś zatrudniony po dacie święta.',
              p_msg_en => 'HSBC:  You are not entitled to this time off. You were hired after the holiday date.'
            );
            RETURN;
          END IF;

          IF v_wtet_id in (v_id_dws, v_id_dws_korekta) AND v_data_rozw_loc IS NOT NULL AND v_data_rozw_loc < v_start_dt THEN --jednak same limity powinny tez to zabezpieczyc
            set_error( --6
              p_msg_pl => 'HSBC:  Ten dzień wykracza poza datę twojego zatrudnienia.',
              p_msg_en => 'HSBC:  This date extends beyond your employment date.'
            );
            RETURN;
          END IF;

          IF v_wtet_id = v_id_dws AND (
               (EXTRACT(MONTH FROM v_start_dt) = 07 AND TRUNC(SYSDATE,'DD') > DATE '2026-07-19') OR
               (EXTRACT(MONTH FROM v_start_dt) = 08 AND TRUNC(SYSDATE,'DD') > DATE '2026-08-19') OR
               (EXTRACT(MONTH FROM v_start_dt) = 09 AND TRUNC(SYSDATE,'DD') > DATE '2026-08-19')
             ) THEN
            set_error( --7
              p_msg_pl => 'HSBC:  Wnioski "Dzień wolny za 15.08" na lipiec można składać do 19.07, wnioski na sierpień i wrzesień do 19.08.',
              p_msg_en => 'HSBC:  Applications "Day off in lieu of 15.08" for July can be submitted until July 19, applications for August & September until August 19.'
            );
            RETURN;
          END IF;

          IF v_wtet_id = v_id_dws_korekta and ( v_dws_wystawione is null or  v_dws_wystawione = 0) THEN
            set_error( --8
              p_msg_pl => 'HSBC:  Wystawienie korekty jest możliwe tylko jeżeli masz już wystawiony wniosek o Dzień wolny za 15.08.2026.',
              p_msg_en => 'HSBC:  Applications "Correction of a Day off in lieu of 15.08.2026" it is possible that you have already registered a request for a "Day off in lieu of 15.08.2026".'
            );
            RETURN;
          END IF;

          IF v_wtet_id = v_id_dws_korekta and ( v_dws_wystawione_kor > 1) THEN
            set_error( --9
              p_msg_pl => 'HSBC:  Możliwa jest tylko jedna korekta dnia wolnego.',
              p_msg_en => 'HSBC:  Only one correction to the day off is possible.'
            );
            RETURN;
          END IF;

          IF v_wtet_id = v_id_dws_korekta and TRUNC(SYSDATE,'DD') > DATE '2026-09-17' THEN
            set_error( --10
              p_msg_pl => 'HSBC:  Wystawienie korekty było możliwe tylko do 17.09.',
              p_msg_en => 'HSBC:  Applications "Correction of a Day off in lieu of 15.08.2026" can be submitted until September 17.'
            );
            RETURN;
          END IF;

          /*IF v_wtet_id = 32 AND (
                v_okres_rozl IS NULL
             OR TO_CHAR(v_okres_rozl) = '1'
             OR v_start_dt NOT BETWEEN DATE '2025-12-01' AND DATE '2025-12-31'
             OR v_dws_na_grudz = 0
            ) THEN
            set_error(
              p_msg_pl => 'HSBC: Korektę możesz złożyć, jeżeli: 1) masz 3-miesięczny okres rozliczeniowy, 2) i miałeś zatwierdzony wniosek o odbiór DW za 01.11. na grudzień, 3) i wnioskujesz o nową datę odbioru DW za 01.11. na grudzień.',
              p_msg_en => 'HSBC: You can make a correction if: 1) you have 3-months settlement period, 2) and you had approved previous request of Day off in lieu of 01.11 for December, 3) and you are requesting for a new day off in lieu od 01.11 in December.'
            );
            RETURN;
          END IF;*/

        END;

      END IF;

      ------------------------------------------------------------------
      -- wtet_id = 20 — karmienie piersią
      ------------------------------------------------------------------
      IF v_wtet_id = 20 THEN

        IF NVL(v_is_hourly, 'N') <> 'T' THEN
          set_error(
            p_msg_pl => 'HSBC: Zaznacz "Na kilka godzin" i uzupełnij godziny rozpoczęcia oraz zakończenia przerwy na karmienie.',
            p_msg_en => 'HSBC: Check "For a few hours" and fill in the start and end time of the breastfeeding break.'
          );
          RETURN;
        END IF;

        DECLARE
          v_bf_num_children VARCHAR2(10);
          v_bf_date_from    DATE;
          v_bf_date_to      DATE;
          v_bf_max_break    NUMBER;
          v_bf_has_decl     NUMBER;
          v_bf_found        BOOLEAN := FALSE;
        BEGIN

          BEGIN
            SELECT CASE WHEN an.code = 'T2' THEN 'D2'
                        WHEN an.code = 'T'  THEN 'D1'
                        ELSE NULL END,
                   od.date_from,
                   od.date_to
              INTO v_bf_num_children, v_bf_date_from, v_bf_date_to
              FROM KP_KDR_EMPL_DECLARATIONS oz
              JOIN KP_KDR_EMPL_DECL_PERIODS  od ON oz.id = od.edec_id
              JOIN KP_SLO_DECLARATION_ANSWERS an ON an.id = od.dean_id
             WHERE oz.decl_id = 1
               AND (od.date_to IS NULL OR od.date_to > v_start_date_time)
               AND od.date_from <= v_end_date_time
               AND oz.prac_id = v_prac_id_wter
               AND ROWNUM = 1;
            v_bf_found := TRUE;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_bf_found := FALSE;
          END;

          IF NOT v_bf_found THEN
            set_error(
              p_msg_pl => 'HSBC: Nie masz Oświadczenia o karmieniu piersią!',
              p_msg_en => 'HSBC: You do not have a Breastfeeding Statement!'
            );
            RETURN;
          END IF;

          IF v_bf_num_children = 'D1' THEN
            v_bf_max_break := 60;
          ELSIF v_bf_num_children = 'D2' THEN
            v_bf_max_break := 90;
          ELSE
            RETURN;
          END IF;

          BEGIN
            SELECT 1
              INTO v_bf_has_decl
              FROM KP_KDR_EMPL_DECLARATIONS oz
              JOIN KP_KDR_EMPL_DECL_PERIODS  od ON oz.id = od.edec_id
              JOIN KP_SLO_DECLARATION_ANSWERS an ON an.id = od.dean_id
             WHERE oz.decl_id = 1
               AND oz.prac_id = v_prac_id_wter
               AND ROWNUM = 1;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_bf_has_decl := NULL;
          END;

          IF v_bf_has_decl = 1 THEN
            IF v_workday_date_from > v_bf_date_from
               OR v_workday_date_to   < v_bf_date_to THEN

              IF v_start_date_time IS NOT NULL
                 AND v_end_date_time IS NOT NULL
                 AND ROUND((v_end_date_time - v_start_date_time) * 1440, 2) > v_bf_max_break THEN
                set_error(
                  p_msg_pl => 'HSBC: Przerwa na karmienie piersią nie może być dłuższa niż ' || v_bf_max_break || ' minut!',
                  p_msg_en => 'HSBC: The breastfeeding break cannot be longer than ' || v_bf_max_break || ' minutes!'
                );
                RETURN;
              END IF;
            END IF;
          END IF;

        END;
      END IF;

    ------------------------------------------------------------------
    -- KP_REQ_DECLARATION_REQUESTS
    ------------------------------------------------------------------
    ELSIF UPPER(p_table_name) = 'KP_REQ_DECLARATION_REQUESTS' THEN

      BEGIN
        SELECT decl_id,
               prac_id,
               date_from,
               date_to,
               dean_id
          INTO v_decl_id,
               v_prac_id,
               v_date_from,
               v_date_to,
               v_dean_id
          FROM KP_REQ_DECLARATION_REQUESTS
         WHERE id = p_id;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          RETURN;
      END;

      v_pierwszy_dzien_biezacego_mies := TRUNC(SYSDATE, 'MM');
      v_pierwszy_dzien_kolejnego_mies := ADD_MONTHS(v_pierwszy_dzien_biezacego_mies, 1);

      BEGIN
        SELECT data_rozw
          INTO v_data_rozw
          FROM t_prac
         WHERE prac_id = v_prac_id;

        IF v_decl_id = 301 THEN

          IF v_date_from <> v_pierwszy_dzien_kolejnego_mies THEN
            set_error(
              p_msg_pl => 'HSBCSD: Data "Obowiązuje od" musi być pierwszym dniem kolejnego miesiąca.',
              p_msg_en => 'HSBCSD: The "Valid from" date must be the first day of the next month.'
            );
            RETURN;
          END IF;

          IF v_date_to IS NOT NULL THEN
            set_error(
              p_msg_pl => 'HSBCSD: Pole "Obowiązuje do" musi pozostać puste.',
              p_msg_en => 'HSBCSD: The "Valid to" date must be empty.'
            );
            RETURN;
          END IF;

          SELECT COUNT(*)
            INTO v_liczba_wpisow
            FROM L_GR_CZ_PRACY
           WHERE PRAC_ID = v_prac_id
             AND DATA_OD > v_date_from;

          IF v_liczba_wpisow > 1 THEN
            set_error(
              p_msg_pl => 'HSBCSD1: Nie można przesłać wniosku z powodu błędu w grupach czasu pracy. Skontaktuj się z działem HR.',
              p_msg_en => 'HSBCSD1: The request cannot be submitted due to a work time group configuration error. Please contact the HR Department.'
            );
            RETURN;
          END IF;

          BEGIN
            SELECT
                gs.nazwa,
                g.data_do,
                (SELECT nazwa
                   FROM SL_GR_CZ
                  WHERE ID = AKT_DANE_ID.GR_CZ_PR(g.prac_id, g.data_do + 1)),
                (SELECT nazwa
                   FROM SL_GR_CZ
                  WHERE nazwa = SUBSTR(gs.nazwa, 1, INSTR(gs.nazwa, '_'))
                              || SUBSTR((SELECT name
                                           FROM KP_SLO_DECLARATION_ANSWERS
                                          WHERE ID = v_dean_id), -5)),
                (SELECT nazwa
                   FROM SL_GR_CZ
                  WHERE nazwa =
                        SUBSTR((SELECT nazwa
                                  FROM SL_GR_CZ
                                 WHERE ID = AKT_DANE_ID.GR_CZ_PR(g.prac_id, g.data_do + 1)),
                               1,
                               INSTR((SELECT nazwa
                                       FROM SL_GR_CZ
                                      WHERE ID = AKT_DANE_ID.GR_CZ_PR(g.prac_id, g.data_do + 1)),
                                     '_'))
                        || SUBSTR((SELECT name
                                     FROM KP_SLO_DECLARATION_ANSWERS
                                    WHERE ID = v_dean_id), -5)),
                (SELECT data_do
                   FROM L_GR_CZ_PRACY
                  WHERE PRAC_ID = g.prac_id
                    AND DATA_OD = g.data_do + 1)
              INTO
                v_gs_nazwa,
                v_data_do,
                v_nast_nazwa,
                v_nowa_nazwa,
                v_nowa_nast_nazwa,
                v_nowa_nast_data_do
              FROM T_PRAC t
              JOIN L_GR_CZ_PRACY g
                ON t.prac_id = g.prac_id
              JOIN SL_GR_CZ gs
                ON g.gr_cz_id = gs.id
             WHERE t.prac_id = v_prac_id
               AND v_date_from BETWEEN g.data_od AND NVL(g.data_do, v_date_from)
               AND ROWNUM = 1;

            v_found := TRUE;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_found := FALSE;
          END;

          IF NOT v_found THEN
            set_error(
              p_msg_pl => 'HSBCSD: Nie znaleziono danych grupy czasu pracy dla pracownika. Skontaktuj się z działem HR.',
              p_msg_en => 'HSBCSD: No work time group data found for this employee. Please contact the HR Department.'
            );
            RETURN;
          END IF;

          v_istnieje_kalendarz := KAL.ISTNIEJE_HARM_IND_W_OKRESIE_TN(
            p_prac_id => v_prac_id,
            p_data_od => v_date_from,
            p_data_do => LAST_DAY(ADD_MONTHS(TRUNC(v_date_from, 'YYYY'), 11))
          );

          IF v_istnieje_kalendarz = 'T' THEN
            set_error(
              p_msg_pl => 'HSBCSD: Nie można przesłać wniosku. Istnieje kalendarz indywidualny dla pracownika.',
              p_msg_en => 'HSBCSD: The request cannot be submitted because an individual calendar exists for this employee.'
            );
            RETURN;
          END IF;

          IF v_gs_nazwa = v_nowa_nazwa THEN
            set_error(
              p_msg_pl => 'HSBCSD: Nowa grupa czasu pracy jest taka sama jak aktualna. Nie można przesłać wniosku.',
              p_msg_en => 'HSBCSD: The new work time group is the same as the current one. The request cannot be submitted.'
            );
            RETURN;
          END IF;

          IF v_gs_nazwa IS NULL THEN
            v_akcja := 0;
          ELSIF v_gs_nazwa IS NOT NULL
             AND v_data_do IS NOT NULL
             AND v_nast_nazwa IS NOT NULL
             AND v_nowa_nazwa IS NOT NULL
             AND v_nowa_nast_nazwa IS NOT NULL
             AND v_nowa_nast_data_do IS NOT NULL THEN
            v_akcja := 4;
          ELSIF v_gs_nazwa IS NOT NULL
             AND v_data_do IS NULL
             AND v_nast_nazwa IS NULL
             AND v_nowa_nazwa IS NOT NULL THEN
            v_akcja := 1;
          ELSIF v_gs_nazwa IS NOT NULL
             AND v_data_do IS NOT NULL
             AND v_nast_nazwa IS NOT NULL
             AND v_nowa_nazwa IS NOT NULL
             AND v_nowa_nast_nazwa IS NOT NULL THEN
            v_akcja := 2;
          ELSIF v_gs_nazwa IS NOT NULL
             AND v_nast_nazwa IS NULL
             AND v_data_do > v_date_from
             AND v_nowa_nazwa IS NOT NULL THEN
            v_akcja := 3;
          ELSE
            v_akcja := 0;
          END IF;

          IF v_akcja = 0 THEN
            set_error(
              p_msg_pl => 'HSBCSD2: Nie można przesłać wniosku z powodu błędu w grupach czasu pracy. Skontaktuj się z działem HR.',
              p_msg_en => 'HSBCSD2: The request cannot be submitted due to a work time group configuration error. Please contact the HR Department.'
            );
            RETURN;
          END IF;

          IF v_data_rozw IS NOT NULL THEN
            set_error(
              p_msg_pl => 'HSBCSD: Nie można złożyć wniosku. Proszę skontaktować się z działem HR.',
              p_msg_en => 'HSBCSD: You cannot submit the request. Please contact HR Department.'
            );
            RETURN;
          END IF;

        END IF;

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          set_error(
            p_msg_pl => 'HSBCSD3: Nie można przesłać wniosku z powodu błędu w grupach czasu pracy. Skontaktuj się z działem HR.',
            p_msg_en => 'HSBCSD3: The request cannot be submitted due to a work time group configuration error. Please contact the HR Department.'
          );
          RETURN;
      END;

    ------------------------------------------------------------------
    -- KP_RCP_OVERTIME_AND_TOIL_REQ
    ------------------------------------------------------------------
    ELSIF UPPER(p_table_name) = 'KP_RCP_OVERTIME_AND_TOIL_REQ' THEN

      BEGIN
        SELECT request_type,
               prac_id,
               calendar_date
          INTO v_ot_request_type,
               v_ot_prac_id,
               v_ot_calendar_date
          FROM KP_RCP_OVERTIME_AND_TOIL_REQ
         WHERE id = p_id;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          RETURN;
      END;

      IF v_ot_request_type IN ('TO') THEN

        SELECT MAX(zn.data)
          INTO v_ot_data_zn
          FROM NT_KP_RCP_ZLECENIA_NADG zn
         WHERE zn.prac_id = v_ot_prac_id
           AND zn.settled = 'N'
           AND zn.payment_only = 'N'
           AND zn.classified_seconds_20 > 0;

        IF v_ot_data_zn IS NOT NULL THEN
          BEGIN
            SELECT CASE
                     WHEN MOD(ROUND(MONTHS_BETWEEN(LAST_DAY(k.dzien_mies), LAST_DAY(b.poczatek_cyklu)) + 1, 0), b.dlugosc) = 0
                       THEN LAST_DAY(v_ot_data_zn)
                     WHEN MOD(ROUND(MONTHS_BETWEEN(LAST_DAY(k.dzien_mies), LAST_DAY(b.poczatek_cyklu)) + 1, 0), b.dlugosc) = 2
                       THEN LAST_DAY(ADD_MONTHS(v_ot_data_zn, 1))
                     WHEN MOD(ROUND(MONTHS_BETWEEN(LAST_DAY(k.dzien_mies), LAST_DAY(b.poczatek_cyklu)) + 1, 0), b.dlugosc) = 1
                       THEN LAST_DAY(ADD_MONTHS(v_ot_data_zn, 2))
                   END
              INTO v_ot_data_do
              FROM t_prac p,
                   KP_RCP_WORKING_TIME_SYSTEMS scz,
                   KP_RCP_OKRESY_BILANSU b,
                   NT_KP_KDR_KALENDARZE_PRAC k
             WHERE akt_dane.work_time_system(p.prac_id, SYSDATE - 10) = scz.code
               AND b.id = scz.rcok_id
               AND k.prac_id = p.prac_id
               AND p.prac_id = v_ot_prac_id
               AND k.dzien_mies = v_ot_data_zn;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_ot_data_do := NULL;
          END;
        ELSE
          v_ot_data_do := NULL;
        END IF;

        IF v_ot_data_do IS NOT NULL
           AND v_ot_calendar_date IS NOT NULL
           AND v_ot_calendar_date > v_ot_data_do THEN
          set_error(
            p_msg_pl => 'HSBC: Data odbioru zlecenia powinna być w bieżącym okresie rozliczeniowym!',
            p_msg_en => 'HSBC: The order receipt date should be in the current billing period!'
          );
          RETURN;
        END IF;

      END IF;

    ------------------------------------------------------------------
    -- KP_REQ_REQUEST
    ------------------------------------------------------------------
    ELSIF UPPER(p_table_name) = 'KP_REQ_REQUEST' THEN

      BEGIN
        SELECT type,
               applicant_osby_id
          INTO v_req_type,
               v_applicant_osby_id
          FROM KP_REQ_REQUEST
         WHERE id = p_id;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          RETURN;
      END;

      IF v_req_type = 'O' THEN

        SELECT COUNT(*)
          INTO v_blocked
          FROM t_prac p
          JOIN l_umowy u
            ON u.prac_id = p.prac_id
           AND u.data_od <= SYSDATE
           AND (u.data_do IS NULL OR u.data_do >= SYSDATE)
         WHERE p.osby_id = v_applicant_osby_id
           AND p.data_zatr <= SYSDATE
           AND (p.data_rozw IS NULL OR p.data_rozw >= SYSDATE)
           AND NOT EXISTS (
                 SELECT 1
                   FROM KP_KDR_REMOTE_WORK_PERIODS pz
                  WHERE pz.lumo_id = u.id
                    AND pz.date_from <= SYSDATE
                    AND (pz.date_to IS NULL OR pz.date_to >= SYSDATE)
               )
           AND NOT EXISTS (
                 SELECT 1
                   FROM l_umowy u1
                   JOIN KP_KDR_REMOTE_WORK_PERIODS pz1
                     ON pz1.lumo_id = u1.id
                  WHERE u1.prac_id = p.prac_id
               );

        IF v_blocked > 0 THEN
          IF v_language = 'en' THEN
            po_error_message := 'HSBC: You are not authorized to submit a request for remote work arrangements. Please read the Remote Work Regulations and fill in the required documents.';
          ELSIF v_language = 'pl' THEN
            po_error_message := 'HSBC: Nie masz uprawnień do składania wniosku o uzgodnienie pracy zdalnej. Prośba o zapoznanie się z Regulaminem Pracy Zdalnej i wypełnienie koniecznych dokumentów.';
          ELSE
            po_error_message := 'HSBC: Nie masz uprawnień do składania wniosku o uzgodnienie pracy zdalnej. Prośba o zapoznanie się z Regulaminem Pracy Zdalnej i wypełnienie koniecznych dokumentów.';
          END IF;
          RETURN;
        END IF;

      END IF;

    ------------------------------------------------------------------
    -- KP_RCP_LEAVE_REQUESTS
    ------------------------------------------------------------------
    ELSIF UPPER(p_table_name) = 'KP_RCP_LEAVE_REQUESTS' THEN

      BEGIN
        SELECT U.DATE_FROM,
               U.DATE_TO,
               Z.WORKDAY_DATE
          INTO v_data_od_a,
               v_data_do_a,
               v_workday_date_lv
          FROM KP_RCP_WORK_TIME_EVENTS Z, KP_RCP_LEAVE_REQUESTS U, T_PRAC P
         WHERE U.id = p_id
           AND P.PRAC_ID = Z.PRAC_ID
           AND P.OSBY_ID = U.APPLICANT_ID
           AND Z.WTET_ID = 18
           AND ROWNUM = 1;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          RETURN;
      END;

      IF v_workday_date_lv BETWEEN v_data_od_a AND v_data_do_a THEN
        set_error(
          p_msg_pl => 'HSBC: W okresie proponowanej absencji jest zaewidencjonowany Dyżur. Proszę o modyfikację zakresu dat we wniosku o urlop lub usunięcie Dyżuru i ponowne złożenie wniosku o urlop.',
          p_msg_en => 'HSBC: An on-call duty has been scheduled during the period covered by the requested leave. Please adjust the date range in the leave request or remove the on-call duty assignment and submit the leave request again.'
        );
        RETURN;
      END IF;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      IF v_language = 'en' THEN
        po_error_message := 'HSBC: Unexpected validation error. Please contact the HR Department.';
      ELSE
        po_error_message := 'HSBC: Nieoczekiwany błąd walidacji. Skontaktuj się z działem HR.';
      END IF;

  END validate_row;

END;
