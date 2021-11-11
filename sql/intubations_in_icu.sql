--This section it to identify the procedures in physionet-mimic-iv where the procedureevent is intubations and perc trachs 
-- and got the unique item_id from d_items

SELECT * FROM `physionet-data.mimic_icu.d_items` 
WHere category in  ("1-Intubation/Extubation",  
"Intubation");

--  I identified all the procedures where there was in intubation 
--  by identifying the unique subject ids and hadm_id and stay_id where there was item_id fromm above
--  and created a table INTUBS that represents all episodes of intubations and perc trachs 

create table `anes-sim.hari.intubs` as
select subject_id,hadm_id,stay_id, starttime,itemid, patientweight 
from `physionet-data.mimic_icu.procedureevents`
Where itemid in  (224385,225448)

-- this is the main table intubs that we will branch out of
-- in this table subject_id is not unique, but a combination of subject_id and hadm_id or subjectid and stay_id is unique
-- i verified that by various distinct commands
-- I explored the data to see how many procedures of intubation/ percutaneosu trach  occured in the Icu

SELECT itemid, count(*) as count  FROM `physionet-data.mimic_icu.procedureevents` 
WHere itemid in  (224385,225448)
group by itemid

#there were 8942 intubaiton and 618 perc trach 
