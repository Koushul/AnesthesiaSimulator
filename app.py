import streamlit as st
import numpy as np
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from matplotlib.pyplot import figure
from pathlib import Path
from sklearn.metrics import plot_confusion_matrix
# import optuna
import time
import shap
from optuna import create_study
from optuna.samplers import TPESampler
from optuna.integration import XGBoostPruningCallback
from xgboost import XGBRegressor, XGBClassifier
from sklearn.model_selection import train_test_split
from sklearn.model_selection import RepeatedKFold
import json
import random
from sklearn.model_selection import RepeatedStratifiedKFold, cross_val_score
from sklearn.metrics import accuracy_score
from collections import Counter
from sklearn.linear_model import LogisticRegression
import sklearn
from imblearn.under_sampling import RandomUnderSampler
from imblearn.over_sampling import  RandomOverSampler
from sklearn.metrics import accuracy_score, f1_score, precision_score, recall_score, roc_auc_score

st.title('Anesthesia Adverse Event Simulator')

data_path = Path('anes-data')

with open('config.json') as f:
        config = json.load(f)


intubs = pd.read_csv(data_path / 'intubs.csv')
ptx_info_dose = pd.read_csv(data_path / 'ptx-info-dose.csv')
outcome_vitals = pd.read_csv(data_path / 'outcome_vitals.csv')
ptx_info = pd.read_csv(data_path / 'ptx-info.csv')
avg_vitals = pd.read_csv(data_path / 'avg_vitals.csv')
pt_drug_x = pd.read_csv(data_path / 'pt_drug_x.csv')
intubes_pt_info = pd.read_csv(data_path / 'intubes_pt_info.csv')

outcome_vitals = outcome_vitals.drop(['sbp_ni', 'dbp_ni', 'mbp_ni'], axis=1)
avg_vitals = avg_vitals.drop(['avg_sbp_ni', 'avg_dbp_ni', 'avg_mbp_ni'], axis=1)

patient_data = (intubes_pt_info
        .drop('subject_id', axis=1)
        .set_index('stay_id')
        .join(avg_vitals.drop('subject_id', axis=1)
        .set_index('stay_id'), how='inner')
        .reset_index()
        .drop(['hadm_id'], axis=1)
        .set_index('stay_id')
        .join(avg_vitals[['subject_id', 'stay_id']]
        .set_index('stay_id'))
        .join(intubs.set_index('stay_id')['patientweight'])
        .drop_duplicates())

drugs = config['drugs']
drugs = list(set(pt_drug_x.medication) & set(drugs))
dosage = ptx_info_dose[ptx_info_dose.medication.isin(drugs)][['subject_id', 'stay_id', 'medication', 'dose_given', 'dose_given_unit']].dropna()
encoded_ptx_drugs = pd.get_dummies(pt_drug_x.set_index('stay_id').medication)[drugs].reset_index().groupby('stay_id').sum()
patient_data = patient_data.join(encoded_ptx_drugs, how='left').drop_duplicates().drop(['avg_sbp', 'avg_dbp'], axis=1)
patient_data[drugs] = patient_data[drugs].fillna(value=0)
dosage['encoded_dose'] = dosage.apply(lambda x: f'{x.medication}_{x.dose_given}_{x.dose_given_unit}', axis=1)
patient_data = patient_data.join(dosage.set_index('stay_id').drop('subject_id', axis=1)['encoded_dose']).drop_duplicates()
patient_data = patient_data.join(pd.get_dummies(patient_data.gender)).drop('gender', axis=1)
patient_data = patient_data.join(pd.get_dummies(patient_data['encoded_dose']).reset_index().groupby('stay_id').sum().applymap(lambda x: 1 if x > 0 else 0)).drop('encoded_dose', axis = 1)
patient_data['BMI'] = patient_data['patientweight'] / patient_data['height']

st.sidebar.title('Adverse Event Definitions')

HR_LOW = st.sidebar.slider('Heart Rate too low', 
        min_value=int(patient_data['avg_hr'].min()), 
        max_value=int(patient_data['avg_hr'].max()), 
        value=int(patient_data['avg_hr'].mean()),
        step=1)

HR_HIGH = st.sidebar.slider('Heart Rate too high', 
        min_value=int(patient_data['avg_hr'].min()), 
        max_value=int(patient_data['avg_hr'].max()), 
        value=int(patient_data['avg_hr'].mean()),
        step=1)

