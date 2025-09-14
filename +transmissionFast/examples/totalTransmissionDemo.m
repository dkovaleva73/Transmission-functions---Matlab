% Demonstration of the total transmission calculation
% This script shows various usage examples of transmissionFast.totalTransmission()
%
% Author: D. Kovaleva (Jul 2025)
% Reference: Garrappa et al. 2025, A&A 699, A50.

%% Setup
close all; clear; clc;
addpath(genpath(fileparts(mfilename('fullpath'))));

fprintf('=== Total Transmission Demonstration ===\n\n');

%% Example 1: Basic usage with default configuration
fprintf('Example 1: Basic usage with default configuration\n');
fprintf('------------------------------------------------\n');

Config = transmissionFast.inputConfig('default');
Total_default = transmissionFast.totalTransmission();

%% Example 2: Default wavelength range
fprintf('\nExample 2: Using default wavelength range\n');
fprintf('------------------------------------------\n');

Lam_default = transmissionFast.utils.makeWavelengthArray(Config);
Total_default_range = transmissionFast.totalTransmission(Lam_default, Config);

%% Example 3: Instrumental transmission only (no atmosphere)
fprintf('\nExample 3: Instrumental transmission only\n');
fprintf('----------------------------------------\n');

Config_no_atm = Config;
Config_no_atm.Atmospheric.Enable = false;
Total_instrumental_only = transmissionFast.totalTransmission(Lam_default, Config_no_atm);

%% Example 4: Different atmospheric conditions
fprintf('\nExample 4: Comparison of atmospheric conditions\n');
fprintf('----------------------------------------------\n');

% Photometric night conditions
Config_photometric = transmissionFast.inputConfig('photometric_night');
Total_photometric = transmissionFast.totalTransmission(Lam_default, Config_photometric);

% High humidity conditions  
Config_humid = transmissionFast.inputConfig('humid_conditions');
Total_humid = transmissionFast.totalTransmission(Lam_default, Config_humid);

% High altitude conditions
Config_altitude = transmissionFast.inputConfig('high_altitude');
Total_altitude = transmissionFast.totalTransmission(Lam_default, Config_altitude);

%% Example 5: Create comprehensive comparison plot
fprintf('\nExample 5: Creating comprehensive comparison plots\n');
fprintf('-------------------------------------------------\n');

figure('Name', 'Total Transmission Comparison', 'Position', [100, 100, 1200, 800]);

% Plot 1: Different atmospheric conditions
subplot(2, 2, 1);
plot(Lam_default, Total_default_range, 'b-', 'LineWidth', 2, 'DisplayName', 'Default');
hold on;
plot(Lam_default, Total_photometric, 'g-', 'LineWidth', 2, 'DisplayName', 'Photometric');
plot(Lam_default, Total_humid, 'r-', 'LineWidth', 2, 'DisplayName', 'Humid');
plot(Lam_default, Total_altitude, 'm-', 'LineWidth', 2, 'DisplayName', 'High Altitude');
xlabel('Wavelength (nm)');
ylabel('Total Transmission');
title('Different Atmospheric Conditions');
legend('Location', 'best');
grid on;
ylim([0, 1]);

% Plot 2: Instrumental vs Total transmission
subplot(2, 2, 2);
plot(Lam_default, Total_instrumental_only, 'k--', 'LineWidth', 2, 'DisplayName', 'Instrumental Only');
hold on;
plot(Lam_default, Total_default_range, 'b-', 'LineWidth', 2, 'DisplayName', 'Total (with atmosphere)');
xlabel('Wavelength (nm)');
ylabel('Transmission');
title('Instrumental vs Total Transmission');
legend('Location', 'best');
grid on;
ylim([0, 1]);

% Plot 3: Logarithmic scale
subplot(2, 2, 3);
semilogy(Lam_default, Total_default_range, 'b-', 'LineWidth', 2, 'DisplayName', 'Default');
hold on;
semilogy(Lam_default, Total_photometric, 'g-', 'LineWidth', 2, 'DisplayName', 'Photometric');
semilogy(Lam_default, Total_humid, 'r-', 'LineWidth', 2, 'DisplayName', 'Humid');
xlabel('Wavelength (nm)');
ylabel('Total Transmission (log scale)');
title('Transmission (Logarithmic Scale)');
legend('Location', 'best');
grid on;
ylim([1e-4, 1]);

% Plot 4: Atmospheric contribution
subplot(2, 2, 4);
atmospheric_contrib = Total_default_range ./ Total_instrumental_only;
plot(Lam_default, atmospheric_contrib, 'r-', 'LineWidth', 2);
xlabel('Wavelength (nm)');
ylabel('Atmospheric Transmission');
title('Atmospheric Contribution');
grid on;
ylim([0, 1]);

