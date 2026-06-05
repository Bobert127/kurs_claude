WITH cal AS (
    /*+ MATERIALIZE */
    SELECT P.PRAC_ID, P.IMIE, P.NAZWISKO, P.NR_EW, P.NR_KARTY,
           akt_dane.Direct_Superior(P.PRAC_ID, K.DZIEN_MIES)                         AS przelozony,
           akt_dane.Superior_Identification_Number(P.PRAC_ID, K.DZIEN_MIES, 'T', 1) AS przelozny_nr_ew,
           K.DZIEN_MIES, K.CZAS_OD, K.CZAS_DO,
           TRUNC(K.DZIEN_MIES) + (K.CZAS_OD - TRUNC(K.CZAS_OD)) AS CAL_START,
           TRUNC(K.DZIEN_MIES) + (K.CZAS_DO - TRUNC(K.CZAS_DO))
           + CASE WHEN (K.CZAS_DO - TRUNC(K.CZAS_DO)) < (K.CZAS_OD - TRUNC(K.CZAS_OD))
                  THEN 1 ELSE 0 END                                                  AS CAL_END
    FROM T_PRAC P
    JOIN NT_KP_KDR_KALENDARZE_PRAC K ON K.PRAC_ID = P.PRAC_ID
    WHERE K.DZIEN_MIES BETWEEN DATE '2026-03-01' AND DATE '2026-05-31'
    AND   K.TYP_DNIA IS NULL
)
SELECT C.IMIE, C.NAZWISKO, C.NR_EW, C.NR_KARTY, C.przelozony, C.przelozny_nr_ew,
       C.DZIEN_MIES,
       TO_CHAR(C.CZAS_OD,        'HH24:MI') AS CZAS_OD,
       TO_CHAR(C.CZAS_DO,        'HH24:MI') AS CZAS_DO,
       D.WORKDAY_DATE,
       TO_CHAR(D.DATE_TIME_FROM, 'HH24:MI') AS DYZUR_OD,
       TO_CHAR(D.DATE_TIME_TO,   'HH24:MI') AS DYZUR_DO,
       CASE
           WHEN D.DATE_TIME_FROM >= C.CAL_START AND D.DATE_TIME_TO <= C.CAL_END
               THEN 'dyżur w czasie pracy'
           ELSE 'dyżur nakładający się z harmonogramem'
       END AS TYP
FROM cal C
JOIN KP_RCP_WORK_TIME_EVENTS D ON D.PRAC_ID  = C.PRAC_ID
                               AND D.WTET_ID  = 18
                               AND TRUNC(D.WORKDAY_DATE) = TRUNC(C.DZIEN_MIES)
                               AND (
                                       -- całkowicie w czasie pracy
                                       (D.DATE_TIME_FROM >= C.CAL_START AND D.DATE_TIME_TO <= C.CAL_END)
                                       -- zazębia z początkiem zmiany
                                    OR (D.DATE_TIME_FROM <  C.CAL_START AND D.DATE_TIME_TO >  C.CAL_START)
                                       -- zazębia z końcem zmiany
                                    OR (D.DATE_TIME_FROM <  C.CAL_END   AND D.DATE_TIME_TO >  C.CAL_END)
                               )
ORDER BY C.NAZWISKO, C.IMIE, C.DZIEN_MIES
