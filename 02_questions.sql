-- =====================================================================
-- PROJET ÉDUCATION (données EdStats, Banque mondiale)
-- Fichier 2 : couverture des données et questions d'analyse
-- Base : projet_education
-- Pré-requis : exécuter d'abord 01_nettoyage.sql
--   (tables education_long, vues pays_reels et regroupements)
--
-- Indicateur principal : SE.PRM.TENR
--   = taux net ajusté de scolarisation au primaire (%), filles et garçons
--
-- Exécuter les requêtes une par une avec Ctrl + Entrée
-- =====================================================================


-- =====================================================================
-- PARTIE A : COUVERTURE DES DONNÉES DANS LE TEMPS
-- Objectif : choisir l'année de comparaison d'après les données réelles
-- =====================================================================

-- A.1 Nombre d'entités (pays ET regroupements) avec une valeur, par année
-- Constat : 15 à 25 entités avant 1999, environ 141 à 163 de 1999 à 2014,
-- 119 en 2015, 9 en 2016, aucune en 2017
SELECT annee, COUNT(DISTINCT code_pays) AS nb_pays
FROM education_long
WHERE code_indicateur = 'SE.PRM.TENR'
GROUP BY annee
ORDER BY annee;

-- A.2 Même comptage, seulement pour les vrais pays (vue pays_reels)
-- Constat : aucun vrai pays avant 1999 ; 113 à 138 pays de 1999 à 2015
-- (130 en 2014, 113 en 2015, 9 en 2016). L'écart avec A.1 est de 25
-- jusqu'en 2014 : ce sont les 25 regroupements.
SELECT e.annee, COUNT(DISTINCT e.code_pays) AS nb_pays_reels
FROM education_long e
INNER JOIN pays_reels p ON e.code_pays = p.code_pays
WHERE e.code_indicateur = 'SE.PRM.TENR'
GROUP BY e.annee
ORDER BY e.annee;

-- Conclusion de la partie A : période d'analyse retenue 1999 à 2015.
-- Année de comparaison entre pays : 2014 (le Togo y a une valeur, 130 pays
-- au total). 2010 est la mieux couverte de la base, mais le Togo n'a pas de
-- valeur entre 2009 et 2013 : un classement en 2010 l'exclurait sans le dire.


-- =====================================================================
-- PARTIE B : LES QUESTIONS
-- =====================================================================

-- ---------------------------------------------------------------------
-- Question 1 : combien d'indicateurs et de pays ont au moins une valeur ?
-- Méthode : COUNT(DISTINCT) sur les identifiants (les codes). Le LEFT JOIN
-- avec pays_reels donne NULL pour les regroupements, que COUNT(DISTINCT)
-- ignore : le 3e nombre ne compte que les vrais pays.
-- Résultat : 3 665 indicateurs, 242 entités, 216 pays. Les trois nombres
-- atteignent leur maximum : aucun indicateur n'est entièrement vide et
-- chaque pays de la vue pays_reels a au moins une valeur. Les 242 entités
-- sont 216 pays, 25 regroupements et VGB (code absent de la table des pays).
-- ---------------------------------------------------------------------
SELECT COUNT(DISTINCT e.code_indicateur) AS nb_indicateurs,
       COUNT(DISTINCT e.code_pays)       AS nb_entites,
       COUNT(DISTINCT p.code_pays)       AS nb_pays_reels
FROM education_long e
LEFT JOIN pays_reels p ON e.code_pays = p.code_pays;


