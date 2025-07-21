%% Example: Atmospheric Transmission Calculations
% This script demonstrates how to use the transmission package for
% calculating atmospheric transmission effects.

clear; close all; clc;

%% Add the transmission package to the path (if needed)
% Make sure you're in the matlab_projects directory or add it to path

%% 1. Create wavelength array
fprintf('Creating wavelength array...\n');
wavelength = transmission.utils.make_wavelength_array(300, 1100, 401);
fprintf('Wavelength range: %.0f - %.0f nm (%d points)\n', ...
        min(wavelength), max(wavelength), length(wavelength));

%% 2. Define atmospheric parameters
zenith_angle = 30;  % degrees
atm_params.pressure = 1013.25;           % mbar
atm_params.precipitable_water = 2.0;     % cm
atm_params.ozone_dobson = 300;           % Dobson units
atm_params.aerosol_aod500 = 0.1;         % AOD at 500nm
atm_params.aerosol_alpha = 1.3;          % Angstrom exponent

fprintf('\nAtmospheric parameters:\n');
fprintf('  Zenith angle: %.1f degrees\n', zenith_angle);
fprintf('  Pressure: %.1f mbar\n', atm_params.pressure);
fprintf('  Precipitable water: %.1f cm\n', atm_params.precipitable_water);
fprintf('  Ozone: %.0f DU\n', atm_params.ozone_dobson);
fprintf('  Aerosol AOD500: %.2f\n', atm_params.aerosol_aod500);
fprintf('  Angstrom exponent: %.1f\n', atm_params.aerosol_alpha);

%% 3. Calculate individual transmission components
fprintf('\nCalculating individual transmission components...\n');

% Rayleigh scattering
trans_rayleigh = transmission.atmospheric.rayleigh(zenith_angle, ...
                                                  atm_params.pressure, wavelength);

% Aerosol extinction
trans_aerosol = transmission.atmospheric.aerosol(zenith_angle, ...
                                                 atm_params.aerosol_aod500, ...
                                                 atm_params.aerosol_alpha, wavelength);

% Try ozone absorption (UV region)
try
    trans_ozone = transmission.atmospheric.ozone(zenith_angle, ...
                                                 atm_params.ozone_dobson, wavelength);
    ozone_available = true;
catch ME
    fprintf('Warning: %s\n', ME.message);
    trans_ozone = ones(size(wavelength));
    ozone_available = false;
end

% Try water vapor absorption
try
    trans_water = transmission.atmospheric.water(zenith_angle, ...
                                                atm_params.precipitable_water, ...
                                                atm_params.pressure, wavelength);
    water_available = true;
catch ME
    fprintf('Warning: %s\n', ME.message);
    trans_water = ones(size(wavelength));
    water_available = false;
end

%% 4. Calculate total atmospheric transmission
fprintf('Calculating total atmospheric transmission...\n');
trans_total = transmission.atmospheric_total(zenith_angle, atm_params, wavelength);

%% 5. Display results
fprintf('\nTransmission at key wavelengths:\n');
key_wavelengths = [400, 500, 600, 700, 800, 900, 1000];
for wvl = key_wavelengths
    idx = find(wavelength >= wvl, 1, 'first');
    if ~isempty(idx)
        fprintf('  %4.0f nm: Rayleigh=%.3f, Aerosol=%.3f, Total=%.3f\n', ...
                wvl, trans_rayleigh(idx), trans_aerosol(idx), trans_total(idx));
    end
end

%% 6. Create plots
figure('Position', [100, 100, 1200, 800]);

% Plot individual components
subplot(2,2,1);
plot(wavelength, trans_rayleigh, 'b-', 'LineWidth', 2); hold on;
plot(wavelength, trans_aerosol, 'r-', 'LineWidth', 2);
if ozone_available
    plot(wavelength, trans_ozone, 'g-', 'LineWidth', 2);
end
if water_available
    plot(wavelength, trans_water, 'm-', 'LineWidth', 2);
end
xlabel('Wavelength (nm)');
ylabel('Transmission');
title('Individual Atmospheric Components');
legend('Rayleigh', 'Aerosol', 'Ozone', 'Water vapor', 'Location', 'best');
grid on;
ylim([0, 1.1]);

% Plot total transmission
subplot(2,2,2);
plot(wavelength, trans_total, 'k-', 'LineWidth', 3);
xlabel('Wavelength (nm)');
ylabel('Total Transmission');
title(sprintf('Total Atmospheric Transmission (z=%.0f°)', zenith_angle));
grid on;
ylim([0, 1.1]);

% Plot extinction (negative log of transmission)
subplot(2,2,3);
extinction_total = -log(trans_total);
extinction_rayleigh = -log(trans_rayleigh);
extinction_aerosol = -log(trans_aerosol);
semilogy(wavelength, extinction_rayleigh, 'b-', 'LineWidth', 2); hold on;
semilogy(wavelength, extinction_aerosol, 'r-', 'LineWidth', 2);
semilogy(wavelength, extinction_total, 'k-', 'LineWidth', 3);
xlabel('Wavelength (nm)');
ylabel('Extinction');
title('Atmospheric Extinction');
legend('Rayleigh', 'Aerosol', 'Total', 'Location', 'best');
grid on;

% Compare different zenith angles
subplot(2,2,4);
zenith_angles = [0, 30, 60, 75];
colors = {'b', 'g', 'r', 'm'};
for i = 1:length(zenith_angles)
    z = zenith_angles(i);
    trans_z = transmission.atmospheric_total(z, atm_params, wavelength);
    plot(wavelength, trans_z, colors{i}, 'LineWidth', 2); hold on;
end
xlabel('Wavelength (nm)');
ylabel('Total Transmission');
title('Effect of Zenith Angle');
legend(arrayfun(@(x) sprintf('z=%.0f°', x), zenith_angles, 'UniformOutput', false), ...
       'Location', 'best');
grid on;
ylim([0, 1.1]);

sgtitle('Atmospheric Transmission Analysis', 'FontSize', 16, 'FontWeight', 'bold');

fprintf('\nPlots created successfully!\n');
fprintf('Package functions available:\n');
fprintf('  transmission.atmospheric.rayleigh(z, pressure, wavelength)\n');
fprintf('  transmission.atmospheric.aerosol(z, aod500, alpha, wavelength)\n');
fprintf('  transmission.atmospheric.ozone(z, dobson_units, wavelength)\n');
fprintf('  transmission.atmospheric.water(z, precip_water, pressure, wavelength)\n');
fprintf('  transmission.atmospheric_total(z, params, wavelength)\n');
fprintf('  transmission.utils.make_wavelength_array(min, max, num)\n');
fprintf('  transmission.utils.airmass_from_SMARTS(z, constituent)\n');