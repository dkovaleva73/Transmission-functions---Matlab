function zenithAngle = airmassToZenithAngle(airmass)
    % Convert airmass to zenith angle using plane-parallel atmosphere model
    %
    % Input:  airmass - Airmass value (must be >= 1.0)
    % Output: zenithAngle - Zenith angle in degrees
    %
    % Formula: zenith_angle = acos(1/airmass)
    % Author: D. Kovaleva (Sep 2025)

    arguments
        airmass (1,1) double {mustBePositive}
    end

    % Validate airmass range
    if airmass < 1.0
        error('Airmass %.2f must be >= 1.0', airmass);
    end

    % Simple plane-parallel atmosphere relationship
    zenithAngle = rad2deg(acos(1/airmass));
end