sgtitle('Total Transmission System Analysis', 'FontSize', 14, 'FontWeight', 'bold');

% Save the figure
saveas(gcf, 'totalTransmissionDemo_comparison.png');
fprintf('Main comparison plot saved as: totalTransmissionDemo_comparison.png\n');

%% Example 5b: Create OTA-only figure for reference
fprintf('\nExample 5b: Creating OTA transmission figure\n');
fprintf('-------------------------------------------\n');

figure('Name', 'OTA Transmission (Instrumental Only)', 'Position', [200, 200, 800, 600]);
plot(Lam_default, Total_instrumental_only, 'k-', 'LineWidth', 2, 'DisplayName', 'OTA Transmission');
xlabel('Wavelength (nm)');
ylabel('OTA Transmission');
title('OTA Transmission Curve (Default Configuration)');
grid on;
ylim([0, 1]);

% Add peak annotation
[peak_val, peak_idx] = max(Total_instrumental_only);
peak_wavelength = Lam_default(peak_idx);
text(peak_wavelength + 50, peak_val - 0.1, ...
     sprintf('Peak: %.3f at %.1f nm', peak_val, peak_wavelength), ...
     'FontSize', 12, 'BackgroundColor', 'white', 'EdgeColor', 'black');

% Save the OTA figure
saveas(gcf, 'totalTransmissionDemo_OTA.png');
fprintf('OTA transmission plot saved as: totalTransmissionDemo_OTA.png\n');

%% Example 6: Performance analysis
fprintf('\nExample 6: Performance analysis\n');
fprintf('------------------------------\n');

% Time the calculation
tic;
for i = 1:10
    Total_test = transmissionFast.totalTransmission(Lam_default, Config);
end
elapsed_time = toc;

fprintf('Average calculation time: %.3f ms (10 iterations)\n', elapsed_time/10*1000);
fprintf('Wavelength points processed: %d\n', length(Lam_default));
fprintf('Processing rate: %.1f points/ms\n', length(Lam_default)/(elapsed_time/10*1000));

%% Example 7: Export results
fprintf('\nExample 7: Exporting results\n');
fprintf('---------------------------\n');

% Create results table
results_table = table(Lam_default, Total_instrumental_only, Total_default_range, ...
                     Total_photometric, Total_humid, Total_altitude, ...
                     'VariableNames', {'Wavelength_nm', 'Instrumental_Only', ...
                     'Default_Conditions', 'Photometric_Night', ...
                     'Humid_Conditions', 'High_Altitude'});

% Save to CSV
output_file = 'total_transmission_results.csv';
writetable(results_table, output_file);
fprintf('Results saved to: %s\n', output_file);

% Display summary statistics
fprintf('\nSummary Statistics:\n');
fprintf('Condition           Peak    Mean    Min     Effective Range (nm)\n');
fprintf('----------------------------------------------------------------\n');

conditions = {'Instrumental Only', 'Default', 'Photometric', 'Humid', 'High Altitude'};
transmissions = {Total_instrumental_only, Total_default_range, Total_photometric, Total_humid, Total_altitude};

for i = 1:length(conditions)
    trans = transmissions{i};
    peak_val = max(trans);
    mean_val = mean(trans);
    min_val = min(trans);
    
    % Effective range (>1% of peak)
    effective_mask = trans > 0.01 * peak_val;
    if any(effective_mask)
        eff_range = sprintf('%.0f-%.0f', min(Lam_default(effective_mask)), max(Lam_default(effective_mask)));
    else
        eff_range = 'None';
    end
    
    fprintf('%-18s  %.3f   %.3f   %.3f   %s\n', conditions{i}, peak_val, mean_val, min_val, eff_range);
end

%% Example 8: Validate physical constraints
fprintf('\nExample 8: Physical constraint validation\n');
fprintf('----------------------------------------\n');

% Check if all transmissions are within [0, 1]
all_transmissions = [Total_default_range; Total_photometric; Total_humid; Total_altitude; Total_instrumental_only];

if all(all_transmissions >= 0 & all_transmissions <= 1)
    fprintf('✅ All transmission values are within physical bounds [0, 1]\n');
else
    out_of_bounds = sum(all_transmissions < 0 | all_transmissions > 1);
    fprintf('⚠️  %d transmission values are out of bounds\n', out_of_bounds);
    fprintf('   Min value: %.6f\n', min(all_transmissions));
    fprintf('   Max value: %.6f\n', max(all_transmissions));
end

% Check for NaN or Inf values
if any(~isfinite(all_transmissions))
    fprintf('⚠️  Non-finite values detected in transmission calculations\n');
else
    fprintf('✅ All transmission values are finite\n');
end

fprintf('\n=== Demonstration Complete ===\n');
fprintf('Total transmission function successfully demonstrated.\n');
fprintf('Results available in workspace and saved to %s\n', output_file);