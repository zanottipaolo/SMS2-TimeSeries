% Owners:
% De Duro Federico      1073477
% Medolago Emanuele     1058907    
% Zanotti Paolo         1074166

% Dependencies
% 1. Image Processing Toolbox (for 'immse')

rng(1)
addpath("Mskekur\")
addpath("tHet.m\")

close all
clearvars
clc

load('dataset.mat');
tNordOvest = T(:, 2:7);
tNordEst = T(:, 8:13);
tCentro = T(:, 14:19);
tSud = T(:, 20:25);
tIsole = T(:, 26:end);
% Stima dei dati mancanti con media mobile
T_Stimata = T;
steps = 7;
for i = 1:width(T_Stimata)
    for j = 1:height(T_Stimata)
        if isnan(T_Stimata{j,i})
            lower = j - steps;
            upper = j + steps;

            if lower < 1
                lower = 1;
            end
            if upper > width(T_Stimata)
                upper = width(T_Stimata);
            end
            somma = 0;
            count = 0;
            for k = lower:upper
                if isnan(T_Stimata{k, i})  
                else
                    somma = somma + T_Stimata{k, i};
                    count = count + 1;
                end
            end
            T_Stimata{j,i} = somma / count;
        end
    end
end

% Plot del dataset dato, con quello stimato
subplot(2,1,1)
x = T.ANNO;
y1 = T_Stimata{:,2:end};
plot(x,y1)

subplot(2,1,2); 
y2 = T{:,2:end};
plot(x,y2)

close all

tNordOvest = T_Stimata(:, 2:7);
tNordEst = T_Stimata(:, 8:13);
tCentro = T_Stimata(:, 14:19);
tSud = T_Stimata(:, 20:25);
tIsole = T_Stimata(:, 26:end);
NE_lm1 = fitlm(tNordEst,'ResponseVar','NE_IPERTENSIONE', 'PredictorVars',{'NE_DIABETE','NE_ECCESSO_PESO','NE_MA_ALLERGICHE'});

%% forecast regressione lineare
xlm = [tNordEst.NE_DIABETE(1:end-5,:) tNordEst.NE_MA_ALLERGICHE(1:end-5,:) tNordEst.NE_ECCESSO_PESO(1:end-5,:)];
ylm = tNordEst.NE_IPERTENSIONE(1:end-5,:);
x_last5 = [tNordEst.NE_DIABETE(end-4:end,:) tNordEst.NE_MA_ALLERGICHE(end-4:end,:) tNordEst.NE_ECCESSO_PESO(end-4:end,:)];

lm_NE = fitlm(xlm,ylm);
[ypred, yci] = predict(lm_NE, x_last5, 'alpha', 0.05, 'Prediction', 'observation', 'Simultaneous','on');
% err = immse(ypred, tNordEst.NE_IPERTENSIONE(end-4:end));
mse = mean((tNordEst.NE_IPERTENSIONE(end-4:end)-ypred).^2)

figure
    plot([2010 2011 2012 2013 2014], ypred)
    title('Previsione dal 2010 al 2014 tramite regressione lineare')
hold on
    grid
    plot([2010 2011 2012 2013 2014], yci,'k--')
    plot([2010 2011 2012 2013 2014], tNordEst.NE_IPERTENSIONE(end-4:end),'r')
    legend('previsione','IC 95% lb','IC 95% ub','osservazione')
    ylabel('Casi di ipertensione [%]');
    xlabel('Anno [2010 - 2014]')
hold off

%% Regressione dinamica
params = [1 1 1 1];
x_regDin = [tNordEst.NE_DIABETE tNordEst.NE_MA_ALLERGICHE tNordEst.NE_ECCESSO_PESO];
y_regDin = tNordEst.NE_IPERTENSIONE;

funzioneMap = @(params) map(params, x_regDin, lm_NE.Coefficients.Estimate(1), NE_lm1.Coefficients.Estimate(2), NE_lm1.Coefficients.Estimate(3), NE_lm1.Coefficients.Estimate(4));
modelNE = ssm(funzioneMap)
estModel = estimate(modelNE, y_regDin, params)

obs_err = (cell2mat(estModel.D).^2)
sta_err = ((estModel.B).^2)

filterMdl = filter(estModel,y_regDin);
alpha_flt = filterMdl(:,1);
beta_flt = filterMdl(:,2:4);
beta_flt1 = filterMdl(:,2);
beta_flt2 = filterMdl(:,3);
beta_flt3 = filterMdl(:,4);

smoothMdl = smooth(estModel,y_regDin);
alpha_smo = smoothMdl(:,1);

beta_smo1 = smoothMdl(:,2);
beta_smo2 = smoothMdl(:,3);
beta_smo3 = smoothMdl(:,4);

% Filter
y3_flt = alpha_flt + (beta_flt1.*x_regDin(:,1)) + (beta_flt2.*x_regDin(:,2)) + (beta_flt3.*x_regDin(:,3));
res = y_regDin - y3_flt;
mean_res = mean(res)
adftest(res)

figure
  subplot(2,2,1)
    plot(res)
    yline(mean_res)
    xlabel('Osservazioni [0-25]')
    ylabel('Valore residuo')
    grid
    title('Residui')
  subplot(2,2,2)
    histfit(res)
    title('Istogramma residui')
  subplot(2,2,3)
    autocorr(res)
    title('Autocorrelazione')
  subplot(2,2,4)
    parcorr(res,'Method','yule-walker')
    title('Autocorrelazione parziale')

figure
  plot(T.ANNO, y3_flt)
  grid
  ylabel('Casi di ipertensione [%]')
  xlabel('Anno [1990 - 2014]')
  title('Confronto osservazioni stimate - osservazioni reali')
hold on
  plot(T.ANNO, y_regDin)
  legend('Filter','Osservazioni')
hold off

% Smooth
y3_smo = alpha_smo + (beta_smo1.*x_regDin(:,1)) + (beta_smo2.*x_regDin(:,2)) + (beta_smo3.*x_regDin(:,3));
res = y_regDin - y3_smo;
mean_res = mean(res)
adftest(res)

figure
  subplot(2,2,1)
    plot(res)
    yline(mean_res)
    title('Residuals')
  subplot(2,2,2)
    histfit(res)
    title('Histfit Residuals')
  subplot(2,2,3)
    autocorr(res)
  subplot(2,2,4)
    parcorr(res,'Method','yule-walker')

figure
  plot(T.ANNO, y3_smo)
  grid
  ylabel('Casi di ipertensione [%]')
  xlabel('Anno [1990 - 2014]')
  title('Confronto osservazioni stimate - osservazioni reali')
hold on
  plot(T.ANNO, y_regDin)
legend('Smooth','Osservazioni')
hold off

% Previsione un passo in avanti
alpha_flt_forecast = [nan; alpha_flt(1:end-1)];
beta_flt_forecast = [nan nan nan; beta_flt(1:end-1,:)];

beta_flt_forecast1 = beta_flt_forecast(:,1);
beta_flt_forecast2 = beta_flt_forecast(:,2);
beta_flt_forecast3 = beta_flt_forecast(:,3);

y3_frc = alpha_flt_forecast + beta_flt_forecast1.*x_regDin(:,1) + beta_flt_forecast2.*x_regDin(:,2) + beta_flt_forecast3.*x_regDin(:,3);
res = y_regDin - y3_frc;
mean_res = nanmean(res)
adftest(res)

figure
  subplot(2,2,1)
    plot(res)
    yline(mean_res)
    title('Residuals')
  subplot(2,2,2)
    histfit(res)
    title('Histfit Residuals')
  subplot(2,2,3)
    autocorr(res)
  subplot(2,2,4)
    parcorr(res,'Method','yule-walker')

figure
    plot(y3_frc)
hold on
    plot(y_regDin)
hold off

% forecast regressione dinamica
params = [1 1 1 1];
x1 = [tNordEst.NE_DIABETE(1:end-5,:) tNordEst.NE_MA_ALLERGICHE(1:end-5,:) tNordEst.NE_ECCESSO_PESO(1:end-5,:)];
y1 = tNordEst.NE_IPERTENSIONE(1:end-5);

funzioneMap = @(params) map(params, x1, lm_NE.Coefficients.Estimate(1), lm_NE.Coefficients.Estimate(2), lm_NE.Coefficients.Estimate(3), lm_NE.Coefficients.Estimate(4));
modelNE = ssm(funzioneMap)

[estModel,estParams] = estimate(modelNE, y1, params);
x_reg = [ones(length(tNordEst.NE_DIABETE(1:end-5,:)),1) tNordEst.NE_DIABETE(1:end-5,:) tNordEst.NE_MA_ALLERGICHE(1:end-5,:) tNordEst.NE_ECCESSO_PESO(1:end-5,:)];
x_last5_reg = [ones(length(tNordEst.NE_DIABETE(end-4:end,:)),1) tNordEst.NE_DIABETE(end-4:end,:) tNordEst.NE_MA_ALLERGICHE(end-4:end,:) tNordEst.NE_ECCESSO_PESO(end-4:end,:)];
[yFregDin, yVar] = forecast(estModel, 5, y1, 'Predictors0', x_reg, 'PredictorsF', x_last5_reg, 'Beta', estParams)
% err = immse(yFregDin,tNordEst.NE_IPERTENSIONE(end-4:end))
mse = mean((tNordEst.NE_IPERTENSIONE(end-4:end)-yFregDin).^2)
ForecastIntervals(:,1) = yFregDin - 1.96*sqrt(yVar);
ForecastIntervals(:,2) = yFregDin + 1.96*sqrt(yVar);

figure
    plot([2010 2011 2012 2013 2014], yFregDin)
    title('Previsione dal 2010 al 2014 tramite regressione dinamica')
hold on
grid
    plot([2010 2011 2012 2013 2014], ForecastIntervals,'k--')
    plot([2010 2011 2012 2013 2014], tNordEst.NE_IPERTENSIONE(end-4:end),'r')
    legend({'Previsione','IC 95% lower bound','IC 95% upper bound','Osservazione'})
    ylabel('Casi di ipertensione [%]');
    xlabel('Anno [2010 - 2014]')
hold off

%% RegArima - Tolto il regressore malattie allergiche perché non significativo
%Ciclo per determinare BIC, q e p
x = [tNordEst.NE_DIABETE(1:end-5,:) tNordEst.NE_ECCESSO_PESO(1:end-5,:)];
y = tNordEst.NE_IPERTENSIONE(1:end-5,:);
x_last5 = [tNordEst.NE_DIABETE(end-4:end,:) tNordEst.NE_ECCESSO_PESO(end-4:end,:)];

q_vector = [0 1 2 3 4];
p_vector = [0 1 2 3 4];
Matrix_result = NaN(5,5);
Matrix_result2 = NaN(5,5);

format longg

for p = 0:4
    for q = 0:4
        model = regARIMA(p,0,q);
        try
            estimate_model = estimate(model, y,'X', x);
            res = infer(estimate_model, y, 'X', x);

            bic = summarize(estimate_model);
            Matrix_result(p+1, q+1) = bic.BIC;
            yF = forecast(estimate_model, 5, 'Y0', y, 'X0', x, 'XF', x_last5);
            mse = mean((tNordEst.NE_IPERTENSIONE(end-4:end)-yF).^2);
            Matrix_result2(p+1, q+1) = mse;
        catch
            % Processo non stazionario/non invertibile
            Matrix_result(p+1, q+1) = NaN;
            Matrix_result2(p+1, q+1) = NaN;
        end  
    end
end

figure
subplot(2,1,1)
plot(p_vector, Matrix_result, 'LineWidth',3)
legend({'q = 0','q = 1','q = 2','q = 3','q = 4'})
title('Andamento BIC rispetto a (p,q)', 'FontSize', 16)
xlabel("p", 'FontSize', 16);
ylabel("BIC", 'FontSize', 16);
grid
hold on
subplot(2,1,2)
plot(p_vector, Matrix_result2, 'LineWidth',3)
legend({'q = 0','q = 1','q = 2','q = 3','q = 4'})
title('Andamento MSE rispetto a (p,q)', 'FontSize', 16)
xlabel("p", 'FontSize', 16);
ylabel("MSE", 'FontSize', 16);
grid
hold off

% regARIMA(2,0,0) modello con migliore rapporto BIC e MSE e con coeff.
% significativi, stazionario
model = regARIMA(2,0,0);
x = [tNordEst.NE_DIABETE(1:end-5,:) tNordEst.NE_ECCESSO_PESO(1:end-5,:)];
y = tNordEst.NE_IPERTENSIONE(1:end-5,:);
estimate_model = estimate(model, y,'X', x,'Display','params');
res = infer(estimate_model, y, 'X', x);
estimate_y = y - res;

% calcolo soluzioni dell'equazione caratteristica
r=roots([1, -cell2mat(estimate_model.AR(1)), -cell2mat(estimate_model.AR(2))]);
modulo_r=abs(r)

% test di Dickey-Fuller
ytest = y - (estimate_model.Intercept + estimate_model.Beta(1).*x(:,1) + estimate_model.Beta(2).*x(:,2));
[h,p]=adftest(ytest);
if h == 1
    disp("processo stazionario")
else
    disp("processo non stazionario")
end

% Bootstrap parametrico IC coefficienti regArima (errori normali)
n=length(y);
m=100;
[Y,E_sim,U_sim] = simulate(estimate_model,n,'NumPaths',m,'X',x);

for j = 1:m
    estimate_model_sim = estimate(model, Y(:,j),'X', x,'Display','off');
    par_sim_NE(j,1) = estimate_model_sim.Intercept;
    par_sim_NE(j,2) = estimate_model_sim.Beta(1);
    par_sim_NE(j,3) = estimate_model_sim.Beta(2);
    par_sim_NE(j,4) = cell2mat(estimate_model_sim.AR(1));
    par_sim_NE(j,5) = cell2mat(estimate_model_sim.AR(2));
end

figure
  subplot(2,3,1)
    histfit(par_sim_NE(:,1));
    title('distribuzione intercetta NE');
  subplot(2,3,2)
    histfit(par_sim_NE(:,2));
    title('distribuzione beta diabete NE');
  subplot(2,3,3)
    histfit(par_sim_NE(:,3));
    title('distribuzione beta sovrappeso NE');
  subplot(2,3,4)
    histfit(par_sim_NE(:,4));
    title('distribuz. coeff. AR(1) NE');
  subplot(2,3,5)
    histfit(par_sim_NE(:,5));
    title('distribuz. coeff. AR(2) NE');

% media beta bootstrap
par_sim_NE_mean = mean(par_sim_NE);
% varianza beta bootstrap
par_sim_NE_var=var(par_sim_NE);
%IC 95% beta bootstrap NE
IC_NE=quantile(par_sim_NE,[0.025 0.975]);
disp('intercetta NE + IC 95% Bootstrap');
disp([IC_NE(1,1) par_sim_NE_mean(1) IC_NE(2,1)]);
disp('beta diabete NE + IC 95% Bootstrap');
disp([IC_NE(1,2) par_sim_NE_mean(2) IC_NE(2,2)]);
disp('beta sovrappeso NE + IC 95% Bootstrap');
disp([IC_NE(1,3) par_sim_NE_mean(3) IC_NE(2,3)]);
disp('coeff. AR(1) NE + IC 95% Bootstrap');
disp([IC_NE(1,4) par_sim_NE_mean(4) IC_NE(2,4)]);
disp('coeff. AR(2) NE + IC 95% Bootstrap');
disp([IC_NE(1,5) par_sim_NE_mean(5) IC_NE(2,5)]);


% forecast regArima
[yF,eVar] = forecast(estimate_model, 5, 'Y0', y, 'X0', x, 'XF', x_last5);
% err = immse(yF,tNordEst.NE_IPERTENSIONE(end-4:end))
mse = mean((tNordEst.NE_IPERTENSIONE(end-4:end)-yF).^2);
ForecastInt(:,1) = yF - 1.96*sqrt(eVar);
ForecastInt(:,2) = yF + 1.96*sqrt(eVar);

figure
hold on
plot(T.ANNO(end-4:end), yF)
plot(T.ANNO(end-4:end), tNordEst.NE_IPERTENSIONE(end-4:end))
plot(T.ANNO(end-4:end),ForecastInt,'--k')
legend('Previsione','Osservazione','IC lb','IC ub')
title("Previsione dal 2010 al 2014 tramite regArima")
xlabel("Anno [Year]",'FontSize', 16)
ylabel("Casi di ipertensione [%]", 'FontSize', 16)
grid()
hold off

% Analisi dei residui
mean_res = mean(res)
adftest(res)
figure
  subplot(2,2,1)
    plot(res)
    yline(mean_res)
    title('Residuals')
  subplot(2,2,2)
    histfit(res)
    title('Histfit Residuals')
  subplot(2,2,3)
    autocorr(res)
  subplot(2,2,4)
    parcorr(res,'Method','yule-walker')
    
% Ricerca degli outliers
dist = (1 / 19) .* ((x - mean(x).^2) / var(x));
estimate_std = sqrt(var(res)) * sqrt(1 - ((1 / 20) + dist));
residui_studentizzati = res ./ estimate_std;

figure
subplot(2,2,1)
    qqplot(res)
    title('Distribuzione Quantili teorici - Quantili residui standardizzati');
subplot(2,2,2)
    [S,AX,BigAx,H,HAx] = plotmatrix([tNordEst.NE_DIABETE(1:end-5,:) tNordEst.NE_ECCESSO_PESO(1:end-5,:)], res)
    title 'Correlazione Residui-Regressori';
    AX(1,1).YLabel.String = 'Residui';
    AX(1,1).XLabel.String = 'DIABETE';
    AX(1,2).XLabel.String = 'MALATTIE ALLERGICHE';
    title('Correlazione Residui-Regressori')
subplot(2,2,3)
    scatter(estimate_y, res, 'filled')
    title('Residuals vs Fitted data')
subplot(2,2,4)
    scatter(estimate_y, residui_studentizzati)
    xlabel("Fitted data");
    ylabel("Residui studentizzati");
    yline(3, '--b');
    yline(-3, '--b');
    title('Residui studentizzati vs Fitted data');

% Omoschedasticità
pval = TestHet(res,[tNordEst.NE_DIABETE(1:end-5,:) tNordEst.NE_ECCESSO_PESO(1:end-5,:)], '-BPK')
if pval>0.05
    disp("accetto l'ipotesi nulla, gli errori sono omoschedastici")
else
    disp("rifiuto l'ipotesi nulla, gli errori sono eteroschedastici")
end

% Verifica dell'incorrelazione tramite gli indici di correlazione
NE_mat_corr_residui = corrcoef([res, tNordEst.NE_DIABETE(1:end-5,:) tNordEst.NE_ECCESSO_PESO(1:end-5,:)], 'Rows','complete');
NE_res_corr_w_reg = NE_mat_corr_residui(2:end, 1) % Vettore di rho residui - regressori

%t test media=0
[h, pval] = ttest(res)
if h == 0
    disp("accetto l'ipotesi nulla, media residui nulla")
else
    disp("rifiuto l'ipotesi nulla, media residui diversa da zero")
end

% test di Lujing Box, residui iid
[h,pValue] = lbqtest(res)
if h == 0
    disp("accetto l'ipotesi nulla, innovazioni iid")
else
    disp("rifiuto l'ipotesi nulla, innovazioni non iid")
end

% Jb Test
x2 = res;
n = length(x2);
JBdata = (skewness(x2).^2)*n/6+((kurtosis(x2)-3).^2)*n/24;

% Simulazione MC
m = 1000;
X0 = randn(m,n);
JB0 = (skewness(X0').^2)*n/6+((kurtosis(X0')-3).^2)*n/24;
alpha = 0.05;
JBcrit = prctile(JB0,100*(1-alpha));
disp(['JBcrit_NE: ',num2str(JBcrit)]);
pval = mean(JB0>JBdata);
stdp = sqrt(pval*(1-pval)/m);
disp(['pvalue_NE: ',num2str(pval)]);
disp(['dev std pvalue_NE: ',num2str(stdp)]);
X1 = chi2rnd(2,m,n);
JB1 = (skewness(X1').^2)*n/6+((kurtosis(X1')-3).^2)*n/24;
potenza = mean(JB1>JBcrit);
disp(['potenza test_NE: ',num2str(potenza)]);
% Accetto ipotesi nulla, res normali
