--# similarly i do the same thing for outcome vital signs 
--# the time is 5 minutes after to 60 minutes after 
--# averaged these readings 
--# this table will be outcome variables

drop table if exists `anes-sim.hari.outcome_vitals`;
create table `anes-sim.hari.outcome_vitals`  as

select 

subject_id,
stay_id,

avg(heart_rate) as hr,
avg(sbp) as sbp,
avg(dbp) as dbp,
avg(mbp) as mbp,
avg(sbp_ni) as sbp_ni,
avg(dbp_ni) as dbp_ni,
avg(mbp_ni) as mbp_ni,
avg(resp_rate) as rr,
avg(temperature) as temperature,
avg (spo2) as spo2,
avg(glucose) as glucose

from (
    SELECT  vita.* 
    FROM `physionet-data.mimic_derived.vitalsign` as vita ,`anes-sim.hari.intubs` as intubs
    where  vita.subject_id in  (intubs.subject_id) 
    and 
    vita.stay_id=intubs.stay_id
    and
    timestamp_diff (intubs.starttime,vita.charttime,minute)  <-5
    and 
    timestamp_diff (intubs.starttime,vita.charttime,minute) > -60
)

group by subject_id,stay_id
