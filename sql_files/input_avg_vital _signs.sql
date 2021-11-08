--# next I work on another improtant table, vital signs. 
--# mimic_derived has vital sign in it i used that. 
--# i find the vital signs hr, bp, sp2 etc that have time stamps 
--#that fall within 7 hours before intubation and 5 min after
--# then I average each of these vital signs to give one number for each category 

drop table if exists `anes-sim.hari.avg_vitals`;
create table `anes-sim.hari.avg_vitals`  as

select 
subject_id,stay_id,

avg(heart_rate) as avg_hr,
avg(sbp) as avg_sbp,
avg(dbp) as avg_dbp,
avg(mbp) as avg_mbp,
avg(sbp_ni) as avg_sbp_ni,
avg(dbp_ni) as avg_dbp_ni,
avg(mbp_ni) as avg_mbp_ni,
avg(resp_rate) as avg_rr,
avg(temperature) as avg_temp,
avg (spo2) as avg_spo2,
avg(glucose) as avg_glucose

from (
    SELECT  vita.* 
    FROM `physionet-data.mimic_derived.vitalsign` as vita ,`anes-sim.hari.intubs` as intubs
    where  vita.subject_id in  (intubs.subject_id) 
    and 
    vita.stay_id=intubs.stay_id
    and 
    timestamp_diff (intubs.starttime,vita.charttime,minute)  <(7*60)
    and 
    timestamp_diff (intubs.starttime,vita.charttime,minute) >-5
)

group by subject_id,stay_id
