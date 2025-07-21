function airmass = getAirmassFromZenith(zenith)
% Approximate airmass as a function of zenith angle in degrees
%
% Input:
%   zenith - zenith angle in degrees
%
% Output:
%   airmass - atmospheric airmass value
%
% Example:
%   zenith = 30;  % degrees
%   am = getAirmassFromZenith(zenith);

arguments
    zenith double
end
airmass = 1./cosd(zenith);
end