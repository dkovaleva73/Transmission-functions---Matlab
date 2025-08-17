% Final test of atmospheric transmission function


% 1. Basic functionality test
fprintf('=== ATMOSPHERIC TRANSMISSION TEST ===\n\n');

Config = transmission.inputConfig('default');
Lam = transmission.utils.makeWavelengthArray(Config);
Trans = transmission.atmosphericTransmission(Lam, Config);

fprintf('Configuration: %s\n', 'default');
fprintf('Wavelength range: %.0f - %.0f nm (%d points)\n', ...
    min(Lam), max(Lam), length(Lam));
fprintf('Transmission range: %.4f - %.4f\n', min(Trans), max(Trans));
fprintf('Mean transmission: %.4f\n\n', mean(Trans));

% 2. Show transmission at key wavelengths
fprintf('Transmission at key wavelengths:\n');
key_wvl = [350, 400, 450, 500, 550, 600, 650, 700, 760, 800, 900, 1000];
fprintf('λ (nm)  | Trans\n');
fprintf('--------|-------\n');
for wvl = key_wvl
    [~, idx] = min(abs(Lam - wvl));
    fprintf('  %4d  | %.4f\n', wvl, Trans(idx));
end

% 3. Test different atmospheric conditions
fprintf('\n=== DIFFERENT ATMOSPHERIC CONDITIONS ===\n');
scenarios = {'default', 'dry_conditions', 'humid_conditions', 'high_altitude', 'dusty_conditions'};

for i = 1:length(scenarios)
    Config_test = transmission.inputConfig(scenarios{i});
    Trans_test = transmission.atmosphericTransmission(Lam, Config_test);
    fprintf('%-20s: Mean T = %.4f, Min T = %.4f\n', ...
        scenarios{i}, mean(Trans_test), min(Trans_test));
end

% 4. Component contribution analysis
fprintf('\n=== COMPONENT CONTRIBUTIONS (at 500 nm) ===\n');
Config_base = transmission.inputConfig('default');
[~, idx500] = min(abs(Lam - 500));

% All components
Trans_all = transmission.atmosphericTransmission(Lam, Config_base);

% Test each component individually
components = {'Rayleigh', 'Ozone', 'Water', 'Aerosol', 'Molecular_absorption'};
for i = 1:length(components)
    Config_single = transmission.inputConfig('default');
    % Disable all components
    Config_single.Atmospheric.Components.Rayleigh.Enable = false;
    Config_single.Atmospheric.Components.Ozone.Enable = false;
    Config_single.Atmospheric.Components.Water.Enable = false;
    Config_single.Atmospheric.Components.Aerosol.Enable = false;
    Config_single.Atmospheric.Components.Molecular_absorption.Enable = false;
    % Enable only this component
    Config_single.Atmospheric.Components.(components{i}).Enable = true;
    
    Trans_single = transmission.atmosphericTransmission(Lam, Config_single);
    absorption = 1 - Trans_single(idx500);
    fprintf('%-20s: T = %.4f (Absorption = %.2f%%)\n', ...
        components{i}, Trans_single(idx500), absorption * 100);
end
fprintf('%-20s: T = %.4f\n', 'All components', Trans_all(idx500));

% 5. Create a plot
figure('Name', 'Atmospheric Transmission', 'Position', [100, 100, 800, 600]);

% Different conditions
subplot(2,1,1);
hold on;
colors = lines(length(scenarios));
for i = 1:length(scenarios)
    Config_plot = transmission.inputConfig(scenarios{i});
    Trans_plot = transmission.atmosphericTransmission(Lam, Config_plot);
    plot(Lam, Trans_plot, 'Color', colors(i,:), 'LineWidth', 1.5, ...
        'DisplayName', strrep(scenarios{i}, '_', ' '));
end
xlabel('Wavelength (nm)');
ylabel('Transmission');
title('Atmospheric Transmission - Different Conditions');
legend('Location', 'best');
grid on;
xlim([300, 1100]);
ylim([0, 1]);

% Component breakdown for default
subplot(2,1,2);
Config_default = transmission.inputConfig('default');
Config_default.Output.Save_components = true;
Trans_default = transmission.atmosphericTransmission(Lam, Config_default);
plot(Lam, Trans_default, 'k-', 'LineWidth', 2);
xlabel('Wavelength (nm)');
ylabel('Transmission');
title('Atmospheric Transmission - Default Configuration');
grid on;
xlim([300, 1100]);
ylim([0, 1]);

fprintf('\n=== TEST COMPLETE ===\n');
