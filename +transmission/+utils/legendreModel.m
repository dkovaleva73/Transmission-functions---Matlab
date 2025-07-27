function Leg_model = legendreModel(Lam, Degr, Li, Min_wvl, Max_wvl)
    % Calculate Legendre polynomial model for instrumental transmission
    % Array operations (4* times longer than direct approach)
    % Input  : - Lam (double array): Wavelength array in nm
    %          - Degr (integer): degree of Legendre polynom
    %          - Li (double): vector of Legendre polynomial coefficients
    %          - Min_wvl (double): Minimum wavelength for normalization
    %          - Max_wvl (double): Maximum wavelength for normalization
    % Output : - Leg_model (double array): Exponential of Legendre polynomial expansion
    % Author : D. Kovaleva (Jul 2025)
    % References: 1. Ofek et al. 2023, PASP 135, Issue 1054, id.124502 - for
    %                default Li values;
    %             2. Garrappa et al. 2025, A&A 699, A50.
    % Example : % Basic usage with default Ofek+23 coefficients
    %           Leg = transmission.utils.legendreModel();
    %           % Custom wavelength array with 4th degree polynomial
    %           Lam = linspace(350, 950, 301)';
    %           Leg = transmission.utils.legendreModel(Lam, 4, [-0.30 0.34 -1.89 -0.82 -3.73]);
    %           % Full 8th order with custom normalization range
    %           Leg = transmission.utils.legendreModel(Lam, 8, Li, 400, 800);
    %           % Simple 2nd order correction
    %           Leg = transmission.utils.legendreModel(Lam, 2, [0.1 -0.05 0.02]);


    arguments
        Lam  = transmission.utils.makeWavelengthArray()
        Degr = 8
        Li = [-0.30 0.34 -1.89 -0.82 -3.73 -0.669 -2.06 -0.24 -0.60]
        Min_wvl = min(Lam)
        Max_wvl = max(Lam)
    end
%tic
%for j=1:1000
    % Validate wavelength bounds
    if Min_wvl >= Max_wvl
        error('transmission:legendreModel:invalidBounds', ...
              'Min_wvl must be less than Max_wvl');
    end
    if Min_wvl < min(Lam) || Max_wvl > max(Lam)
        error('transmission:legendreModel:boundsOutOfRange', ...
              'Normalization bounds [%.1f, %.1f] exceed wavelength array range [%.1f, %.1f]', ...
              Min_wvl, Max_wvl, min(Lam), max(Lam));
    end
    
    % Transform wavelength to [-1, 1] range
    New_lambda = transmission.utils.normLambda(Lam, Min_wvl, Max_wvl, -1.0, 1.0);
    %New_lambda = transmission.utils.normLambda();

    % Calculate Legendre polynomials (using MATLAB's legendre function)
    % Note: MATLAB's legendre function uses different normalization
   
      for n=0:Degr
        Legn=legendre(n,New_lambda);
        Leg0{n+1} = Legn(1, :);
      end
      Leg = vertcat(Leg0{:}); 

      % Calculate Legendre model
      Leg_expansion=Li*Leg;

      % Return exponential of the expansion
      Leg_model = exp(Leg_expansion);
%end      
%toc      
end