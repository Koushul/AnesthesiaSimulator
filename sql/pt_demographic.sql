-- Works on getting basic demographics 
# then i worked on second demographic information table 
# I added the patient demographic information from  a prederived table called mimic_derived and 
# jused joins to make a single table 
# meld score i had to calculate and average since they are calcualted at random times and i am interested in 
# the meld in the hosp admission before intubation

drop table if exists `anes-sim.hari.intubs_pt_info`;

create table `anes-sim.hari.intubs_pt_info`   as

select intubs.subject_id,intubs.hadm_id,intubs.stay_id, ag.age,ht.height,pt.gender
,comp_meld.meld

from `anes-sim.hari.intubs` as intubs 

left join `physionet-data.mimic_derived.age` as ag on (ag.hadm_id =intubs.hadm_id)

left join  `physionet-data.mimic_derived.height` as ht on (ht.stay_id =intubs.stay_id )

left join `physionet-data.mimic_core.patients` as pt  on (pt.subject_id = intubs.subject_id)

left join
    (
        select intubs.subject_id, intubs.hadm_id, intubs.stay_id ,avg(meld_initial) as meld from 
        `physionet-data.mimic_derived.meld` as mel , `anes-sim.hari.intubs` as intubs 
         where (mel.subject_id = intubs.subject_id 
         and  mel.hadm_id =  intubs.hadm_id 
         and mel.stay_id = intubs.stay_id)
        group by subject_id,hadm_id,stay_id
        ) as comp_meld

    on (intubs.subject_id=comp_meld.subject_id and intubs.hadm_id=comp_meld.hadm_id and intubs.stay_id = comp_meld.stay_id)

# so if there were more than one meld i averge out any meld_initial that may be there to avoid duplicate in table 


