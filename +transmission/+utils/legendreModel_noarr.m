function Leg_model = legendreModel_noarr(Lam, Config)
    % Calculate Legendre polynomial model for instrumental transmission
    % (direct approach without using MATLAB's legendre function)
    % Input  : - Lam (double array): Wavelength array in nm
    %          - Config (struct): Configuration struct from inputConfig()
    %            Uses Config.Utils.LegendreModel.Default_coeffs
    % Output : - Leg_model (double array): Exponential of Legendre polynomial expansion
    % Author : D. Kovaleva (Jul 2025)
    % References: 1. Ofek et al. 2023, PASP 135, Issue 1054, id.124502 - for
    %                default L0-L8 values
    %             2. Garrappa et al. 2025, A&A 699, A50
    % Example : % Basic usage with default config
    %           Config = transmission.inputConfig('default');
    %           Lam = transmission.utils.makeWavelengthArray(Config);
    %           Leg = transmission.utils.legendreModel_noarr(Lam, Config);
    %           % Custom coefficients
    %           Config.Utils.LegendreModel.Default_coeffs = [0.1, -0.05, 0.02];
    %           Leg = transmission.utils.legendreModel_noarr(Lam, Config);

    arguments
        Lam = transmission.utils.makeWavelengthArray(transmission.inputConfig())
        Config = transmission.inputConfig()
    end
    
    % Extract parameters from Config
    Li = Config.Utils.LegendreModel.Default_coeffs;
    Target_min = Config.Utils.RescaleInputData.Target_min;
    Target_max = Config.Utils.RescaleInputData.Target_max;
    
    % Use wavelength array range for normalization
    Min_wvl = min(Lam);
    Max_wvl = max(Lam);
%tic
%for j=1:1000

    
    % Transform wavelength to target range
    New_lambda = transmission.utils.rescaleInputData(Lam, Min_wvl, Max_wvl, [], [], Config);
    %New_lambda = transmission.utils.rescaleInputData();

    % Calculate Legendre polynomials 
    % Note: MATLAB's legendre function uses different normalization, so we
    % use explicit forms 
    Leg_0 = repmat(1,size(New_lambda)); %#ok<*RPMT1>
    Leg_1 = New_lambda;
    Leg_2 = 0.5 * (3 * New_lambda.^2 - 1);
    Leg_3 = 0.5 * (5 * New_lambda.^3 - 3 * New_lambda);
    Leg_4 = 0.125 * (35 * New_lambda.^4 - 30 * New_lambda.^2 + 3);
    Leg_5 = 0.125 * (63 * New_lambda.^5 - 70 * New_lambda.^3 + 15 * New_lambda);
    Leg_6 = 0.0625 * (231 * New_lambda.^6 - 315 * New_lambda.^4 + 105 * New_lambda.^2 - 5);
    Leg_7 = 0.0625 * (429 * New_lambda.^7 - 693 * New_lambda.^5 + 315 * New_lambda.^3 - 35 * New_lambda);
    Leg_8 = 0.0078125 * (6435 * New_lambda.^8 - 12012 * New_lambda.^6 + 6930 * New_lambda.^4 - 1260 * New_lambda.^2 + 35);
   

    % Calculate Legendre model
   Leg_expansion = Li(1) * Leg_0 + Li(2) * Leg_1 + Li(3) * Leg_2 + Li(4) * Leg_3 + Li(5) * Leg_4 + ...
                  Li(6) * Leg_5 + Li(7) * Leg_6 + Li(8) * Leg_7 + Li(9) * Leg_8;
   
    % Return exponential of the expansion
    Leg_model = exp(Leg_expansion);
         
    if size(Lam, 1) > 1 && size(Leg_model, 1) == 1
          Leg_model = Leg_model';
      end
%end   
% toc   
end