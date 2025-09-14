function Leg_model = legendreModel(Lam, Config)
    % Calculate Legendre polynomial model for instrumental transmission
    % Input  : - Lam (double array): Wavelength array in nm
    %          - Config (struct): Configuration struct from inputConfig()
    %            Uses Config.Utils.LegendreModel.Default_coeffs
    % Output : - Leg_model (double array): Exponential of Legendre polynomial expansion
    % Author : D. Kovaleva (Jul 2025)
    % References: 1. Ofek et al. 2023, PASP 135, Issue 1054, id.124502 - for
    %                default Li values;
    %             2. Garrappa et al. 2025, A&A 699, A50.
    % Example : % Basic usage with default config
    %           Config = transmissionFast.inputConfig('default');
    %           Lam = transmissionFast.utils.makeWavelengthArray(Config);
    %           Leg = transmissionFast.utils.legendreModel(Lam, Config);
    %           % Custom coefficients
    %           Config.Utils.LegendreModel.Default_coeffs = [0.1, -0.05, 0.02];
    %           Leg = transmissionFast.utils.legendreModel(Lam, Config);

    arguments
        Lam = transmissionFast.utils.makeWavelengthArray(transmissionFast.inputConfig())
        Config = transmissionFast.inputConfig()
    end
    % Extract parameters from Config
    Li = Config.Utils.LegendreModel.Default_coeffs;
    Target_min = Config.Utils.RescaleInputData.Target_min;
    Target_max = Config.Utils.RescaleInputData.Target_max;
    
    % Use wavelength array range for normalization
    Min_wvl = min(Lam);
    Max_wvl = max(Lam);
    
    % Transform wavelength to target range
    New_lambda = transmissionFast.utils.rescaleInputData(Lam, Min_wvl, Max_wvl, [], [], Config);
    %New_lambda = transmissionFast.utils.rescaleInputData();

    % Calculate Legendre polynomials (using MATLAB's legendre function)
    % Note: MATLAB's legendre function uses different normalization
   
      for n=0:length(Li)-1 
        Legn=legendre(n,New_lambda);
        Leg0{n+1} = Legn(1, :);
      end
      Leg = vertcat(Leg0{:}); 

      % Calculate Legendre model
      Leg_expansion=Li*Leg;

      % Return exponential of the expansion
        Leg_model = exp(Leg_expansion);
      % Ensure output is a column vector matching input shape
      if size(Lam, 1) > 1 && size(Leg_model, 1) == 1
          Leg_model = Leg_model';
      end
%end      
%toc      
end