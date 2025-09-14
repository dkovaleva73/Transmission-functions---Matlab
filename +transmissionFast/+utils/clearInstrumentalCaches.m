function clearInstrumentalCaches()
    % Clear persistent caches from instrumental functions
    % This forces recalculation on next function call
    %
    % Usage: transmissionFast.utils.clearInstrumentalCaches()
    %
    % Clears persistent variables from:
    %  - mirrorReflectance
    %  - correctorTransmission
    %
    % Author: D. Kovaleva (Sep 2025)
    
    % Clear persistent variables by clearing the functions
    clear transmissionFast.instrumental.mirrorReflectance
    clear transmissionFast.instrumental.correctorTransmission
    
    fprintf('Instrumental function caches cleared successfully\n');
end