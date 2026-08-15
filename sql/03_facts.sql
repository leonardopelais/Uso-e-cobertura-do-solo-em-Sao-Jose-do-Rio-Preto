-- sql/03_facts.sql

INSERT INTO fact_coverage (geocode, class_id, year, area_ha)
SELECT sc.geocode, dc.class_id, sc.year, sc.area_ha
FROM staging_coverage sc
JOIN dim_class dc
  ON dc.class_name_en = COALESCE(sc.class_level_4, sc.class_level_3, sc.class_level_2, sc.class_level_1, sc.class_level_0);

INSERT INTO fact_transition (geocode, class_id_from, class_id_to, period, area_ha)
SELECT st.geocode, dcf.class_id, dct.class_id, st.period, st.area_ha
FROM staging_transition st
JOIN dim_class dcf ON dcf.class_name_pt = st.class_from
JOIN dim_class dct ON dct.class_name_pt = st.class_to;

-- Validação (Camada 2 do spec): nenhuma linha de staging deve ficar sem
-- município correspondente depois do JOIN. Se a query abaixo retornar
-- alguma linha, algo está errado (ex.: geocode com erro de digitação).
SELECT sc.geocode, sc.municipality
FROM staging_coverage sc
LEFT JOIN dim_municipality dm ON dm.geocode = sc.geocode
WHERE dm.geocode IS NULL;
