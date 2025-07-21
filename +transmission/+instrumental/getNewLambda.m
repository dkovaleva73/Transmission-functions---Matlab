function New_lambda = getNewLambda(Lam, Min_wvl, Max_wvl, Min_1, Max_1)
    % Transform wavelength array to specified range for Legendre polynomials
    %
    % Parameters:
    %   Lam (double array): Wavelength array in nm
    %   Min_wvl (double): Minimum wavelength of the array
    %   Max_wvl (double): Maximum wavelength of the array
    %   Min_1 (double): Minimum value for new lambda (default: -1)
    %   Max_1 (double): Maximum value for new lambda (default: +1)
    %
    % Returns:
    %   New_lambda (double array): Transformed wavelength array
    
    arguments
        Lam (:,1) double
        Min_wvl (1,1) double
        Max_wvl (1,1) double
        Min_1 (1,1) double = -1.0
        Max_1 (1,1) double = 1.0
    end
    
    % Linear transformation to map [Min_wvl, Max_wvl] to [Min_1, Max_1]
    New_lambda = (Max_1 - Min_1) ./ (Max_wvl - Min_wvl) .* (Lam - Max_wvl) + Max_1;
end