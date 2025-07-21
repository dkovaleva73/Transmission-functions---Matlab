function [wvl_array] = make_wvl_array(min_int, max_int, num)
%
%  Generate wavelength array for photometric calculations
%
% Input:
%   min_int - minimum wavelength (default: 300 nm)
%   max_int - maximum wavelength (default: 1100 nm)  
%   num - integer, number of points (default: 401)
% Returns:
%   wvl_arr - array, wavelength array in nm
%
% Notes:
%   num = 401 points mimics Gaia sampling (dLambda = 2nm)
%   num =  81 points gives dLambda = 10nm 

arguments (Input)
    min_int =  300.;
    max_int = 1100.;
    num=401;
end

arguments (Output)
    wvl_array
end

 wvl_array = linspace(min_int, max_int, num);
       
end