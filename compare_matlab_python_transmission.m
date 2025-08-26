% Compare MATLAB and Python atmospheric transmission implementations

% Create identical test conditions
Config = transmission.inputConfig('default');

% Verify we're using the same parameters as Python
fprintf('=== MATLAB ATMOSPHERIC TRANSMISSION ===\n\n');
fprintf('Test conditions:\n');
fprintf('  Zenith angle: %.1f deg\n', Config.Atmospheric.Zenith_angle_deg);
fprintf('  Pressure: %.1f mbar\n', Config.Atmospheric.Pressure_mbar);
fprintf('  Temperature: %.1f C\n', Config.Atmospheric.Temperature_C);
fprintf('  Ozone: %.0f DU\n', Config.Atmospheric.Components.Ozone.Dobson_units);
fprintf('  Water vapor: %.1f cm\n', Config.Atmospheric.Components.Water.Pwv_cm);
fprintf('  Aerosol AOD: %.3f\n', Config.Atmospheric.Components.Aerosol.Tau_aod500);
fprintf('  CO2: %.0f ppm\n', Config.Atmospheric.Components.Molecular_absorption.Co2_ppm);

% Create identical wavelength array - 101 points from 300 to 1100 nm
wavelengths = linspace(300, 1100, 101)';

% Calculate total transmission
fprintf('\nCalculating components...\n');
Trans_total = transmission.atmosphericTransmission(wavelengths, Config);

% Also calculate individual components for detailed comparison
% Rayleigh only
Config_ray = Config;
Config_ray.Atmospheric.Components.Ozone.Enable = false;
Config_ray.Atmospheric.Components.Water.Enable = false;
Config_ray.Atmospheric.Components.Aerosol.Enable = false;
Config_ray.Atmospheric.Components.Molecular_absorption.Enable = false;
Trans_ray = transmission.atmosphericTransmission(wavelengths, Config_ray);

% Ozone only
Config_oz = Config;
Config_oz.Atmospheric.Components.Rayleigh.Enable = false;
Config_oz.Atmospheric.Components.Water.Enable = false;
Config_oz.Atmospheric.Components.Aerosol.Enable = false;
Config_oz.Atmospheric.Components.Molecular_absorption.Enable = false;
Trans_oz = transmission.atmosphericTransmission(wavelengths, Config_oz);

% Water only
Config_water = Config;
Config_water.Atmospheric.Components.Rayleigh.Enable = false;
Config_water.Atmospheric.Components.Ozone.Enable = false;
Config_water.Atmospheric.Components.Aerosol.Enable = false;
Config_water.Atmospheric.Components.Molecular_absorption.Enable = false;
Trans_water = transmission.atmosphericTransmission(wavelengths, Config_water);

% Aerosol only
Config_aer = Config;
Config_aer.Atmospheric.Components.Rayleigh.Enable = false;
Config_aer.Atmospheric.Components.Ozone.Enable = false;
Config_aer.Atmospheric.Components.Water.Enable = false;
Config_aer.Atmospheric.Components.Molecular_absorption.Enable = false;
Trans_aer = transmission.atmosphericTransmission(wavelengths, Config_aer);

% UMG only
Config_umg = Config;
Config_umg.Atmospheric.Components.Rayleigh.Enable = false;
Config_umg.Atmospheric.Components.Ozone.Enable = false;
Config_umg.Atmospheric.Components.Water.Enable = false;
Config_umg.Atmospheric.Components.Aerosol.Enable = false;
Trans_umg = transmission.atmosphericTransmission(wavelengths, Config_umg);

% Output results in same format as Python
fprintf('\n# Wavelength(nm), Trans_Total, Trans_Ray, Trans_Oz, Trans_Water, Trans_Aer, Trans_UMG\n');
for i = 1:length(wavelengths)
    fprintf('%.1f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f\n', ...
        wavelengths(i), Trans_total(i), Trans_ray(i), Trans_oz(i), ...
        Trans_water(i), Trans_aer(i), Trans_umg(i));
end

% Summary statistics
fprintf('\n=== SUMMARY ===\n');
fprintf('Mean total transmission: %.4f\n', mean(Trans_total));
fprintf('Min total transmission: %.4f\n', min(Trans_total));
fprintf('Max total transmission: %.4f\n', max(Trans_total));

% Band averages
uv_mask = wavelengths >= 300 & wavelengths <= 400;
vis_mask = wavelengths >= 400 & wavelengths <= 700;
nir_mask = wavelengths >= 700 & wavelengths <= 1100;

fprintf('\nMean UV transmission (300-400 nm): %.4f\n', mean(Trans_total(uv_mask)));
fprintf('Mean visible transmission (400-700 nm): %.4f\n', mean(Trans_total(vis_mask)));
fprintf('Mean NIR transmission (700-1100 nm): %.4f\n', mean(Trans_total(nir_mask)));

% Save results for comparison
save('matlab_transmission_results.mat', 'wavelengths', 'Trans_total', ...
     'Trans_ray', 'Trans_oz', 'Trans_water', 'Trans_aer', 'Trans_umg');