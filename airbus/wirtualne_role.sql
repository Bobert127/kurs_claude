SELECT DISTINCT
    dir.osby_id AS id
FROM kp_mrq_manager_requests mare
JOIN pa_wfl_doc_associations doas ON doas.document_guid = mare.guid
JOIN pa_wfl_dokumenty_d doku ON doku.id = doas.doku_id
INNER JOIN kp_mrq_employees memp ON memp.mare_id = mare.id
  OUTER APPLY (
    SELECT osby_id
    FROM (
        SELECT p.osby_id, LEVEL AS poziom
        FROM NT_KP_KDR_STRUKTURA_AGENT a
        JOIN t_prac p ON p.prac_id = a.prac_id
        WHERE UPPER(AKT_DANE.STANOWISKO(p.prac_id, SYSDATE)) LIKE 'DYREKTOR%'
          AND a.data_od <= SYSDATE
          AND (a.data_do IS NULL OR a.data_do >= SYSDATE)   -- rekord struktury aktualnie obowiązujący
        START WITH p.osby_id = mare.applicant_osby_id
            AND a.data_od <= SYSDATE
            AND (a.data_do IS NULL OR a.data_do >= SYSDATE)
        CONNECT BY NOCYCLE PRIOR a.prac_prac_id = a.prac_id
            AND a.data_od <= SYSDATE
            AND (a.data_do IS NULL OR a.data_do >= SYSDATE)
        ORDER BY poziom
    )
    WHERE ROWNUM = 1
) dir
WHERE doku.szab_id = 227
  AND mare.TYPE = 'U'
  AND doku.id = {*Arguments.DocumentId*}
  AND dir.osby_id IS NOT NULL;
