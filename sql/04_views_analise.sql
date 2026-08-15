-- sql/04_views_analise.sql

-- 1. Evolução da área urbana de SJRP, ano a ano (COVERAGE -> inglês)
CREATE VIEW vw_urban_growth_sjrp AS
SELECT fc.year, fc.area_ha
FROM fact_coverage fc
JOIN dim_class dc ON dc.class_id = fc.class_id
WHERE fc.geocode = 3549805 AND dc.class_name_en = '4.2. Urban Area'
ORDER BY fc.year;

-- 2. Ritmo de crescimento comparado às 5 cidades do grupo
CREATE VIEW vw_urban_growth_comparison AS
SELECT dm.municipality, fc.year, fc.area_ha,
       ROUND(100.0 * (fc.area_ha - FIRST_VALUE(fc.area_ha) OVER w)
             / FIRST_VALUE(fc.area_ha) OVER w, 1) AS growth_pct
FROM fact_coverage fc
JOIN dim_municipality dm ON dm.geocode = fc.geocode
JOIN dim_class dc ON dc.class_id = fc.class_id
WHERE dm.is_comparison_group AND dc.class_name_en = '4.2. Urban Area'
WINDOW w AS (PARTITION BY dm.geocode ORDER BY fc.year)
ORDER BY dm.municipality, fc.year;

-- 3. O que virou área urbana em SJRP, por década (TRANSITION -> português)
CREATE VIEW vw_transition_to_urban_sjrp AS
SELECT ft.period, dcf.class_name_pt AS origin_class, SUM(ft.area_ha) AS area_ha
FROM fact_transition ft
JOIN dim_class dcf ON dcf.class_id = ft.class_id_from
JOIN dim_class dct ON dct.class_id = ft.class_id_to
WHERE ft.geocode = 3549805 AND dct.class_name_pt = 'Área Urbanizada' AND dcf.class_name_pt <> 'Área Urbanizada'
GROUP BY ft.period, dcf.class_name_pt
ORDER BY ft.period, area_ha DESC;

-- 4. % da área urbana nova vinda de pastagem, por período (SJRP)
CREATE VIEW vw_share_pastagem_by_period AS
SELECT DISTINCT
    period,
    SUM(area_ha) FILTER (WHERE origin_class = 'Pastagem') OVER (PARTITION BY period) AS pastagem_ha,
    SUM(area_ha) OVER (PARTITION BY period) AS total_ha,
    ROUND(100.0 * SUM(area_ha) FILTER (WHERE origin_class = 'Pastagem') OVER (PARTITION BY period)
          / SUM(area_ha) OVER (PARTITION BY period), 1) AS pastagem_pct
FROM vw_transition_to_urban_sjrp;

-- 5. O mesmo padrão, nas 5 cidades de comparação
CREATE VIEW vw_share_pastagem_by_city AS
SELECT DISTINCT
    dm.municipality,
    ft.period,
    SUM(ft.area_ha) FILTER (WHERE dcf.class_name_pt = 'Pastagem')
        OVER (PARTITION BY dm.municipality, ft.period) AS pastagem_ha,
    SUM(ft.area_ha) OVER (PARTITION BY dm.municipality, ft.period) AS total_ha,
    ROUND(100.0 * SUM(ft.area_ha) FILTER (WHERE dcf.class_name_pt = 'Pastagem')
        OVER (PARTITION BY dm.municipality, ft.period)
        / SUM(ft.area_ha) OVER (PARTITION BY dm.municipality, ft.period), 1) AS pastagem_pct
FROM fact_transition ft
JOIN dim_municipality dm ON dm.geocode = ft.geocode
JOIN dim_class dcf ON dcf.class_id = ft.class_id_from
JOIN dim_class dct ON dct.class_id = ft.class_id_to
WHERE dm.is_comparison_group AND dct.class_name_pt = 'Área Urbanizada' AND dcf.class_name_pt <> 'Área Urbanizada';

-- 6. Ranking: quem converteu mais pastagem em área urbana
CREATE VIEW vw_ranking_pastagem_to_urban AS
SELECT dm.municipality,
       SUM(ft.area_ha) AS pastagem_to_urban_ha,
       RANK() OVER (ORDER BY SUM(ft.area_ha) DESC) AS rank_absoluto
FROM fact_transition ft
JOIN dim_municipality dm ON dm.geocode = ft.geocode
JOIN dim_class dcf ON dcf.class_id = ft.class_id_from
JOIN dim_class dct ON dct.class_id = ft.class_id_to
WHERE dm.is_comparison_group AND dcf.class_name_pt = 'Pastagem' AND dct.class_name_pt = 'Área Urbanizada'
GROUP BY dm.municipality;

-- 7. Composição agrícola de SJRP ao longo dos 41 anos (COVERAGE -> inglês)
CREATE VIEW vw_agri_composition_over_time AS
SELECT dc.class_name_pt AS class_name, fc.year, fc.area_ha
FROM fact_coverage fc
JOIN dim_class dc ON dc.class_id = fc.class_id
WHERE fc.geocode = 3549805
  AND dc.class_name_en IN (
    '3.1. Pasture', '3.2.1.2. Sugar cane', '3.2.1.1. Soybean',
    '3.2.2.1. Coffee', '3.2.2.2. Citrus', '3.3. Forest Plantation', '3.4. Mosaic of Uses'
  )
ORDER BY dc.class_name_pt, fc.year;

-- 8. Transições entre classes agrícolas (não só para urbano), por período
CREATE VIEW vw_agri_transitions_by_period AS
SELECT ft.period, dcf.class_name_pt AS origin_class, dct.class_name_pt AS destination_class,
       SUM(ft.area_ha) AS area_ha
FROM fact_transition ft
JOIN dim_class dcf ON dcf.class_id = ft.class_id_from
JOIN dim_class dct ON dct.class_id = ft.class_id_to
WHERE ft.geocode = 3549805
  AND dcf.class_name_pt IN ('Pastagem','Cana','Soja','Café','Citrus','Silvicultura','Mosaico de Usos')
  AND dct.class_name_pt IN ('Pastagem','Cana','Soja','Café','Citrus','Silvicultura','Mosaico de Usos')
  AND dcf.class_name_pt <> dct.class_name_pt
GROUP BY ft.period, dcf.class_name_pt, dct.class_name_pt
ORDER BY ft.period, area_ha DESC;
