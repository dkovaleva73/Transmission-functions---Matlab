function Leg_model = legendreModel(Lam, L0, L1, L2, L3, L4, L5, L6, L7, L8, Min_wvl, Max_wvl)
    % Calculate Legendre polynomial model for instrumental transmission
    %
    % Parameters:
    %   Lam (double array): Wavelength array in nm
    %   L0-L8 (double): Legendre polynomial coefficients
    %   Min_wvl (double): Minimum wavelength for normalization
    %   Max_wvl (double): Maximum wavelength for normalization
    %
    % Returns:
    %   Leg_model (double array): Exponential of Legendre polynomial expansion
    
    arguments
        Lam (:,1) double
        L0 (1,1) double
        L1 (1,1) double
        L2 (1,1) double
        L3 (1,1) double
        L4 (1,1) double
        L5 (1,1) double
        L6 (1,1) double
        L7 (1,1) double
        L8 (1,1) double
        Min_wvl (1,1) double
        Max_wvl (1,1) double
    end
    
    % Import helper function
    import transmission.instrumental.getNewLambda
    
    % Transform wavelength to [-1, 1] range
    New_lambda = getNewLambda(Lam, Min_wvl, Max_wvl, -1.0, 1.0);
    
    % Calculate Legendre polynomials (using MATLAB's legendre function)
    % Note: MATLAB's legendre function uses different normalization, so we use explicit forms
    Leg_0 = ones(size(New_lambda));
    Leg_1 = New_lambda;
    Leg_2 = 0.5 * (3 * New_lambda.^2 - 1);
    Leg_3 = 0.5 * (5 * New_lambda.^3 - 3 * New_lambda);
    Leg_4 = 0.125 * (35 * New_lambda.^4 - 30 * New_lambda.^2 + 3);
    Leg_5 = 0.125 * (63 * New_lambda.^5 - 70 * New_lambda.^3 + 15 * New_lambda);
    Leg_6 = 0.0625 * (231 * New_lambda.^6 - 315 * New_lambda.^4 + 105 * New_lambda.^2 - 5);
    Leg_7 = 0.0625 * (429 * New_lambda.^7 - 693 * New_lambda.^5 + 315 * New_lambda.^3 - 35 * New_lambda);
    Leg_8 = 0.0078125 * (6435 * New_lambda.^8 - 12012 * New_lambda.^6 + 6930 * New_lambda.^4 - 1260 * New_lambda.^2 + 35);
    
    % Calculate Legendre model
    Leg_expansion = L0 * Leg_0 + L1 * Leg_1 + L2 * Leg_2 + L3 * Leg_3 + L4 * Leg_4 + ...
                   L5 * Leg_5 + L6 * Leg_6 + L7 * Leg_7 + L8 * Leg_8;
    
    % Return exponential of the expansion
    Leg_model = exp(Leg_expansion);
end