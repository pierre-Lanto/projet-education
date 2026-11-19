-- =====================================================================
-- PROJET ÉDUCATION (données EdStats, Banque mondiale)
-- Fichier 1 : vérifications, audit de qualité et nettoyage
-- Base : projet_education  |  Schéma : public
--
-- Pré-requis : les 3 tables brutes sont déjà importées depuis les CSV
--   edstatscountry (241 lignes), edstatsseries (3 665 lignes),
--   edstatsdata (886 930 lignes)
--
-- Exécution : Alt + X pour tout lancer. L'étape 4 (education_long)
-- peut durer 1 à 2 minutes : attendre la fin.
-- =====================================================================


-- =====================================================================
-- ÉTAPE 0 : vérifier la base active (doit afficher projet_education)
-- =====================================================================
SELECT current_database();


-- =====================================================================
-- ÉTAPE 1 : AUDIT DE QUALITÉ DES DONNÉES BRUTES
-- =====================================================================

-- 1.1 Doublons sur (pays, indicateur). Attendu : 0 ligne
SELECT "Country Code", "Indicator Code", COUNT(*) AS nb
FROM edstatsdata
GROUP BY "Country Code", "Indicator Code"
HAVING COUNT(*) > 1;

-- 1.2 Lignes dont toutes les années sont vides.
-- Résultat obtenu : 529 525 sur 886 930 (environ 60 %)
SELECT COUNT(*) AS lignes_vides
FROM edstatsdata d
WHERE (SELECT COUNT(*)
       FROM jsonb_each_text(to_jsonb(d))
       WHERE key ~ '^[0-9]{4}$' AND value <> '') = 0;

-- 1.3 Nombre de valeurs renseignées pour quelques années (données brutes)
-- Résultat obtenu : 1990 = 124 405 ; 2000 = 176 676 ; 2010 = 242 442 ;
--                   2015 = 131 058 ; 2017 = 143
SELECT COUNT(*) FILTER (WHERE "1990" <> '') AS n_1990,
       COUNT(*) FILTER (WHERE "2000" <> '') AS n_2000,
       COUNT(*) FILTER (WHERE "2010" <> '') AS n_2010,
       COUNT(*) FILTER (WHERE "2015" <> '') AS n_2015,
       COUNT(*) FILTER (WHERE "2017" <> '') AS n_2017
FROM edstatsdata;

-- 1.4 Valeurs de 2010 qui ne sont pas des nombres. Attendu : 0
SELECT COUNT(*) AS non_numeriques
FROM edstatsdata
WHERE "2010" <> ''
  AND "2010" !~ '^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$';

-- 1.5 Codes pays présents dans les données mais absents de la table des pays
-- (anti-jointure). Résultat obtenu : 1 code, VGB
SELECT DISTINCT d."Country Code"
FROM edstatsdata d
LEFT JOIN edstatscountry c ON d."Country Code" = c."Country Code"
WHERE c."Country Code" IS NULL;

-- 1.6 Pays avec et sans région. Résultat obtenu : 27 sans région, 214 avec
SELECT COUNT(*) FILTER (WHERE "Region" = '')  AS sans_region,
       COUNT(*) FILTER (WHERE "Region" <> '') AS avec_region
FROM edstatscountry;

-- 1.7 Que sont les 27 lignes sans région ?
-- Résultat : 25 regroupements (World, Arab World, groupes de revenu...)
-- et 2 vrais territoires : GIB (Gibraltar) et NRU (Nauru)
SELECT "Country Code", "Short Name"
FROM edstatscountry
WHERE "Region" = ''
ORDER BY "Short Name";


-- =====================================================================
-- ÉTAPE 2 : SÉPARER LES VRAIS PAYS DES REGROUPEMENTS (deux vues)
-- =====================================================================

-- 2.1 Pays et territoires : ceux qui ont une région, plus GIB et NRU
CREATE OR REPLACE VIEW pays_reels AS
SELECT "Country Code" AS code_pays,
       "Short Name"   AS pays,
       NULLIF("Region", '')       AS region,
       NULLIF("Income Group", '') AS groupe_revenu
FROM edstatscountry
WHERE "Region" <> ''
   OR "Country Code" IN ('GIB', 'NRU');

-- 2.2 Regroupements (World, Low income, South Asia...) à exclure des
-- classements de pays
CREATE OR REPLACE VIEW regroupements AS
SELECT "Country Code" AS code_regroupement,
       "Short Name"   AS nom
FROM edstatscountry
WHERE "Region" = ''
  AND "Country Code" NOT IN ('GIB', 'NRU');

-- 2.3 Contrôle. Attendu : 216 pays et 25 regroupements (total 241)
SELECT (SELECT COUNT(*) FROM pays_reels)    AS nb_pays,
       (SELECT COUNT(*) FROM regroupements) AS nb_regroupements;

-- 2.4 Contrôle : le Togo et ses voisins. Attendu : 6 lignes
-- (Sub-Saharan Africa ; Togo, Bénin, Burkina Faso = Low income ;
--  Côte d'Ivoire, Ghana, Nigeria = Lower middle income, selon le fichier)
SELECT code_pays, pays, region, groupe_revenu
FROM pays_reels
WHERE code_pays IN ('TGO', 'GHA', 'BEN', 'BFA', 'CIV', 'NGA')
ORDER BY pays;


-- =====================================================================
-- ÉTAPE 3 : TABLE D'ANALYSE AU FORMAT LONG (education_long)
-- Une ligne par pays, indicateur et année.
-- Transformations : une colonne par année devient une ligne par année,
-- années jusqu'à 2017 seulement, cases vides supprimées, valeurs
-- converties en nombres. La table brute edstatsdata reste intacte.
-- Attention : DROP supprime l'ancienne version, la recréation prend
-- 1 à 2 minutes.
-- =====================================================================
DROP TABLE IF EXISTS education_long;

CREATE TABLE education_long AS
SELECT d."Country Code"   AS code_pays,
       d."Country Name"   AS pays,
       d."Indicator Code" AS code_indicateur,
       d."Indicator Name" AS indicateur,
       kv.key::int        AS annee,
       kv.value::numeric  AS valeur
FROM edstatsdata d
CROSS JOIN LATERAL jsonb_each_text(to_jsonb(d)) AS kv
WHERE CASE WHEN kv.key ~ '^[0-9]{4}$' THEN kv.key::int <= 2017 ELSE FALSE END
  AND kv.value <> '';


-- =====================================================================
-- ÉTAPE 4 : CONTRÔLES DE LA TABLE NETTOYÉE
-- =====================================================================

-- 4.1 Nombre total de lignes. Résultat obtenu : 4 207 789
SELECT COUNT(*) AS nb_lignes
FROM education_long;

-- 4.2 La conversion n'a perdu aucune ligne : les nombres doivent être
-- identiques à ceux de la table brute (requête 1.3)
-- Attendu : 124 405 ; 176 676 ; 242 442 ; 131 058 ; 143
SELECT annee, COUNT(*) AS nb_valeurs
FROM education_long
WHERE annee IN (1990, 2000, 2010, 2015, 2017)
GROUP BY annee
ORDER BY annee;

-- 4.3 Test de lecture : taux net ajusté de scolarisation primaire du Togo
-- Attendu : 12 lignes, de 1999 (88,55) à 2015 (97,46)
SELECT annee, valeur
FROM education_long
WHERE code_pays = 'TGO'
  AND code_indicateur = 'SE.PRM.TENR'
ORDER BY annee;