RR_LOW = st.sidebar.slider('Respiration Rate too low', 
        min_value=int(patient_data['avg_rr'].min()), 
        max_value=int(patient_data['avg_rr'].max()), 
        value=int(patient_data['avg_rr'].mean()),
        step=1)

SPO2_LOW = st.sidebar.slider('Oxygen Saturation too low', 
        min_value=int(patient_data['avg_spo2'].min()), 
        max_value=int(patient_data['avg_spo2'].max()), 
        value=int(patient_data['avg_spo2'].mean()),
        step=1)

def get_event(avg_hr, avg_mbp, avg_rr, avg_spo2, avg_glucose):
    hr = False
    rr = False
    spo2 = False
    gluc = False
    
    if avg_hr < HR_LOW or avg_hr > HR_HIGH:
        hr = True
    if avg_rr < RR_LOW:
        rr = True
    if avg_spo2 < SPO2_LOW:
        spo2 = True
#     if avg_glucose < 100:
#         gluc = True
        
    if any([hr, rr, spo2, gluc]): return 1
    else: return 0

under_sampler = RandomUnderSampler()
X_ = patient_data.drop(['subject_id', 'avg_hr', 'avg_mbp', 'avg_rr', 'avg_temp', 'avg_spo2', 'avg_glucose'], axis=1)
y_ = patient_data[['avg_hr', 'avg_mbp', 'avg_rr', 'avg_spo2', 'avg_glucose']].apply(lambda x: get_event(x.avg_hr, x.avg_mbp, x.avg_rr, x.avg_spo2, x.avg_glucose), axis=1)
X, y = under_sampler.fit_resample(X_, y_)

model = XGBClassifier(**config['xgboost_params'], use_label_encoder=False, eval_metric='logloss')
model.fit(X, y)

col1, col2, col3 = st.columns(3)
options = list(set(dosage.medication))


drug_combos = [{}, {}, {}, {}, {}, {}, {}, {}]
drug_selection = []

col1.write('Drug')
col2.write('Dose')
col3.write('Unit')

# for i in [0, 1, 2, 3, 4, 5, 6, 7]:
for i in [0, 1, 2]:
        key = str(i)
        with col1:
                drug_combos[i]['drug'] = drug = st.selectbox('', ['None'] + list(set(options)), key=key)
        if drug != 'None':
                options.remove(drug)
                with col2:
                        drug_combos[i]['dose'] = dose = st.selectbox('', np.unique(dosage[dosage.medication == drug]['dose_given']), key=key)
                with col3:
                        drug_combos[i]['unit'] = unit = st.selectbox('', np.unique(dosage[dosage.medication == drug]['dose_given_unit']), key=key)
        
                drug_selection.append(f'{drug}_{dose}_{unit}')

drug_selection = list(set(dosage['encoded_dose']) & set(drug_selection))

age = st.slider('Age', 
        min_value=int(patient_data['age'].min()), 
        max_value=int(patient_data['age'].max()), 
        value=int(patient_data['age'].mean()),
        step=1)

patientweight = st.slider('Weight', 
        min_value=int(patient_data['patientweight'].min()), 
        max_value=int(patient_data['patientweight'].max()), 
        value=int(patient_data['patientweight'].mean()),
        step=1)

height = st.slider('Height', 
        min_value=int(patient_data['height'].min()), 
        max_value=int(patient_data['height'].max()), 
        value=int(patient_data['height'].mean()),
        step=1)

meld = st.slider('MELD', 
        min_value=int(patient_data['meld'].min()), 
        max_value=int(patient_data['meld'].max()), 
        value=int(patient_data['meld'].mean()),
        step=1)

bmi = patientweight / height

df = pd.DataFrame(np.zeros(len(X.columns)).reshape(1, -1), columns=X.columns)
df.age = age
df.height = height
df.bmi = bmi
df.medl = meld
df.patientweight = patientweight

for i in drug_selection:
        df[i] = 1

p = model.predict_proba(df)

if p[0][1] > 0.5:
        st.error(f'Adverse Event Predicted with Probability {round(100*p[0][1], 2)} %')
else:
        st.success(f'No Adverse Event with Probability {round(100*p[0][0], 2)} %')


st.set_option('deprecation.showPyplotGlobalUse', False)

explainer = shap.TreeExplainer(model)
shap_values = explainer(df)
shap.plots.waterfall(shap_values[0])
st.pyplot()