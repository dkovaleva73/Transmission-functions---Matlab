% Test the complete atmospheric transmission function

% 1. Default configuration test
fprintf('=== TEST 1: Default Configuration ===\n');
Config = transmission.inputConfig('default');
Lam = transmission.utils.makeWavelengthArray(Config);
Trans = transmission.atmosphericTransmission(Lam, Config);

fprintf('Wavelength range: %.1f - %.1f nm\n', min(Lam), max(Lam));
fprintf('Transmission range: %.4f - %.4f\n', min(Trans), max(Trans));
fprintf('Mean transmission: %.4f\n', mean(Trans));

% Check specific wavelengths
test_wvl = [350, 400, 500, 600, 700, 800, 900, 1000];
for wvl = test_wvl
    idx = find(abs(Lam - wvl) < 1);
    if ~isempty(idx)
        fprintf('  T(%d nm) = %.4f\n', wvl, Trans(idx(1)));
    end
end

% 2. Test with different scenarios
fprintf('\n=== TEST 2: Different Scenarios ===\n');

% Dry conditions
Config_dry = transmission.inputConfig('dry_conditions');
Trans_dry = transmission.atmosphericTransmission(Lam, Config_dry);
fprintf('Dry conditions - Mean transmission: %.4f\n', mean(Trans_dry));

% Humid conditions
Config_humid = transmission.inputConfig('humid_conditions');
Trans_humid = transmission.atmosphericTransmission(Lam, Config_humid);
fprintf('Humid conditions - Mean transmission: %.4f\n', mean(Trans_humid));

% High altitude
Config_altitude = transmission.inputConfig('high_altitude');
Trans_altitude = transmission.atmosphericTransmission(Lam, Config_altitude);
fprintf('High altitude - Mean transmission: %.4f\n', mean(Trans_altitude));

% 3. Test component enable/disable
fprintf('\n=== TEST 3: Component Control ===\n');

% Only Rayleigh
Config_ray = transmission.inputConfig('default');
Config_ray.Atmospheric.Components.Ozone.Enable = false;
Config_ray.Atmospheric.Components.Water.Enable = false;
Config_ray.Atmospheric.Components.Aerosol.Enable = false;
Config_ray.Atmospheric.Components.Molecular_absorption.Enable = false;
Trans_ray = transmission.atmosphericTransmission(Lam, Config_ray);
fprintf('Rayleigh only - Mean transmission: %.4f\n', mean(Trans_ray));

% No aerosols
Config_no_aer = transmission.inputConfig('default');
Config_no_aer.Atmospheric.Components.Aerosol.Enable = false;
Trans_no_aer = transmission.atmosphericTransmission(Lam, Config_no_aer);
fprintf('No aerosols - Mean transmission: %.4f\n', mean(Trans_no_aer));

% 4. Test with plotting
fprintf('\n=== TEST 4: Plotting Test ===\n');
Config_plot = transmission.inputConfig('default');
Config_plot.Output.Plot_results = true;
Config_plot.Output.Save_components = true;
Trans_plot = transmission.atmosphericTransmission(Lam, Config_plot);

% 5. Test zenith angle dependence
fprintf('\n=== TEST 5: Zenith Angle Dependence ===\n');
zenith_angles = [0, 30, 45, 60, 70];
for z = zenith_angles
    Config_z = transmission.inputConfig('default');
    Config_z.Atmospheric.Zenith_angle_deg = z;
    Trans_z = transmission.atmosphericTransmission(Lam, Config_z);
    fprintf('Zenith = %d deg, Airmass ≈ %.2f - Mean transmission: %.4f\n', ...
        z, 1/cos(deg2rad(z)), mean(Trans_z));
end

% 6. Test trace gases effect
fprintf('\n=== TEST 6: Trace Gases Effect ===\n');
Config_trace = transmission.inputConfig('default');
Config_trace.Atmospheric.Components.Molecular_absorption.With_trace_gases = true;
Trans_trace = transmission.atmosphericTransmission(Lam, Config_trace);

Config_no_trace = transmission.inputConfig('default');
Config_no_trace.Atmospheric.Components.Molecular_absorption.With_trace_gases = false;
Trans_no_trace = transmission.atmosphericTransmission(Lam, Config_no_trace);

fprintf('With trace gases - Mean transmission: %.4f\n', mean(Trans_trace));
fprintf('Without trace gases - Mean transmission: %.4f\n', mean(Trans_no_trace));
fprintf('Difference: %.4f\n', mean(Trans_no_trace) - mean(Trans_trace));