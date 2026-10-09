DECLARE
    CURSOR c IS
        select o.id
        from NT_KP_RCP_ZLECENIA_NADG z, KP_RCP_OVERTIME_PAYMENT o, t_prac p
        where z.id = o.RCZP_ID
        and o.CALENDAR_DATE = '26/08/30'
        and z.DATA between '26/08/01' and '26/08/31'
        and (z.CLASSIFIED_SECONDS_11 > 0 or z.CLASSIFIED_SECONDS_12 > 0)
        and p.PRAC_ID = z.PRAC_ID
        and p.nr_ew = '45255195'
        order by p.nazwisko;

BEGIN
    FOR rec IN c LOOP
        CONTINUE WHEN rec.id IS NULL;
        update KP_RCP_OVERTIME_PAYMENT set CALENDAR_DATE = '26/08/31' where id = rec.id;
        COMMIT;
    END LOOP;
END;