-- ---------------------------------------------------------------------
-- Question 2 : quels sont les 5 indicateurs les mieux renseignés
-- (vrais pays seulement) ?
-- Constat : avec les regroupements, les indicateurs "Population ages"
-- arrivent en 3e à 5e position ; sans eux, ce sont trois indicateurs sur le
-- système éducatif (durée du primaire, âges d'entrée). Exclure les
-- regroupements change le classement.
-- Résultat : Population, total (9 989 valeurs, 215 pays) en tête, puis
-- Population growth (9 983), Theoretical duration of primary education
-- (9 582), Official entrance age to primary (9 582) et Official entrance
-- age to lower secondary (9 464).
-- Contrôle : edstatsseries n'a aucun doublon sur "Series Code".
-- ---------------------------------------------------------------------
SELECT el.code_indicateur,
       es."Indicator Name",
       COUNT(*) AS nb_valeurs,
       COUNT(DISTINCT el.code_pays) AS nb_pays_reels
FROM education_long el
INNER JOIN pays_reels p     ON el.code_pays = p.code_pays
INNER JOIN edstatsseries es ON el.code_indicateur = es."Series Code"
GROUP BY el.code_indicateur, es."Indicator Name"
ORDER BY nb_valeurs DESC
LIMIT 5;


-- ---------------------------------------------------------------------
-- Question 3 : comment a évolué le taux net de scolarisation primaire
-- du Togo ?
-- Méthode : LAG pour la valeur et l'année précédentes. La variation n'est
-- gardée que si l'écart est de 1 an : le Togo n'a aucune valeur de 2009 à
-- 2013, donc la ligne 2014 compare en réalité 2014 à 2008 (6 ans).
-- Résultat : 88,55 % en 1999 à 97,46 % en 2015 (environ +9 points).
-- Reculs en 2000 (-3,52), 2003 (-2,20), 2005 (-0,55) et 2007 (-3,31).
-- Les données ne disent rien sur les causes de ces reculs.
-- ---------------------------------------------------------------------
WITH serie AS (
    SELECT annee,
           ROUND(valeur, 2) AS valeur,
           annee - LAG(annee) OVER (ORDER BY annee) AS ecart_annees,
           ROUND(valeur - LAG(valeur) OVER (ORDER BY annee), 2) AS variation
    FROM education_long
    WHERE code_pays = 'TGO'
      AND code_indicateur = 'SE.PRM.TENR'
)
SELECT annee,
       valeur,
       CASE WHEN ecart_annees = 1 THEN variation END AS variation_annuelle
FROM serie
ORDER BY annee;


-- ---------------------------------------------------------------------
-- Question 4 : où se situe le Togo parmi les pays d'Afrique subsaharienne ?
-- ---------------------------------------------------------------------

-- 4a. Classement en 2014 (RANK et COUNT(*) OVER ())
-- Résultat : le Togo est 9e sur 26 pays avec 93,03 %, au-dessus de la
-- médiane (rangs 13-14 : environ 81 %). Premier : Cabo Verde (98,24).
SELECT p.pays,
       ROUND(e.valeur, 2) AS taux,
       RANK() OVER (ORDER BY e.valeur DESC) AS rang,
       COUNT(*) OVER () AS nb_pays_classes
FROM education_long e
INNER JOIN pays_reels p ON e.code_pays = p.code_pays
WHERE e.code_indicateur = 'SE.PRM.TENR'
  AND e.annee = 2014
  AND p.region = 'Sub-Saharan Africa'
ORDER BY rang;

-- 4b. Pays de la région SANS valeur en 2014 (anti-jointure)
-- Les conditions sur education_long sont dans le ON : placées dans le
-- WHERE, elles supprimeraient les NULL cherchés.
-- Résultat : 22 pays (48 dans la région moins 26 classés), dont Nigeria,
-- Rép. dém. du Congo, Afrique du Sud, Kenya, Soudan et Ouganda.
-- Le classement ne couvre donc que 54 % de la région.
-- Le Nigeria a des valeurs de 1999 à 2010 seulement.
SELECT p.code_pays,
       p.pays
FROM pays_reels p
LEFT JOIN education_long e
       ON e.code_pays = p.code_pays
      AND e.code_indicateur = 'SE.PRM.TENR'
      AND e.annee = 2014
WHERE p.region = 'Sub-Saharan Africa'
  AND e.code_pays IS NULL
ORDER BY p.pays;

-- 4c. Stabilité : 2014 et 2015 sur les MÊMES pays (pivot avec CASE WHEN)
-- Les classements de chaque année ne se comparent pas directement :
-- 26 pays classés en 2014, 24 en 2015 (5 pays seulement en 2014, 3
-- seulement en 2015).
-- Résultat sur les 21 pays communs : le Togo passe de la 8e à la 1re place
-- (93,03 à 97,46 ; +4,43 points, 2e plus forte hausse après la Mauritanie
-- +4,82). Écart avec le 2e en 2015 (Cabo Verde, 97,27) : 0,19 point.
-- Médiane des variations : +0,18 point.
-- Conclusion : le Togo est dans le groupe de tête, mais son rang exact
-- dépend de l'année et des pays inclus. Les données n'expliquent pas la
-- hausse de 2015.
WITH valeurs AS (
    SELECT p.code_pays,
           p.pays,
           MAX(CASE WHEN e.annee = 2014 THEN e.valeur END) AS v2014,
           MAX(CASE WHEN e.annee = 2015 THEN e.valeur END) AS v2015
    FROM education_long e
    INNER JOIN pays_reels p ON e.code_pays = p.code_pays
    WHERE e.code_indicateur = 'SE.PRM.TENR'
      AND e.annee IN (2014, 2015)
      AND p.region = 'Sub-Saharan Africa'
    GROUP BY p.code_pays, p.pays
),
communs AS (
    SELECT *
    FROM valeurs
    WHERE v2014 IS NOT NULL
      AND v2015 IS NOT NULL
)
SELECT pays,
       ROUND(v2014, 2) AS taux_2014,
       ROUND(v2015, 2) AS taux_2015,
       ROUND(v2015 - v2014, 2) AS variation,
       RANK() OVER (ORDER BY v2014 DESC) AS rang_2014,
       RANK() OVER (ORDER BY v2015 DESC) AS rang_2015,
       COUNT(*) OVER () AS nb_pays_communs
FROM communs
ORDER BY rang_2015;


-- ---------------------------------------------------------------------
-- Question 5 : la parité filles-garçons au primaire s'est-elle améliorée ?
-- Indicateur SE.ENR.PRIM.FM.ZS : indice de parité (GPI) du taux brut de
-- scolarisation au primaire. 1 = parité parfaite.
-- ---------------------------------------------------------------------

-- 5a. La série et ses variations annuelles (arrondi à 3 décimales)
-- Résultat : 44 années de 1971 à 2015 (1993 absente). L'indice passe de 0,446
-- à 0,947 (+0,501 ; x2,1). 37 variations annuelles sur 42 sont positives
-- (médiane +0,0125). Baisses en 1984-1987 (4 années consécutives) et en 2009
-- (-0,025), suivie de la plus forte hausse (+0,049 en 2010). La variation de
-- 1994 est vide : l'écart avec 1992 est de 2 ans.
-- L'indice compare des taux d'inscription, pas la qualité de l'éducation.
WITH serie AS (
    SELECT annee,
           ROUND(valeur, 3) AS indice,
           annee - LAG(annee) OVER (ORDER BY annee) AS ecart_annees,
           ROUND(valeur - LAG(valeur) OVER (ORDER BY annee), 3) AS variation
    FROM education_long
    WHERE code_pays = 'TGO'
      AND code_indicateur = 'SE.ENR.PRIM.FM.ZS'
)
SELECT annee,
       indice,
       CASE WHEN ecart_annees = 1 THEN variation END AS variation_annuelle
FROM serie
ORDER BY annee;

-- 5b. Première et dernière valeur (FIRST_VALUE / LAST_VALUE)
-- LAST_VALUE exige la fenêtre ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED
-- FOLLOWING, sinon elle renvoie la valeur de la ligne courante.
-- Résultat : 0,446 (1971) à 0,947 (2015), soit +0,501.
SELECT DISTINCT
       FIRST_VALUE(annee)  OVER w AS premiere_annee,
       FIRST_VALUE(valeur) OVER w AS premiere_valeur,
       LAST_VALUE(annee)   OVER w AS derniere_annee,
       LAST_VALUE(valeur)  OVER w AS derniere_valeur
FROM education_long
WHERE code_pays = 'TGO'
  AND code_indicateur = 'SE.ENR.PRIM.FM.ZS'
WINDOW w AS (ORDER BY annee
             ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING);


-- ---------------------------------------------------------------------
-- Question 6 : combien d'élèves par enseignant au primaire (Togo) ?
-- Indicateur SE.PRM.ENRL.TC.ZS (comptage par personnes).
-- Moyenne mobile sur 3 ans avec RANGE (et non ROWS) : la fenêtre est définie
-- sur les années, donc un trou ne l'étire pas ; COUNT(*) OVER w contrôle le
-- nombre de points (3 attendus).
-- Résultat : 44 années, 1993 absente ; moyenne masquée en 1971, 1972, 1994 et
-- 1995 (fenêtre incomplète). De 58,46 (1971) à 41,71 (2015), -28,7 %.
-- Phases : stable jusqu'en 1978, baisse jusqu'à 44,42 (1985), hausse jusqu'au
-- maximum 63,79 (1992), baisse jusqu'au minimum 33,60 (2005), palier de 2010 à
-- 2015 (entre 40,57 et 41,71).
-- Le ratio ne mesure pas la qualité de l'enseignement.
-- ---------------------------------------------------------------------
SELECT annee,
       ROUND(valeur, 2) AS eleves_par_enseignant,
       COUNT(*) OVER w  AS nb_points,
       CASE WHEN COUNT(*) OVER w = 3
            THEN ROUND(AVG(valeur) OVER w, 2)
       END AS moyenne_mobile_3ans
FROM education_long
WHERE code_pays = 'TGO'
  AND code_indicateur = 'SE.PRM.ENRL.TC.ZS'
WINDOW w AS (ORDER BY annee RANGE BETWEEN 2 PRECEDING AND CURRENT ROW)
ORDER BY annee;


-- ---------------------------------------------------------------------
-- Question 7 : le ratio publié correspond-il aux effectifs / enseignants ?
-- Pivot de 3 indicateurs (CASE WHEN + MAX) puis comparaison.
-- Résultat : 44 années communes (1993 absente des trois séries). L'écart est
-- de 0,00 % partout : le ratio est cohérent avec les effectifs divisés par les
-- enseignants. Ce test vérifie la cohérence interne, pas l'exactitude des
-- effectifs (le ratio est vraisemblablement calculé à partir d'eux).
-- Le pic de 1992 (63,79) vient d'une baisse du nombre d'enseignants (-7,9 %),
-- le creux de 2005 (33,60) d'une hausse (+17,7 %). Élèves x6,19 et
-- enseignants x8,67 entre 1971 et 2015.
-- Effectifs quasi identiques en 2013-2015 (variations de +0,06 % et +0,02 %).
-- ---------------------------------------------------------------------
WITH pivot AS (
    SELECT annee,
           MAX(CASE WHEN code_indicateur = 'SE.PRM.ENRL'       THEN valeur END) AS eleves,
           MAX(CASE WHEN code_indicateur = 'SE.PRM.TCHR'       THEN valeur END) AS enseignants,
           MAX(CASE WHEN code_indicateur = 'SE.PRM.ENRL.TC.ZS' THEN valeur END) AS ratio_publie
    FROM education_long
    WHERE code_pays = 'TGO'
      AND code_indicateur IN ('SE.PRM.ENRL', 'SE.PRM.TCHR', 'SE.PRM.ENRL.TC.ZS')
    GROUP BY annee
)
SELECT annee,
       eleves,
       enseignants,
       ROUND(ratio_publie, 2)                  AS ratio_publie,
       ROUND(eleves / enseignants, 2)          AS ratio_calcule,
       ROUND((eleves / enseignants / ratio_publie - 1) * 100, 2) AS ecart_pct
FROM pivot
WHERE eleves IS NOT NULL
  AND enseignants IS NOT NULL
  AND ratio_publie IS NOT NULL
ORDER BY annee;


-- ---------------------------------------------------------------------
-- Question 8 : l'écart de durée de scolarisation entre filles et garçons
-- s'est-il réduit ? (Togo)
-- Indicateurs UIS.SLE.1.M / UIS.SLE.1.F / UIS.SLE.1.GPI : espérance de
-- scolarisation au primaire (années). Elle ne coïncide pas avec les classes
-- achevées (redoublement) ; la valeur des garçons dépasse 6 ans (durée
-- officielle du primaire) 42 années sur 43.
-- ---------------------------------------------------------------------

-- 8.0 Définitions officielles des indicateurs. Attendu : 3 lignes
SELECT "Series Code",
       "Indicator Name",
       "Short definition",
       "Long definition"
FROM edstatsseries
WHERE "Series Code" IN ('UIS.SLE.1.M', 'UIS.SLE.1.F', 'UIS.SLE.1.GPI');

-- 8a. Garçons, filles, écart et indice par année
-- Résultat : 43 années de 1971 à 2014 (1993 absente, série arrêtée en 2014).
-- Écart garçons - filles : 3,19 an (1971) à 0,46 an (2014). L'indice calculé
-- (filles / garçons) égale l'indice publié sur les 43 années.
WITH pivot AS (
    SELECT annee,
           MAX(CASE WHEN code_indicateur = 'UIS.SLE.1.M'   THEN valeur END) AS garcons,
           MAX(CASE WHEN code_indicateur = 'UIS.SLE.1.F'   THEN valeur END) AS filles,
           MAX(CASE WHEN code_indicateur = 'UIS.SLE.1.GPI' THEN valeur END) AS gpi_publie
    FROM education_long
    WHERE code_pays = 'TGO'
      AND code_indicateur IN ('UIS.SLE.1.M', 'UIS.SLE.1.F', 'UIS.SLE.1.GPI')
    GROUP BY annee
)
SELECT annee,
       ROUND(garcons, 2)          AS garcons,
       ROUND(filles, 2)           AS filles,
       ROUND(garcons - filles, 2) AS ecart_annees,
       ROUND(filles / garcons, 3) AS gpi_calcule,
       ROUND(gpi_publie, 3)       AS gpi_publie
FROM pivot
WHERE garcons IS NOT NULL
  AND filles IS NOT NULL
ORDER BY annee;

-- 8b. Début, fin et extrêmes de l'écart
-- Résultat : 3,19 (1971), 0,46 (2014), maximum 3,50 (1978), minimum 0,46.
-- L'écart passe sous 2 ans en 2000 et sous 1 an en 2008. Filles : 2,52 à 7,43
-- (x2,95) ; garçons : 5,72 à 7,89 (x1,38), maximum 8,59 en 1980. La
-- convergence vient surtout de la hausse des filles. Hausse de l'écart en
-- 2009 (+0,33, la plus forte). Comparé à la question 5 : écart médian de
-- l'indice de 0,004, maximum 0,014 (1986) sur 43 années communes.
WITH pivot AS (
    SELECT annee,
           MAX(CASE WHEN code_indicateur = 'UIS.SLE.1.M' THEN valeur END) AS garcons,
           MAX(CASE WHEN code_indicateur = 'UIS.SLE.1.F' THEN valeur END) AS filles
    FROM education_long
    WHERE code_pays = 'TGO'
      AND code_indicateur IN ('UIS.SLE.1.M', 'UIS.SLE.1.F')
    GROUP BY annee
),
ecarts AS (
    SELECT annee,
           garcons - filles AS ecart
    FROM pivot
    WHERE garcons IS NOT NULL
      AND filles IS NOT NULL
)
SELECT DISTINCT
       FIRST_VALUE(annee) OVER w               AS premiere_annee,
       ROUND(FIRST_VALUE(ecart) OVER w, 2)     AS premier_ecart,
       LAST_VALUE(annee) OVER w                AS derniere_annee,
       ROUND(LAST_VALUE(ecart) OVER w, 2)      AS dernier_ecart,
       ROUND(MAX(ecart) OVER (), 2)            AS ecart_max,
       ROUND(MIN(ecart) OVER (), 2)            AS ecart_min
FROM ecarts
WINDOW w AS (ORDER BY annee
             ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING);


-- ---------------------------------------------------------------------
-- Question 9 : où se situe le Togo parmi les pays d'Afrique subsaharienne
-- pour le taux brut de scolarisation au primaire ?
-- Indicateur SE.PRM.ENRR (peut dépasser 100 % : redoublants, entrées tardives)
-- ---------------------------------------------------------------------

-- 9.0 Préparation : choisir l'année d'après la couverture
-- Résultat : 2011 réunit 43 pays sur 48 et les 5 voisins du Togo ; 2010 n'en
-- avait que 3 ; 32 pays en 2014 et 29 en 2015.
SELECT e.annee,
       COUNT(DISTINCT e.code_pays) AS nb_pays_region,
       COUNT(DISTINCT e.code_pays) FILTER (WHERE e.code_pays = 'TGO') AS togo,
       COUNT(DISTINCT e.code_pays) FILTER (WHERE e.code_pays IN ('BEN', 'BFA', 'CIV', 'GHA', 'NGA')) AS nb_voisins
FROM education_long e
INNER JOIN pays_reels p ON e.code_pays = p.code_pays
WHERE e.code_indicateur = 'SE.PRM.ENRR'
  AND p.region = 'Sub-Saharan Africa'
  AND e.annee BETWEEN 2000 AND 2015
GROUP BY e.annee
ORDER BY e.annee;

-- 9a. Classement en 2011
-- Résultat : le Togo est 7e sur 43 pays (125,87 %), 20,8 points au-dessus de
-- la médiane (105,07). 24 pays dépassent 100 %. Voisins : Benin 10e (118,61),
-- Ghana 19e (106,67), Nigeria 31e (90,25), Côte d'Ivoire 36e (81,56),
-- Burkina Faso 39e (81,28). Un taux plus élevé n'est pas "meilleur".
-- Le classement couvre 90 % de la région (contre 54 % pour le taux net, Q4).
SELECT p.pays,
       ROUND(e.valeur, 2) AS taux_brut,
       RANK() OVER (ORDER BY e.valeur DESC) AS rang,
       COUNT(*) OVER () AS nb_pays_classes,
       CASE WHEN p.code_pays = 'TGO' THEN 'Togo'
            WHEN p.code_pays IN ('BEN', 'BFA', 'CIV', 'GHA', 'NGA') THEN 'voisin'
       END AS repere
FROM education_long e
INNER JOIN pays_reels p ON e.code_pays = p.code_pays
WHERE e.code_indicateur = 'SE.PRM.ENRR'
  AND e.annee = 2011
  AND p.region = 'Sub-Saharan Africa'
ORDER BY rang;


-- 9b. Stabilité : 2008 et 2011 sur les MÊMES pays (pivot avec CASE WHEN)
-- Résultat : 39 pays communs (4 pays seulement en 2011 : Gabon, Sierra Leone,
-- Swaziland, South Sudan ; 2 pays seulement en 2008, d'après la couverture).
-- Le classement est stable : corrélation des rangs (Spearman) de 0,94 ; 23
-- pays sur 39 changent d'au plus 2 rangs, 34 d'au plus 5 (maximum 12 :
-- Tanzania 14e puis 26e). 8 des 10 premiers de 2008 le restent en 2011
-- (entrants : Congo, Benin ; sortants : Zambia, Uganda).
-- Le Togo passe du 10e (111,48 %) au 6e rang (125,87 %) : +14,39 points, la
-- 3e plus forte hausse après Burundi (+17,02) et Angola (+16,79). Il devance
-- ses 5 voisins les deux années (rangs 2008 : Benin 13, Ghana 19, Nigeria 29,
-- Côte d'Ivoire 35, Burkina Faso 36). Médiane des variations : +2,26 ; 24 pays
-- sur 39 progressent. Le sens de la hausse du Togo est le même que celui des
-- effectifs (+23,2 % entre 2008 et 2011, question 7), sans que cela prouve un
-- lien. Un taux brut peut dépasser 100 %.
WITH valeurs AS (
    SELECT p.code_pays,
           p.pays,
           MAX(CASE WHEN e.annee = 2008 THEN e.valeur END) AS v2008,
           MAX(CASE WHEN e.annee = 2011 THEN e.valeur END) AS v2011
    FROM education_long e
    INNER JOIN pays_reels p ON e.code_pays = p.code_pays
    WHERE e.code_indicateur = 'SE.PRM.ENRR'
      AND e.annee IN (2008, 2011)
      AND p.region = 'Sub-Saharan Africa'
    GROUP BY p.code_pays, p.pays
),
communs AS (
    SELECT *
    FROM valeurs
    WHERE v2008 IS NOT NULL
      AND v2011 IS NOT NULL
)
SELECT pays,
       ROUND(v2008, 2) AS taux_2008,
       ROUND(v2011, 2) AS taux_2011,
       ROUND(v2011 - v2008, 2) AS variation,
       RANK() OVER (ORDER BY v2008 DESC) AS rang_2008,
       RANK() OVER (ORDER BY v2011 DESC) AS rang_2011,
       COUNT(*) OVER () AS nb_pays_communs
FROM communs
ORDER BY rang_2011;


-- ---------------------------------------------------------------------
-- Question 10 : quelles années manquent dans les séries d'éducation du Togo ?
-- LEAD donne l'année suivante de la même série ; un écart > 1 signale un trou.
-- Séries d'au moins 30 valeurs, thèmes d'éducation.
-- ---------------------------------------------------------------------

-- 10.0 Années manquantes de 4 séries entre 1971 et 2015 (anti-jointure avec
-- generate_series). Résultat : 1993 pour les 4 séries, 2015 pour UIS.SLE.1.
SELECT i.code_indicateur,
       a.annee AS annee_manquante
FROM (VALUES ('SE.PRM.ENRR'),
             ('SE.PRM.ENRL.TC.ZS'),
             ('SE.ENR.PRIM.FM.ZS'),
             ('UIS.SLE.1')) AS i(code_indicateur)
CROSS JOIN generate_series(1971, 2015) AS a(annee)
LEFT JOIN education_long e
       ON e.code_pays = 'TGO'
      AND e.code_indicateur = i.code_indicateur
      AND e.annee = a.annee
WHERE e.annee IS NULL
ORDER BY i.code_indicateur, a.annee;

-- 10a. Détail des trous par série
-- Résultat partiel (affichage limité à 200 lignes par DBeaver) : 144 séries
-- visibles, dont 99 manquent 1973-1975.
WITH serie_togo AS (
    SELECT el.code_indicateur,
           es."Indicator Name" AS indicateur,
           el.annee,
           LEAD(el.annee) OVER (PARTITION BY el.code_indicateur
                                ORDER BY el.annee) AS annee_suivante,
           COUNT(*) OVER (PARTITION BY el.code_indicateur) AS nb_valeurs
    FROM education_long el
    INNER JOIN edstatsseries es ON el.code_indicateur = es."Series Code"
    WHERE el.code_pays = 'TGO'
      AND es."Topic" IN ('Primary', 'Secondary', 'Tertiary', 'Pre-Primary',
                         'Attainment', 'Literacy', 'Education Equality',
                         'Learning Outcomes', 'Teachers', 'Expenditures')
)
SELECT code_indicateur,
       indicateur,
       annee + 1                  AS debut_trou,
       annee_suivante - 1         AS fin_trou,
       annee_suivante - annee - 1 AS nb_annees_manquantes,
       nb_valeurs
FROM serie_togo
WHERE annee_suivante - annee > 1
  AND nb_valeurs >= 30
ORDER BY nb_annees_manquantes DESC, code_indicateur, debut_trou;

-- 10b. Bilan par série (nombre de trous et d'années manquantes)
-- Résultat partiel (affichage limité à 200 lignes : seules les séries les plus
-- lacunaires sont visibles ; les séries à 1 ou 2 années manquantes, dont
-- SE.PRM.ENRR, SE.PRM.ENRL.TC.ZS et SE.ENR.PRIM.FM.ZS avec 1993, n'y figurent pas).
-- La série la plus lacunaire est UIS.OAEP.1 (élèves du primaire en sureffectif
-- d'âge) : 30 valeurs sur 45 années, 15 manquantes en 5 trous.
-- 4 séries de taux net, d'admission et d'enfants non scolarisés (SE.PRM.UNER,
-- UIS.NERT.1, UIS.NIRA.1, UIS.ROFST.1) ont 14 années manquantes en 5 trous.
-- Le supérieur perd 12 années (4 trous : SE.TER.ENRL, SE.TER.ENRR, UIS.SLE.56,
-- UIS.TE_100000.56) ; SE.SCH.LIFE, SE.SEC.ENRL.TC.ZS et SE.SEC.TCHR 11 années
-- (6 trous) ; les taux d'abandon du primaire 10 ou 11 années.
-- Une série d'au moins 30 valeurs peut donc avoir jusqu'à un tiers de ses
-- années absentes. Les causes ne sont pas dans les données.
-- Contrôle : dernière année - première année + 1 = nb_valeurs + années
-- manquantes (vérifié sur un échantillon de lignes).
WITH serie_togo AS (
    SELECT el.code_indicateur,
           es."Indicator Name" AS indicateur,
           el.annee,
           LEAD(el.annee) OVER (PARTITION BY el.code_indicateur
                                ORDER BY el.annee) AS annee_suivante,
           COUNT(*) OVER (PARTITION BY el.code_indicateur) AS nb_valeurs
    FROM education_long el
    INNER JOIN edstatsseries es ON el.code_indicateur = es."Series Code"
    WHERE el.code_pays = 'TGO'
      AND es."Topic" IN ('Primary', 'Secondary', 'Tertiary', 'Pre-Primary',
                         'Attainment', 'Literacy', 'Education Equality',
                         'Learning Outcomes', 'Teachers', 'Expenditures')
)
SELECT code_indicateur,
       indicateur,
       MIN(annee)      AS premiere_annee,
       MAX(annee)      AS derniere_annee,
       MAX(nb_valeurs) AS nb_valeurs,
       COUNT(*) FILTER (WHERE annee_suivante - annee > 1) AS nb_trous,
       COALESCE(SUM(annee_suivante - annee - 1)
                FILTER (WHERE annee_suivante - annee > 1), 0) AS annees_manquantes
FROM serie_togo
GROUP BY code_indicateur, indicateur
HAVING MAX(nb_valeurs) >= 30
ORDER BY annees_manquantes DESC, code_indicateur;

-- 10c. Quelles périodes manquent le plus souvent ?
-- Résultat : 1993 est l'année la plus lacunaire : 216 séries la perdent
-- seule, 19 avec 1992 (au moins 235 séries sur les 245 de la 10d, soit 95,9 %).
-- Puis 1997-1998 (128 séries, 52,2 %),
-- 1977 (100), 1973-1975 (99), 1997 seule (47), 2012 (45), 2009 (43), 2008 (41).
-- Les trous sont partagés par des blocs de séries. Les trous les plus longs
-- touchent le supérieur (1999-2005, 7 ans) et UIS.OAEP.1 (2009-2014, 6 ans).
-- 4 séries de taux net et d'accès (UIS.NERT.1, UIS.NIRA.1, UIS.ROFST.1,
-- SE.PRM.UNER) partagent le trou 2009-2013 de SE.PRM.TENR.
-- Les causes ne sont pas dans les données. Toute variation d'une année à
-- l'autre doit être protégée par un contrôle de l'écart d'années.
WITH serie_togo AS (
    SELECT el.code_indicateur,
           el.annee,
           LEAD(el.annee) OVER (PARTITION BY el.code_indicateur
                                ORDER BY el.annee) AS annee_suivante,
           COUNT(*) OVER (PARTITION BY el.code_indicateur) AS nb_valeurs
    FROM education_long el
    INNER JOIN edstatsseries es ON el.code_indicateur = es."Series Code"
    WHERE el.code_pays = 'TGO'
      AND es."Topic" IN ('Primary', 'Secondary', 'Tertiary', 'Pre-Primary',
                         'Attainment', 'Literacy', 'Education Equality',
                         'Learning Outcomes', 'Teachers', 'Expenditures')
),
trous AS (
    SELECT code_indicateur,
           annee + 1                  AS debut_trou,
           annee_suivante - 1         AS fin_trou,
           annee_suivante - annee - 1 AS nb_annees_manquantes
    FROM serie_togo
    WHERE annee_suivante - annee > 1
      AND nb_valeurs >= 30
)
SELECT debut_trou,
       fin_trou,
       nb_annees_manquantes,
       COUNT(*) AS nb_series
FROM trous
GROUP BY debut_trou, fin_trou, nb_annees_manquantes
ORDER BY nb_series DESC, debut_trou
LIMIT 15;

-- 10d. Nombre total de séries d'au moins 30 valeurs (pour exprimer les trous
-- en pourcentage).
-- Résultat : 245 séries. 1993 manque donc dans au moins 235 séries sur 245
-- (95,9 %) ; 1997-1998 dans 128 (52,2 %) ; 1977 dans 100 (40,8 %) ;
-- 1973-1975 dans 99 (40,4 %). Les 5 séries constantes à 47 valeurs
-- (durées, âges d'entrée) n'ont aucun trou.
SELECT COUNT(*) AS nb_series_30_valeurs
FROM (
    SELECT el.code_indicateur
    FROM education_long el
    INNER JOIN edstatsseries es ON el.code_indicateur = es."Series Code"
    WHERE el.code_pays = 'TGO'
      AND es."Topic" IN ('Primary', 'Secondary', 'Tertiary', 'Pre-Primary',
                         'Attainment', 'Literacy', 'Education Equality',
                         'Learning Outcomes', 'Teachers', 'Expenditures')
    GROUP BY el.code_indicateur
    HAVING COUNT(*) >= 30
) t;


-- =====================================================================
-- PARTIE C : DENSITÉ DE LA BASE PAR ANNÉE (contrôle du creux de 1993)
-- =====================================================================

-- C.1 Nombre d'indicateurs avec une valeur pour le Togo, par année
-- Résultat : 1991 : 574 ; 1992 : 508 ; 1993 : 267 ; 1994 : 545 ; 1995 : 945
SELECT annee, COUNT(*) AS nb_indicateurs
FROM education_long
WHERE code_pays = 'TGO'
  AND annee BETWEEN 1991 AND 1995
GROUP BY annee
ORDER BY annee;

-- C.2 Même comptage pour tous les pays
-- Résultat : 74 437 ; 75 543 ; 75 793 ; 77 462 ; 131 361 lignes, 241 entités
-- chaque année. Le creux de 1993 est propre au Togo (la base progresse de
-- 0,3 %) ; le bond de 1995 est général (+70 % pour la base, +73 % pour le Togo).
SELECT annee,
       COUNT(*) AS nb_lignes,
       COUNT(DISTINCT code_pays) AS nb_pays
FROM education_long
WHERE annee BETWEEN 1991 AND 1995
GROUP BY annee
ORDER BY annee;
