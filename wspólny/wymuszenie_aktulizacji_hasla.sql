DECLARE
    a pa_user_account_statuses.id%TYPE;
    v_licznik NUMBER := 0;
    CURSOR c IS
    SELECT
        us.id
    FROM
        pa_user_account_statuses us,
        teta_users               u
    WHERE
            us.user_id = u.id
        AND u.has_access_to_tg = 'T'
         AND U.UZYTKOWNIK = '45173440';

BEGIN
    OPEN c;
    LOOP
        FETCH c INTO a;
        EXIT WHEN c%notfound;
        IF a IS NOT NULL THEN
            UPDATE pa_user_account_statuses us
            SET
                us.password_expiry_date = sysdate - 1
            WHERE
                id = a;
            COMMIT;
            v_licznik := v_licznik + 1;
        END IF;

    END LOOP;

    CLOSE c;

    DBMS_OUTPUT.PUT_LINE('Petla wykonala sie ' || v_licznik || ' razy.');
END;
