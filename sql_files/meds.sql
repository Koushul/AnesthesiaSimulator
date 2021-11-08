--# next table to work on is medication table. this one is more complicated 
--#First i identified all meds names  given before intubation in the last 24 hour before intubation to 20 min after
--#given only in this admission period prior to intubation 
--#and of those I manually skimmed throguh and used my judgement to identify most relevent meds 
--#that were most commonly present in this period

SELECT  drug  , count(drug) as count
FROM  `anes-sim.hari.intubs` as intubs 

left join `physionet-data.mimic_core.admissions` as adm
on (
    intubs.hadm_id=adm.hadm_id and intubs.subject_id=adm.subject_id
)

left join `physionet-data.mimic_hosp.prescriptions` as emar 
on (
    intubs.subject_id=emar.subject_id 
)

where (
        timestamp_diff(intubs.starttime,emar.starttime, minute ) > -20
        and 
        timestamp_diff(intubs.starttime,emar.starttime, minute ) < timestamp_diff(intubs.starttime, adm.admittime, minute)
        and 
        timestamp_diff(intubs.starttime,emar.stoptime, minute ) < (24*60)
)
group by drug
order by count DESC 

--# the output table of the frequncy and name is here 
--# one or two repeat labels but thats ok 
--#lowest freq is 114 administration in nealry 9000 k pts.
    
-- Furosemide  6503
-- Metoprolol Tartrate 5101
-- Propofol    5024
-- Fentanyl Citrate    3589
-- Lorazepam   3053
-- HYDROmorphone (Dilaudid)    2923
-- Haloperidol 1541
-- Nitroglycerin   1531
-- Midazolam   1451
-- PHENYLEPHrine   1449
-- NORepinephrine  1396
-- HydrALAzine 1390
-- Albuterol Inhaler   1288
-- Amiodarone  1243
-- Labetalol   1240
-- Phenylephrine   1179
-- Diltiazem   1036
-- Ipratropium-Albuterol Neb   1034
-- Dexmedetomidine 970
-- LORazepam   888
-- OxycoDONE (Immediate Release)   839
-- OxyCODONE (Immediate Release)   745
-- Ipratropium Bromide MDI 713
-- Octreotide Acetate  704
-- HydrALAZINE 547
-- Diazepam    521
-- Neostigmine 513
-- Midodrine   426
-- Amlodipine  368
-- Norepinephrine  320
-- TraMADOL (Ultram)   300
-- Carvedilol  243
-- Nitroglycerin SL    240
-- OxycoDONE Liquid    237
-- Methadone   223
-- Succinylcholine 221
-- Metoprolol Succinate XL 181
-- Esmolol 158
-- Chloraseptic Throat Spray   157
-- Atropine Sulfate    157
-- Artificial Tears Preserv. Free  156
-- TraMADol    155
-- Milrinone   153
-- DOPamine    153
-- Etomidate   150
-- Nimodipine  149
-- Racepinephrine  143
-- DOBUTamine  114

--# to make the drug table with this list I went in steps instead of one long code
--# first step 
--# for unique intubations in intubs ( by selecting subject id and stay_id)
--# i joined the unique emar ( which has unique ( by emar_id) drug administration info)
--# so now a table with every intubations drug administration between -24 hours to  20 min is a seperate row. 
--# i grouped by subject,stayid and medication name. 
--# emar id also had the property of being a chronologically increasing number so a max (emar_id) for a particualr subject
--# in a set will be the most recent administration 
--# i cal it pt- drug administration-intersection table pt_drug_x

drop table if exists `anes-sim.hari.pt_drug_x`;
create table `anes-sim.hari.pt_drug_x`  as 
SELECT  intubs.subject_id ,intubs.stay_id,emar.medication,max(emar.emar_id) as recent_admin
FROM  `anes-sim.hari.intubs` as intubs 
left join `physionet-data.mimic_hosp.emar` as emar 
on (
    intubs.subject_id=emar.subject_id 
    and intubs.hadm_id = emar.hadm_id
)

where (
        timestamp_diff(intubs.starttime,emar.charttime, minute ) > -20
        and 
        timestamp_diff(intubs.starttime,emar.charttime, minute ) < (60*24)

)

group by intubs.subject_id ,intubs.stay_id,emar.medication

--#now with that table where I know emar_ids for all the most recent administrations of medicine for all intubes
--# i pick out by label the administrations I want in a table called  ptx_info

drop table if exists `anes-sim.hari.ptx-info`;
create table `anes-sim.hari.ptx-info` # as
select ptx.* 
from `anes-sim.hari.pt_drug_x` as ptx
where ptx.medication in (
"Furosemide",
"Metoprolol Tartrate",
"Propofol",
"Fentanyl Citrate",
"Lorazepam",
"HYDROmorphone (Dilaudid)",
"Haloperidol",
"Nitroglycerin",
"Midazolam",
"PHENYLEPHrine",
"NORepinephrine",
"HydrALAzine",
"Albuterol Inhaler",
"Amiodarone",
"Labetalol",
"Phenylephrine",
"Diltiazem",
"Ipratropium-Albuterol Neb",
"Dexmedetomidine",
"LORazepam",
"OxycoDONE (Immediate Release)",
"OxyCODONE (Immediate Release)",
"Ipratropium Bromide MDI",
"Octreotide Acetate",
"HydrALAZINE",
"Diazepam",
"Neostigmine",
"Midodrine",
"Amlodipine",
"Norepinephrine",
"TraMADOL (Ultram)",
"Carvedilol",
"Nitroglycerin SL",
"OxycoDONE Liquid",
"Methadone",
"Succinylcholine",
"Metoprolol Succinate XL",
"Esmolol",
"Chloraseptic Throat Spray",
"Atropine Sulfate",
"Artificial Tears Preserv. Free",
"TraMADol",
"Milrinone",
"DOPamine",
"Etomidate",
"Nimodipine",
"Racepinephrine",
"DOBUTamine"

)

--# now this needs more detail so i left join it with a table called emar_detail which has a ton of detail for the uniqe emar_id. 

create table `anes-sim.hari.ptx-info-dose` # as
select ptx_info.*,emard.emar_id, emard.administration_type, emard.dose_given,emard.dose_given_unit,emard.prior_infusion_rate, emard.infusion_rate,emard.infusion_rate_adjustment,emard.infusion_rate_adjustment_amount,emard.infusion_rate_unit,
emard.pharmacy_id,emard.route,emard.product_code,emard.product_description,emard.product_amount_given, emard.product_unit,emard.product_description_other,

from `anes-sim.hari.ptx-info` as ptx_info
left join `physionet-data.mimic_hosp.emar_detail` as emard
on ptx_info.recent_admin = emard.emar_id 
where ptx_info.subject_id=emard.subject_id

--# now this tabel is what we can use for drug table 
--# there is  unique intersection between (subject, hadm_id ) or (subject, stay_id) and medication and emmar_id and all the deails. 
--# wach drug for a patient can be a query .
--# one issue. some drugs are ininfusion some in dose, some in different units. 
--# this is a big tabel which needs some discretion on what col you will pick as input variables dependign on the drug. 
--# see if you can figure it out if not I will work it and send you soonish. 
--# we can start on the ML now. anyhanges will be minor. 
--# lab data may be another table but that will be simpler. and it is like i said optional. 


