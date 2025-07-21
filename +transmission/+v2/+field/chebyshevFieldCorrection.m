function field_correction = chebyshevFieldCorrection(Lam, R0, R1, R2, R3, R4, Min_wvl, Max_wvl)
    % Calculate field correction using Chebyshev polynomials
    %
    % Parameters:
    %   Lam (double array): Wavelength array in nm
    %   R0-R4 (double): Chebyshev polynomial coefficients
    %   Min_wvl (double): Minimum wavelength for normalization
    %   Max_wvl (double): Maximum wavelength for normalization
    %
    % Returns:
    %   field_correction (double array): Field correction values exp(Chebyshev_series)
    %
    % Example:
    %   Lam = transmission.utils.makeWavelengthArray(400, 800, 201);
    %   Field_corr = transmission.v2.field.chebyshevFieldCorrection(Lam, 0, 0, 0, 0, 0, min(Lam), max(Lam));
    
    arguments
        Lam (:,1) double
        R0 (1,1) double = 0.0
        R1 (1,1) double = 0.0
        R2 (1,1) double = 0.0
        R3 (1,1) double = 0.0
        R4 (1,1) double = 0.0
        Min_wvl (1,1) double = min(Lam)
        Max_wvl (1,1) double = max(Lam)
    end
    
    % Transform wavelength to [-1, +1] range for Chebyshev polynomials
    % Using same transformation as in Python: (max_1 - min_1) / (max_0 - min_0) * (x - max_0) + max_1
    New_lambda = 2 ./ (Max_wvl - Min_wvl) .* (Lam - Max_wvl) + 1;
    
    % Calculate Chebyshev polynomials T_n(x)
    % T_0(x) = 1
    % T_1(x) = x  
    % T_2(x) = 2x² - 1
    % T_3(x) = 4x³ - 3x
    % T_4(x) = 8x⁴ - 8x² + 1
    
    T0 = ones(size(New_lambda));
    T1 = New_lambda;
    T2 = 2 * New_lambda.^2 - 1;
    T3 = 4 * New_lambda.^3 - 3 * New_lambda;
    T4 = 8 * New_lambda.^4 - 8 * New_lambda.^2 + 1;
    
    % Calculate Chebyshev series: R0*T0 + R1*T1 + R2*T2 + R3*T3 + R4*T4
    Cheb_series = R0 * T0 + R1 * T1 + R2 * T2 + R3 * T3 + R4 * T4;
    
    % Field correction is exponential of Chebyshev series
    field_correction = exp(Cheb_series);
    
    % Ensure positive values
    field_correction = max(field_correction, 1e-10);
end