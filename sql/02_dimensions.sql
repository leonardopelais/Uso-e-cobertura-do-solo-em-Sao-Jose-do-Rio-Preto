-- sql/02_dimensions.sql

-- dim_municipality: todos os municípios de SP entram (dado já é pequeno),
-- mas só os 6 do grupo de comparação ficam marcados is_comparison_group = TRUE.
-- A regra usa a própria tabela para achar as 5 populações mais próximas de SJRP —
-- não é uma lista fixa de nomes.
INSERT INTO dim_municipality (geocode, municipality, state, population)
SELECT DISTINCT geocode, municipality, state, population
FROM staging_population
ON CONFLICT (geocode) DO NOTHING;

UPDATE dim_municipality
SET is_comparison_group = TRUE
WHERE geocode = 3549805
   OR geocode IN (
        SELECT geocode
        FROM dim_municipality
        WHERE geocode != 3549805
        ORDER BY ABS(population - (SELECT population FROM dim_municipality WHERE geocode = 3549805))
        LIMIT 5
   );

-- dim_class: uma linha por combinação única de níveis, vinda do COVERAGE (inglês).
-- class_name_pt é a tradução manual para o nome em português que aparece nos
-- exports de TRANSITION — levantada a partir do conjunto real de classes
-- observado nas 6 cidades do projeto (não é uma lista genérica do MapBiomas).
-- Observação: "Usina Fotovoltaica" (PT) não tem uma classe própria no COVERAGE
-- desta coleção — cai dentro do "balde" mais próximo, "Other non Vegetated Areas".
-- "Aquaculture" (EN) não tem correspondente porque não houve transição de
-- aquicultura em nenhuma das 6 cidades — fica sem tradução (NULL), sem problema.
INSERT INTO dim_class (class_level_0, class_level_1, class_level_2, class_level_3, class_level_4, class_name_en, class_name_pt)
SELECT DISTINCT ON (sc.class_name_en)
    sc.class_level_0, sc.class_level_1, sc.class_level_2, sc.class_level_3, sc.class_level_4,
    sc.class_name_en,
    t.class_name_pt
FROM (
    SELECT class_level_0, class_level_1, class_level_2, class_level_3, class_level_4,
           COALESCE(class_level_4, class_level_3, class_level_2, class_level_1, class_level_0) AS class_name_en
    FROM staging_coverage
) sc
LEFT JOIN (VALUES
    ('3.1. Pasture', 'Pastagem'),
    ('3.2.1.2. Sugar cane', 'Cana'),
    ('3.2.1.1. Soybean', 'Soja'),
    ('3.2.1.5. Other Temporary Crops', 'Outras Lavouras Temporárias'),
    ('3.2.2.1. Coffee', 'Café'),
    ('3.2.2.4. Other Perennial Crops', 'Outras Lavouras Perenes'),
    ('3.2.2.2. Citrus', 'Citrus'),
    ('3.3. Forest Plantation', 'Silvicultura'),
    ('3.4. Mosaic of Uses', 'Mosaico de Usos'),
    ('4.2. Urban Area', 'Área Urbanizada'),
    ('4.3. Mining', 'Mineração'),
    ('1.1. Forest Formation', 'Formação Florestal'),
    ('1.2. Savanna Formation', 'Formação Savânica'),
    ('1.4. Mangrove', 'Mangue'),
    ('1.6. Wooded Sandbank Vegetation', 'Restinga Arbórea'),
    ('2.1. Wetland', 'Campo Alagado e Área Pantanosa'),
    ('2.3. Grassland Formation', 'Formação Campestre'),
    ('2.5. Hypersaline Tidal Flat', 'Apicum'),
    ('2.6. Rocky Outcrop', 'Afloramento Rochoso'),
    ('4.1. Beach, Dune and Sand Spot', 'Praia, Duna e Areal'),
    ('5.1. River, Lake and Ocean', 'Rio, Lago e Oceano'),
    ('4.6. Other non Vegetated Areas', 'Usina Fotovoltaica')
) AS t(class_name_en, class_name_pt) ON t.class_name_en = sc.class_name_en
ON CONFLICT (class_name_en) DO NOTHING;
