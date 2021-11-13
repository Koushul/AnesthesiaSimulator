class NaiveModel(object):
    
    def __init__(self):        
        self.thresholds = {
            'age': 70.0,
            'weight': 200.0,
            'meld': 20,
            'bmi': 0.75
        }
        
        self.indexes = {}
    
    def _update_threshold(self, attr):
        idx = self.indexes[attr]
        search_space = range(int(self.X.values[:, idx].min()), int(self.X.values[:, idx].max()))
        solutions = [accuracy_score(self.y, (self.X.values[:, idx] > i).astype(int)) for i in search_space]
        self.thresholds[attr] = search_space[np.argmax(solutions)]
        
    
    def fit(self, X, y):
        self.X = X.reset_index().dropna().set_index('stay_id')
        self.y = y.reset_index().loc[X.reset_index().dropna().index][0].values
        
        self.X, self.y = under_sampler.fit_resample(self.X, self.y)
        
        self.indexes['age'] = list(self.X.columns).index('age')
        self.indexes['weight'] = list(self.X.columns).index('patientweight')
        self.indexes['meld'] = list(self.X.columns).index('meld')
        self.indexes['bmi'] = list(self.X.columns).index('BMI')
        
        for attr in self.indexes:
            self._update_threshold(attr)
            
    def predict(self, X):
        age_pred = (X.values[:, self.indexes['age']] > self.thresholds['age']).astype(int)
        weight_pred = (X.values[:, self.indexes['weight']] > self.thresholds['weight']).astype(int)
        meld_pred = (X.values[:, self.indexes['meld']] > self.thresholds['meld']).astype(int)
        bmi_pred = (X.values[:, self.indexes['bmi']] > self.thresholds['bmi']).astype(int)
        
        return np.array([1 if i > 1 else 0 for i in sum([age_pred, weight_pred, meld_pred, bmi_pred])])