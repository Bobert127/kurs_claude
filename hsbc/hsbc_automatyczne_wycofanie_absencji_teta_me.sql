-- wersja 1 - oryginalna
SELECT LERE.ID AS ID,
              DOKU.ID AS DOKU_ID,
              LRPO.PRAC_ID AS PRAC_ID,
              LERE.GUID AS GUID,
              LERE.OSBY_ID AS OSBY_ID,
              to_char(sysdate, 'dd') AS DZIS
FROM  PA_WFL_DOC_ASSOCIATIONS DOAS
            INNER JOIN KP_RCP_LEAVE_REQUESTS LERE
                                 ON LERE.GUID = DOAS.DOCUMENT_GUID
            INNER JOIN KP_RCP_LEAVE_REQUESTS_POSITION LRPO
                                 ON LRPO.LERE_ID = LERE.ID
            INNER JOIN PA_WFL_DOKUMENTY DOKU
                                ON DOKU.ID = DOAS.DOKU_ID
WHERE DOKU.STDO_KOD = 'U4T_ACCEPT_FOR_WITHDRAWING'
AND LERE.DATE_FROM >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -3)


-- wersja 2 - blokada na freez
SELECT LERE.ID AS ID,
              DOKU.ID AS DOKU_ID,
              LRPO.PRAC_ID AS PRAC_ID,
              LERE.GUID AS GUID,
              LERE.OSBY_ID AS OSBY_ID,
              to_char(sysdate, 'dd') AS DZIS
FROM  PA_WFL_DOC_ASSOCIATIONS DOAS
            INNER JOIN KP_RCP_LEAVE_REQUESTS LERE
                                 ON LERE.GUID = DOAS.DOCUMENT_GUID
            INNER JOIN KP_RCP_LEAVE_REQUESTS_POSITION LRPO
                                 ON LRPO.LERE_ID = LERE.ID
            INNER JOIN PA_WFL_DOKUMENTY DOKU
                                ON DOKU.ID = DOAS.DOKU_ID
WHERE DOKU.STDO_KOD = 'U4T_ACCEPT_FOR_WITHDRAWING'
AND LERE.DATE_FROM >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -3)
AND to_char(sysdate, 'dd') NOT IN (4,5,6,7,8,19,20,21,22,23,24,25)
