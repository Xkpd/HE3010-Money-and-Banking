Endogeneity (Instrumental Variable)
there is correlation between X and error term (unobservable variable e.g. motivation) --> error term affects both X and Y at the same time
violation of E(Error term|X) = 0

solution: 
- Instrumental variable: related to X but not Y. (the only way it is related to Y is through X e.g. lag_1 X)

Heteroskedasity
variance of error term is not constant
- unreliable variance of X and Y
- CI unreliable
- but coefficient does not change
reason: some data are spread out / noisy e.g. rich family has more variation in speding than poor. household consumptino = income + u

solution:
- sobust s.e.


	•	DIFF-GMM:
Uses lagged levels as instruments for the differenced equation. It can suffer from weak instrument issues when your variables are highly persistent.
	•	SYS-GMM:
Combines the differenced equation with the level equation, using lagged differences as instruments for the levels. This generally improves efficiency, especially in short panels with many units and few time periods.
