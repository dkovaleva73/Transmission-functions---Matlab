function [wvl_array_Gaia, mask_gaia, mask_gaia_uv, mask_gaia_ir] = make_wvl_array_Gaia()
% Generate wavelength array specific to Gaia observations
% Returns:
%   wvl_array_Gaia: Wavelength array for Gaia observations
%   mask_gaia: Boolean mask for wavelengths within Gaia range
%   mask_gaia_ir: Boolean mask for wavelengths greater than or equal to max_int_gaia
%   mask_gaia_uv: Boolean mask for wavelengths less than or equal to min_int_gaia

    wvl_arr = make_wvl_array();
    min_int_gaia = 336;
    max_int_gaia = 1020;
    
    mask_gaia = (wvl_arr >= min_int_gaia) & (wvl_arr <= max_int_gaia);
    mask_gaia_uv = (wvl_arr <= min_int_gaia);
    mask_gaia_ir = (wvl_arr >= max_int_gaia);
    
    wvl_array_Gaia = wvl_arr(mask_gaia);
end