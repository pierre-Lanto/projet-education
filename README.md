# Mini-projet SQL : l'éducation en Afrique subsaharienne

Import, nettoyage et analyse des données **EdStats** de la Banque mondiale avec **PostgreSQL**, en mettant l'accent sur le **Togo**.

> **Statut : analyses terminées.** Les dix questions sont réalisées et leurs vérifications complémentaires faites.

**Auteur :** Lanto Gnim Pierre, étudiant en Master 1 Big Data (UCAO), Lomé, Togo

---

## Objectif

Appliquer sur des données réelles et volumineuses la chaîne complète d'un projet de data analyse : **importer, auditer, nettoyer, analyser, conclure**. Le thème de l'éducation a été choisi pour son lien avec la data au service du public.

## Outils

- PostgreSQL
- DBeaver Community
- SQL : jointures, anti-jointures, CTE, vues, fonctions de fenêtre (`RANK`, `LAG`, `LEAD`, `FIRST_VALUE`, `LAST_VALUE`, moyennes mobiles), pivots (`CASE WHEN`), `generate_series`, `CROSS JOIN LATERAL`

## Les données

Source : base **Education Statistics (EdStats)** de la Banque mondiale, téléchargeable en fichiers CSV sur le site de la Banque mondiale (catalogue de données, jeu de données EdStats).

| Fichier | Table | Lignes | Contenu |
|---|---|---|---|
| `EdStatsCountry.csv` | `edstatscountry` | 241 | Pays et regroupements : code, nom, région, groupe de revenu |
| `EdStatsSeries.csv` | `edstatsseries` | 3 665 | Indicateurs : code, thème, définitions |
| `EdStatsData.csv` | `edstatsdata` | 886 930 | Valeurs : une ligne par pays et indicateur, une colonne par année (70 colonnes) |

Deux autres fichiers du téléchargement (`EdStatsCountry-Series.csv`, `EdStatsFootNote.csv`) contiennent des notes sur les sources. Ils n'ont pas été importés, car ils ne sont pas nécessaires aux questions retenues.

**Relations entre les tables :** `edstatsdata."Country Code"` renvoie à `edstatscountry."Country Code"`, et `edstatsdata."Indicator Code"` renvoie à `edstatsseries."Series Code"`.

## Organisation du dépôt

| Fichier | Contenu |
|---|---|
| `00_creation_tables_brutes.sql` | Création des 3 tables brutes (colonnes `TEXT`) avant l'import des CSV |
| `01_nettoyage.sql` | Audit de qualité, vues `pays_reels` et `regroupements`, création et contrôle de `education_long` |
| `02_questions.sql` | Couverture des données dans le temps, les dix questions et leurs résultats |
| `README.md` | Ce document |

**Ordre d'exécution :** créer la base `projet_education`, exécuter `00_creation_tables_brutes.sql`, importer les trois CSV dans les tables, puis exécuter `01_nettoyage.sql` et `02_questions.sql` (requête par requête avec `Ctrl + Entrée`).

---

## Démarche et décisions de nettoyage

### 1. Import

DBeaver devine les types de colonnes d'après les premières lignes et propose des textes trop courts, ce qui provoque l'erreur `value too long for type character varying(50)`. Les tables sont donc créées à la main avec des colonnes `TEXT`, puis les CSV sont importés vers ces tables. La conversion en nombres se fait ensuite en SQL.

### 2. Audit de qualité des données brutes

| Contrôle | Résultat | Décision |
|---|---|---|
| Doublons sur (pays, indicateur) | 0 | Rien à supprimer |
| Lignes sans aucune valeur d'année | 529 525 sur 886 930 (60 %) | Exclues de l'analyse |
| Valeurs de 2010 non numériques | 0 | Conversion en nombres possible |
| Codes pays absents de `edstatscountry` | 1 (`VGB`) | Exclu des analyses avec jointure |
| Pays sans région renseignée | 27 | Examinés un par un (voir ci-dessous) |

**Pays et regroupements.** La table des pays mélange de vrais pays et des regroupements (« World », « Arab World », groupes de revenu...). Parmi les 27 lignes sans région, 25 sont des regroupements, mais 2 sont de vrais territoires : Gibraltar (`GIB`) et Nauru (`NRU`). Filtrer simplement les régions vides les aurait retirés par erreur. Deux vues séparent les deux ensembles :

