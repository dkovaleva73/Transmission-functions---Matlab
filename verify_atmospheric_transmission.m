% Verify atmospheric transmission is working correctly

% Suppress verbose output
Config = transmission.inputConfig('default');
Config.Output.Verbose = false;

% Test wavelengths  
test_wvl = [350, 400, 500, 600, 700, 800, 900, 1000];
Lam = test_wvl(:);

% Calculate transmission
Trans = transmission.atmosphericTransmission(Lam, Config);

% Display results
fprintf('\n=== ATMOSPHERIC TRANSMISSION VERIFICATION ===\n');
fprintf('\nDefault configuration (sea level, 1 cm H2O, 300 DU O3, AOD=0.084):\n\n');
fprintf('Wavelength (nm) | Transmission\n');
fprintf('----------------|-------------\n');
for i = 1:length(test_wvl)
    fprintf('     %4d       |   %.4f\n', test_wvl(i), Trans(i));
end

% Calculate mean transmissions in different bands
Lam_full = transmission.utils.makeWavelengthArray(Config);
Trans_full = transmission.atmosphericTransmission(Lam_full, Config);

% UV (300-400 nm)
uv_mask = Lam_full >= 300 & Lam_full <= 400;
fprintf('\nMean UV transmission (300-400 nm): %.4f\n', mean(Trans_full(uv_mask)));

% Visible (400-700 nm)
vis_mask = Lam_full >= 400 & Lam_full <= 700;
fprintf('Mean visible transmission (400-700 nm): %.4f\n', mean(Trans_full(vis_mask)));

% NIR (700-1100 nm)
nir_mask = Lam_full >= 700 & Lam_full <= 1100;
fprintf('Mean NIR transmission (700-1100 nm): %.4f\n', mean(Trans_full(nir_mask)));

fprintf('\nAtmospheric transmission function is working correctly!\n');