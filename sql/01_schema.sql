-- sql/01_schema.sql

-- Staging: espelho fiel do dado bruto, sem transformação de negócio
CREATE TABLE staging_population (
    state              TEXT NOT NULL,
    uf_code            INTEGER NOT NULL,
    municipality_code  INTEGER NOT NULL,
    geocode            INTEGER NOT NULL,
    municipality       TEXT NOT NULL,
    population         INTEGER NOT NULL
);

CREATE TABLE staging_coverage (
    geocode        INTEGER NOT NULL,
    municipality   TEXT NOT NULL,
    state          TEXT NOT NULL,
    class_level_0  TEXT NOT NULL,
    class_level_1  TEXT,
    class_level_2  TEXT,
    class_level_3  TEXT,
    class_level_4  TEXT,
    year           INTEGER NOT NULL,
    area_ha        NUMERIC NOT NULL
);

CREATE TABLE staging_transition (
    geocode       INTEGER NOT NULL,
    municipality  TEXT NOT NULL,
    period        TEXT NOT NULL,
    class_from    TEXT NOT NULL,
    class_to      TEXT NOT NULL,
    area_ha       NUMERIC NOT NULL
);

-- Dimensões
CREATE TABLE dim_municipality (
    geocode              INTEGER PRIMARY KEY,
    municipality         TEXT NOT NULL,
    state                TEXT NOT NULL,
    population           INTEGER NOT NULL,
    is_comparison_group  BOOLEAN NOT NULL DEFAULT FALSE
);

-- class_level_0..4 e class_name_en vêm do COVERAGE, que usa nomes em INGLÊS
-- (ex.: "4.2. Urban Area"). class_name_pt é a tradução manual para o nome em
-- PORTUGUÊS que aparece nos exports de TRANSITION (ex.: "Área Urbanizada") —
-- os dois idiomas coexistem porque cada fonte de dado do MapBiomas exporta
-- num idioma diferente; sem isso o JOIN entre fact_coverage e fact_transition
-- não bate.
CREATE TABLE dim_class (
    class_id       SERIAL PRIMARY KEY,
    class_level_0  TEXT NOT NULL,
    class_level_1  TEXT,
    class_level_2  TEXT,
    class_level_3  TEXT,
    class_level_4  TEXT,
    class_name_en  TEXT NOT NULL UNIQUE,
    class_name_pt  TEXT UNIQUE
);

-- Fatos
CREATE TABLE fact_coverage (
    geocode   INTEGER NOT NULL REFERENCES dim_municipality(geocode),
    class_id  INTEGER NOT NULL REFERENCES dim_class(class_id),
    year      INTEGER NOT NULL,
    area_ha   NUMERIC NOT NULL,
    PRIMARY KEY (geocode, class_id, year)
);

CREATE TABLE fact_transition (
    geocode        INTEGER NOT NULL REFERENCES dim_municipality(geocode),
    class_id_from  INTEGER NOT NULL REFERENCES dim_class(class_id),
    class_id_to    INTEGER NOT NULL REFERENCES dim_class(class_id),
    period         TEXT NOT NULL,
    area_ha        NUMERIC NOT NULL,
    PRIMARY KEY (geocode, class_id_from, class_id_to, period)
);