- `pays_reels` : **216** pays et territoires
- `regroupements` : **25** regroupements, à exclure de tout classement de pays

### 3. Table d'analyse `education_long`

La table brute a une colonne par année. `education_long` a **une ligne par pays, indicateur et année** (4 207 789 lignes) :

- années jusqu'à 2017 uniquement (les projections 2020 à 2100 sont écartées) ;
- cases vides supprimées ;
- valeurs converties en nombres.

La table brute reste intacte : la version nettoyée est construite à côté, comme dans un pipeline ETL.

**Contrôle de la conversion.** Le nombre de valeurs par année dans `education_long` est identique à celui de la table brute pour les cinq années testées :

| Année | Table brute | `education_long` |
|---|---|---|
| 1990 | 124 405 | 124 405 |
| 2000 | 176 676 | 176 676 |
| 2010 | 242 442 | 242 442 |
| 2015 | 131 058 | 131 058 |
| 2017 | 143 | 143 |

## Couverture des données dans le temps

Pour l'indicateur `SE.PRM.TENR` (taux net ajusté de scolarisation au primaire), nombre de **vrais pays** ayant une valeur :

- **1970 à 1998** : aucun vrai pays (seuls des regroupements) ;
- **1999 à 2014** : de 116 à 138 pays par année (130 en 2014) ;
- **2015** : 113 pays ; **2016** : 9 pays ; **2017** : aucun.

La période exploitable pour comparer des pays est donc **1999 à 2015**.

**Choisir l'année d'après la couverture.** 2010 est l'année la mieux couverte de toute la base, mais le Togo n'a aucune valeur de cet indicateur de 2009 à 2013 : un classement en 2010 l'exclurait sans le signaler. L'année de comparaison est choisie **indicateur par indicateur** : 2014 pour le taux net, 2011 pour le taux brut (43 pays sur 48 et les 5 voisins du Togo, contre 3 voisins en 2010).

---

## Résultats des dix questions

Les requêtes et les contrôles détaillés sont dans `02_questions.sql`.

