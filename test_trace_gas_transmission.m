% Test complete trace gas transmission at different wavelengths

% Configuration
Config = transmission.inputConfig('default');
Config.Atmospheric.Components.Molecular_absorption.With_trace_gases = true;

% Test wavelengths including the problematic UV range
test_wavelengths = [300, 350, 396, 400, 450, 500, 600];

% Calculate transmission
Lam = test_wavelengths(:);
Trans = transmission.atmospheric.umgTransmittance(Lam, Config);

% Display results
fprintf('\n=== UMG TRANSMISSION WITH TRACE GASES ===\n');
fprintf('Wavelength (nm) | Transmission\n');
fprintf('----------------|-------------\n');
for i = 1:length(test_wavelengths)
    fprintf('    %6.0f      |  %.6f\n', test_wavelengths(i), Trans(i));
end

% Also test without trace gases
Config.Atmospheric.Components.Molecular_absorption.With_trace_gases = false;
Trans_no_trace = transmission.atmospheric.umgTransmittance(Lam, Config);

fprintf('\n=== UMG TRANSMISSION WITHOUT TRACE GASES ===\n');
fprintf('Wavelength (nm) | Transmission\n');
fprintf('----------------|-------------\n');
for i = 1:length(test_wavelengths)
    fprintf('    %6.0f      |  %.6f\n', test_wavelengths(i), Trans_no_trace(i));
end

% Show the difference
fprintf('\n=== TRACE GAS CONTRIBUTION ===\n');
fprintf('Wavelength (nm) | Trans reduction\n');
fprintf('----------------|----------------\n');
for i = 1:length(test_wavelengths)
    reduction = Trans_no_trace(i) - Trans(i);
    fprintf('    %6.0f      |    %.6f\n', test_wavelengths(i), reduction);
end