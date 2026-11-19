

SELECT current_database();

DROP TABLE IF EXISTS public.edstatsseries;

CREATE TABLE public.edstatsseries (
    "Series Code" TEXT,
    "Topic" TEXT,
    "Indicator Name" TEXT,
    "Short definition" TEXT,
    "Long definition" TEXT,
    "Unit of measure" TEXT,
    "Periodicity" TEXT,
    "Base Period" TEXT,
    "Other notes" TEXT,
    "Aggregation method" TEXT,
    "Limitations and exceptions" TEXT,
    "Notes from original source" TEXT,
    "General comments" TEXT,
    "Source" TEXT,
    "Statistical concept and methodology" TEXT,
    "Development relevance" TEXT,
    "Related source links" TEXT,
    "Other web links" TEXT,
    "Related indicators" TEXT,
    "License Type" TEXT,
    "Column21" TEXT
);

SELECT COUNT(*) AS nb_colonnes
FROM information_schema.columns
WHERE table_name = 'edstatsseries';

SELECT COUNT(*) FROM edstatsseries;


--CREATE TABLES edstatsdata

SELECT current_database();
DROP TABLE IF EXISTS public.edstatscountry;

SELECT table_catalog, table_schema, table_name
FROM information_schema.tables
WHERE table_name = 'edstatscountry';

CREATE TABLE public.edstatscountry (
    "Country Code" TEXT PRIMARY KEY,
    "Short Name" TEXT,
    "Table Name" TEXT,
    "Long Name" TEXT,
    "2-alpha code" TEXT,
    "Currency Unit" TEXT,
    "Special Notes" TEXT,
    "Region" TEXT,
    "Income Group" TEXT,
    "WB-2 code" TEXT,
    "National accounts base year" TEXT,
    "National accounts reference year" TEXT,
    "SNA price valuation" TEXT,
    "Lending category" TEXT,
    "Other groups" TEXT,
    "System of National Accounts" TEXT,
    "Alternative conversion factor" TEXT,
    "PPP survey year" TEXT,
    "Balance of Payments Manual in use" TEXT,
    "External debt Reporting status" TEXT,
    "System of trade" TEXT,
    "Government Accounting concept" TEXT,
    "IMF data dissemination standard" TEXT,
    "Latest population census" TEXT,
    "Latest household survey" TEXT,
    "Source of most recent Income and expenditure data" TEXT,
    "Vital registration complete" TEXT,
    "Latest agricultural census" TEXT,
    "Latest industrial data" TEXT,
    "Latest trade data" TEXT,
    "Latest water withdrawal data" TEXT,
    "Column32" TEXT
);

SELECT COUNT(*) FROM edstatscountry;

--CREATE TABLES edstatscountry
SELECT current_database();

SELECT COUNT(*) AS nb_colonnes
FROM information_schema.columns
WHERE table_name = 'edstatsdata';

CREATE TABLE public.edstatsdata (
    "Country Name" TEXT,
    "Country Code" TEXT,
    "Indicator Name" TEXT,
    "Indicator Code" TEXT,
    "1970" TEXT, "1971" TEXT, "1972" TEXT, "1973" TEXT, "1974" TEXT, "1975" TEXT,
    "1976" TEXT, "1977" TEXT, "1978" TEXT, "1979" TEXT, "1980" TEXT, "1981" TEXT,
    "1982" TEXT, "1983" TEXT, "1984" TEXT, "1985" TEXT, "1986" TEXT, "1987" TEXT,
    "1988" TEXT, "1989" TEXT, "1990" TEXT, "1991" TEXT, "1992" TEXT, "1993" TEXT,
    "1994" TEXT, "1995" TEXT, "1996" TEXT, "1997" TEXT, "1998" TEXT, "1999" TEXT,
    "2000" TEXT, "2001" TEXT, "2002" TEXT, "2003" TEXT, "2004" TEXT, "2005" TEXT,
    "2006" TEXT, "2007" TEXT, "2008" TEXT, "2009" TEXT, "2010" TEXT, "2011" TEXT,
    "2012" TEXT, "2013" TEXT, "2014" TEXT, "2015" TEXT, "2016" TEXT, "2017" TEXT,
    "2020" TEXT, "2025" TEXT, "2030" TEXT, "2035" TEXT, "2040" TEXT, "2045" TEXT,
    "2050" TEXT, "2055" TEXT, "2060" TEXT, "2065" TEXT, "2070" TEXT, "2075" TEXT,
    "2080" TEXT, "2085" TEXT, "2090" TEXT, "2095" TEXT, "2100" TEXT,
    "Column70" TEXT
);
SELECT COUNT(*) FROM edstatsdata;
SELECT "Country Name", "Indicator Name", "2000", "2010", "2015"
FROM edstatsdata
WHERE "Country Code" = 'TGO'
  AND "Indicator Code" = 'SE.PRM.TENR';

SELECT COUNT(*) AS lignes_remplies
FROM edstatsdata
WHERE "Column70" <> '';
