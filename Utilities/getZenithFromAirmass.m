function zenith = getZenithFromAirmass(airmass)
% Approximate zenith angle in degrees as a function of airmass
%
% Input:
%   airmass - atmospheric airmass value
%
% Output:
%   zenith - zenith angle in degrees
%
% Example:
%   airmass = 2.0;
%   zenith = getZenithFromAirmass(airmass);

arguments
    airmass double
end

zenith = acosd(1./airmass);
end