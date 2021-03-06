

-- Recommender system based on Jaccard similarity 
-- This porgram considers the rating data as Binary 1/0 and uses Item based collaborative filtering to Recommend Top 3 Items
-- With actual ratings Pearson correlation and other similarities can be used

-- Load the data
ratings = LOAD 'data.csv' USING PigStorage(',') AS (user_id:int, movie_id:int, rating:int) ;
 
-- Limit the dataset with at least N ratings/plays at STEP D if needed ;

B = GROUP ratings BY movie_id ;
C = FOREACH B GENERATE group AS movie_id, COUNT($1) AS count ;
D = FILTER C BY count >= 1  ;
E = FOREACH D GENERATE movie_id AS movie_ok,count as count ;
F = JOIN ratings BY movie_id, E BY movie_ok ;
filtered = FOREACH F GENERATE user_id, movie_id, rating,count ;

-- Creating coratings with a self join ;

filtered_2 = FOREACH F GENERATE user_id AS user_id_2, movie_id AS movie_id_2, rating AS rating_2, count as count_2 ;
pairs = JOIN filtered BY user_id, filtered_2 BY user_id_2 ;
 
-- Eliminate dupes (item1,item1);

J = FILTER pairs BY movie_id != movie_id_2 ;
 

K = FOREACH J GENERATE 
movie_id as movie_id ,movie_id_2  as movie_id_2,
count as count,count_2 as count_2;


L = GROUP K BY (movie_id, movie_id_2) ;


-- Generate the data for Jaccard similarity 
 
co = foreach L 
{ 
disc = DISTINCT K;
nn = foreach disc generate count as count,count_2 as count_2;
generate flatten(group) as (movie_id,movie_id_2),
COUNT(K.movie_id) AS N,
flatten(nn) as (count,count_2);
};

-- LIMIT based on minimum number of times the pair occurs

nco = FILTER co BY N >=1;


-- Calculate jaccard similarity

simi = foreach nco GENERATE movie_id,movie_id_2,count,count_2,N,
(double)(N)/(double)(count+count_2-N) as zacsim;


-- Getting the Top 3 similar items for every item (K = 3 model)


zacgroup = GROUP simi by movie_id;

top3 = FOREACH zacgroup {
       zacord = ORDER simi BY zacsim DESC;
       topzac = LIMIT zacord 3;
       GENERATE flatten(topzac);
};


-- store the item based model if needed

store top3 into 'topsongs' using PigStorage(',','-schema'); 




-- Making Recommendations (Based on R Recommenderlab Predict method )

-- To pass a new data set apart from the model - pass it to userout

item_matrix = foreach top3 generate movie_id as movie_id,movie_id_2 as movie_id_2,zacsim as zacsim;
userout = foreach ratings generate user_id as user_id,movie_id as movie_id;

Joined = join userout by movie_id, item_matrix by movie_id_2;
Joindata = foreach Joined generate user_id as user_id,item_matrix::movie_id as movie_id,movie_id_2 as movie_id_2,zacsim as zacsim;

--groups = group joined by (user, row);

--removing already seen items

bgrp = cogroup Joindata BY (user_id,movie_id),userout BY (user_id,movie_id)  ;
b_minus = filter bgrp BY IsEmpty(userout);    
b_m_data = foreach b_minus generate flatten(Joindata); 


-- calculating the average simlarity ( cross product -> sum and divide by the count )

sumgrp = group b_m_data BY (user_id,movie_id);                                               
sumdata = foreach sumgrp generate flatten(group) as (user,movie),(float)SUM(b_m_data.zacsim)/COUNT(b_m_data.zacsim) as asimi;

-- limting the Top3 recommendations

usergrp = group sumdata by user;
reco = foreach usergrp {
ord = ORDER sumdata BY asimi DESC;
l = LIMIT ord 3; 
generate flatten(l);};