| # | Question | Résultat principal |
|---|---|---|
| 1 | Combien d'indicateurs et de pays ont au moins une valeur ? | 3 665 indicateurs, 242 entités (216 pays, 25 regroupements et `VGB`), 216 pays : aucun indicateur n'est entièrement vide |
| 2 | Quels sont les 5 indicateurs les mieux renseignés ? | Population totale (9 989 valeurs, 215 pays), croissance de la population, puis trois indicateurs sur le système éducatif (durée du primaire, âges d'entrée) |
| 3 | Comment a évolué la scolarisation primaire au Togo ? | Taux net : 88,5 % (1999) à 97,5 % (2015) |
| 4 | Où se situe le Togo parmi les pays d'Afrique subsaharienne ? | 9e sur 26 en 2014, 2e sur 24 en 2015 ; sur 21 pays communs, 8e puis 1er |
| 5 | La parité filles-garçons s'est-elle améliorée ? | Indice de 0,446 (1971) à 0,947 (2015) |
| 6 | Combien d'élèves par enseignant ? | 58,5 (1971) à 41,7 (2015), minimum 33,6 en 2005 |
| 7 | Le ratio publié est-il cohérent avec les effectifs ? | Oui, écart de 0,00 % sur les 44 années |
| 8 | L'écart de durée de scolarisation filles-garçons s'est-il réduit ? | De 3,19 ans (1971) à 0,46 an (2014) |
| 9 | Où se situe le Togo pour le taux brut ? | 7e sur 43 pays en 2011 (125,87 %) ; classement stable entre 2008 et 2011 |
| 10 | Quelles années manquent dans les séries du Togo ? | 1993 manque dans au moins 235 des 245 séries étudiées (96 %) |

### Question 3 : l'évolution du Togo

Taux net ajusté de scolarisation au primaire (`SE.PRM.TENR`) : de **88,55 % en 1999 à 97,46 % en 2015**, soit environ 9 points de plus en 16 ans. La progression est irrégulière : le taux recule en 2000, 2003, 2005 et 2007. Aucune valeur n'existe de 2009 à 2013.

**Un piège évité.** Sans précaution, la fonction `LAG` compare 2014 à 2008 et affiche +1,56 comme une variation annuelle, alors qu'il s'agit d'un écart de six ans. Toutes les variations du projet ne sont calculées que si l'écart d'années vaut 1.

### Question 4 : le Togo dans la région

| Base de comparaison | 2014 | 2015 |
|---|---|---|
| Tous les pays ayant une valeur | 9e sur 26 (93,03 %) | 2e sur 24 (97,46 %) |
| Les 21 pays présents les deux années | 8e | 1er |

- La région compte **48 pays** dans le fichier ; **22 n'ont pas de valeur en 2014**, dont le Nigeria (série arrêtée en 2010). Le classement ne couvre que 54 % de la région : le Togo est « 9e sur les 26 pays qui ont une valeur », pas « 9e de la région ».
- Les rangs de 2014 et 2015 ne se comparent pas directement, car les pays classés ne sont pas les mêmes.
- En 2015, l'écart avec Cabo Verde (97,27 %) n'est que de 0,19 point : le rang 1 ne permet pas de dire que le Togo fait mieux.
- Le taux du Togo gagne 4,43 points entre 2014 et 2015, la deuxième plus forte hausse des 21 pays communs, après la Mauritanie (+4,82). La médiane est de +0,18 point.

### Question 5 : la parité filles-garçons au primaire

L'indice de parité des taux bruts (`SE.ENR.PRIM.FM.ZS`) passe de **0,446 en 1971 à 0,947 en 2015**, soit plus du double. Il progresse sur 37 des 42 variations annuelles. Deux épisodes de baisse : 1984 à 1987 (quatre années consécutives) et 2009 (-0,025), suivie de la plus forte hausse de la série (+0,049 en 2010).

### Question 6 : élèves par enseignant

De **58,46 en 1971 à 41,71 en 2015** (-28,7 %), avec une évolution en phases : stable jusqu'en 1978, baisse jusqu'à 44,42 (1985), hausse jusqu'au maximum de 63,79 (1992), baisse jusqu'au minimum de 33,60 (2005), puis un palier de 2010 à 2015 (entre 40,57 et 41,71). La moyenne mobile sur 3 ans est calculée sur les années réellement présentes, et masquée quand la fenêtre est incomplète.

### Question 7 : cohérence du ratio

Le ratio publié est égal aux effectifs divisés par le nombre d'enseignants sur les 44 années. Ce test vérifie la cohérence interne de la source, pas l'exactitude des effectifs. Le pic de 1992 vient d'une baisse du nombre d'enseignants (-7,9 %), le creux de 2005 d'une hausse (+17,7 %). Entre 1971 et 2015, les élèves sont multipliés par 6,19 et les enseignants par 8,67.

### Question 8 : durée de scolarisation filles et garçons

L'espérance de scolarisation au primaire passe de 2,52 à 7,43 ans pour les filles et de 5,72 à 7,89 ans pour les garçons (1971 à 2014). L'écart de **3,19 ans (1971) tombe à 0,46 an (2014)**, passe sous 2 ans en 2000 et sous 1 an en 2008. Les garçons ont leur maximum en 1980 (8,59) : la convergence vient surtout de la hausse des filles. L'indice calculé (filles divisé par garçons) égale l'indice publié sur les 43 années. Comparé à la question 5, l'écart médian entre les deux indices de parité est de 0,004 (maximum 0,014).

### Question 9 : le Togo parmi la région, taux brut

En 2011, le Togo est **7e sur 43 pays** avec un taux brut de 125,87 %, soit 20,8 points au-dessus de la médiane (105,07 %). Il devance ses cinq voisins : Benin 10e (118,61), Ghana 19e (106,67), Nigeria 31e (90,25), Côte d'Ivoire 36e (81,56), Burkina Faso 39e (81,28). Ce classement couvre 90 % de la région, contre 54 % pour le taux net.

**Stabilité (2008 contre 2011, 39 pays présents les deux années).** Le classement est stable : la corrélation des rangs (Spearman) est de 0,94, 23 pays sur 39 changent d'au plus 2 rangs et 34 d'au plus 5, et 8 des 10 premiers de 2008 le restent en 2011. Le Togo passe du 10e au 6e rang : son taux gagne 14,39 points (111,48 à 125,87), la troisième plus forte hausse après le Burundi (+17,02) et l'Angola (+16,79). Il devance ses cinq voisins les deux années. Cette hausse va dans le même sens que celle des effectifs de la question 7 (+23,2 % entre 2008 et 2011), sans que cela prouve un lien.

**Attention :** un taux brut peut dépasser 100 % (redoublants, entrées tardives). Un taux plus élevé n'est pas « meilleur ».

### Question 10 : les trous dans les séries du Togo

Pour les séries d'éducation d'au moins 30 valeurs, les trous sont **partagés par des blocs de séries** :

- **1993** manque dans au moins 235 des 245 séries étudiées, soit au moins 95,9 % (216 seule, 19 avec 1992) ; le creux est propre au Togo (267 indicateurs en 1993 contre 508 en 1992, alors que l'ensemble de la base ne baisse pas) ;
- **1997 à 1998** : 128 séries (52 %) ; **1977** : 100 (41 %) ; **1973 à 1975** : 99 (40 %) ;
- les trous les plus longs concernent le supérieur (1999 à 2005, 7 ans) et `UIS.OAEP.1` (2009 à 2014) ;
- quatre séries de taux net et d'accès partagent le trou 2009 à 2013 de `SE.PRM.TENR`.

Une série d'au moins 30 valeurs peut avoir jusqu'à un tiers de ses années absentes (15 sur 45 pour `UIS.OAEP.1`).

---

## Limites

- **Un seul indicateur de départ** : les conclusions ne portent que sur les indicateurs analysés et ne décrivent pas l'éducation au Togo dans son ensemble.
- **Aucune explication causale** : les reculs, les creux de 2005 et 2009, la hausse de 2015 et les années manquantes ne sont documentés ni par la source ni par ces requêtes.
- **Classements partiels** : seuls les pays ayant une valeur sont classés (26 sur 48 en 2014, 43 sur 48 en 2011). Un rang ne dit rien des pays absents.
- **Années manquantes** : le Togo n'a aucune valeur de `SE.PRM.TENR` de 2009 à 2013 ni avant 1999, et ses séries ont des trous partagés (1993, 1997-1998, 1973-1975).
- **Cohérence interne seulement** : le test de la question 7 et la concordance de la question 8 ne prouvent pas que les chiffres de départ sont justes.
- **Code `VGB`** : présent dans les valeurs, absent de la table des pays, donc exclu des analyses avec jointure.
- **Groupes de revenu** : repris du fichier utilisé ; la Banque mondiale les révise régulièrement, ils peuvent différer du classement actuel.
- **Contrôle de conversion partiel** : cinq années comparées sur 48 (toutes concordent).
- **Affichage limité** : DBeaver n'affiche que 200 lignes par défaut ; les résultats de la requête 10a et 10b sont partiels.
- **Scripts non relancés en un seul passage** : testés requête par requête, pas depuis une base vide.

## Pistes pour aller plus loin

- Refaire une partie de l'analyse en Python (pandas) pour la comparer aux résultats SQL.
- Construire un tableau de bord (Looker Studio) sur les indicateurs étudiés.

## Compétences mises en œuvre

Import de données volumineuses et résolution d'erreurs, audit de qualité, nettoyage et transformation (ETL), jointures sur plusieurs tables, anti-jointures, CTE, vues, fonctions de fenêtre, pivots, contrôles de cohérence, esprit critique sur les données (couverture, valeurs manquantes, limites).

---

## English summary

This project imports and cleans the World Bank **EdStats** education dataset (886,930 raw rows, 3,665 indicators) into **PostgreSQL**, builds a clean long-format table of 4,207,789 rows, and separates 216 real countries from 25 aggregates. Ten SQL questions are answered, with window functions, pivots and consistency checks. Togo's net primary enrolment rate rises from 88.5% (1999) to 97.5% (2015), and its gender parity index from 0.446 to 0.947 (1971 to 2015). Togo ranks 9th of 26 countries in 2014 on the net rate (the ranking covers only 54% of the region). The data have many gaps (for instance, 1993 is missing in at least 235 of 245 Togo series), and no causal explanation is claimed.
