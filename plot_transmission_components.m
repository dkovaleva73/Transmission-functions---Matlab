 function plot_transmission_components()
         % Plot individual atmospheric transmission components vs wavelength

         fprintf('Plotting atmospheric transmission components...\n');

         % Add path to transmission package
         addpath('/home/dana/matlab_projects');

         % Setup parameters
         Z_ = 30;  % Zenith angle in degrees
         Lam = transmission.utils.makeWavelengthArray(300, 1100, 401);  % Full spectrum

         % Atmospheric parameters
         Pressure = 1013.25;  % mbar
         Aod500 = 0.1;        % Aerosol optical depth at 500nm
         Alpha = 1.3;         % Angstrom exponent
         Tair = 15;           % Air temperature in °C
         Co2_ppm = 415;       % CO2 concentration

         fprintf('Calculating transmission components...\n');

         %% Calculate individual components
         try
             % Rayleigh scattering
             Trans_ray = transmission.atmospheric.rayleighTransmission(Z_, Pressure, Lam);
             fprintf('✓ Rayleigh transmission calculated\n');

             % Aerosol extinction  
             Trans_aer = transmission.atmospheric.aerosolTransmittance(Z_, Aod500, Alpha, Lam);
             fprintf('✓ Aerosol transmission calculated\n');

             % UMG transmission
             Trans_umg = transmission.atmospheric.umgTransmittance(Z_, Tair, Pressure, Lam, Co2_ppm, true);
             fprintf('✓ UMG transmission calculated\n');

         catch ME
             fprintf('Error calculating components: %s\n', ME.message);
             return;
         end

         %% Create the plot
         figure('Name', 'Atmospheric Transmission Components', 'Position', [100, 100, 1000, 600]);

         % Plot all components
         hold on;
         plot(Lam, Trans_ray, 'b-', 'LineWidth', 2, 'DisplayName', 'Rayleigh Scattering');
         plot(Lam, Trans_aer, 'r-', 'LineWidth', 2, 'DisplayName', 'Aerosol Extinction');
         plot(Lam, Trans_umg, 'g-', 'LineWidth', 2, 'DisplayName', 'Uniformly Mixed Gases');

         % Formatting
         xlabel('Wavelength (nm)', 'FontSize', 12);
         ylabel('Transmission', 'FontSize', 12);
         title(sprintf('Atmospheric Transmission Components (Zenith Angle = %.0f°)', Z_), 'FontSize', 14);
         grid on;
         legend('Location', 'best', 'FontSize', 11);

         % Set axis limits for better visualization
         xlim([min(Lam), max(Lam)]);
         ylim([0.8, 1.0]);  % Focus on the transmission range

         % Add text annotations with key values
         text(400, 0.85, sprintf('At 500nm:'), 'FontSize', 10, 'FontWeight', 'bold');
         text(400, 0.83, sprintf('Rayleigh: %.4f', interp1(Lam, Trans_ray, 500)), 'FontSize', 9, 'Color', 'blue');
         text(400, 0.81, sprintf('Aerosol: %.4f', interp1(Lam, Trans_aer, 500)), 'FontSize', 9, 'Color', 'red');
         text(400, 0.79, sprintf('UMG: %.4f', interp1(Lam, Trans_umg, 500)), 'FontSize', 9, 'Color','green');

         %% Create a second subplot for combined view
         figure('Name', 'Combined Atmospheric Transmission', 'Position', [150, 150, 1000, 600]);

         % Calculate combined transmission
         Trans_combined = Trans_ray .* Trans_aer .* Trans_umg;

         % Plot individual and combined
         subplot(2,1,1);
         hold on;
         plot(Lam, Trans_ray, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Rayleigh');
         plot(Lam, Trans_aer, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Aerosol');
         plot(Lam, Trans_umg, 'g-', 'LineWidth', 1.5, 'DisplayName', 'UMG');
         xlabel('Wavelength (nm)');
         ylabel('Transmission');
         title('Individual Components');
         grid on;
         legend('Location', 'best');
         ylim([0.8, 1.0]);

         subplot(2,1,2);
         plot(Lam, Trans_combined, 'k-', 'LineWidth', 2, 'DisplayName', 'Combined');
         hold on;
         plot(Lam, Trans_ray .* Trans_aer, 'c--', 'LineWidth', 1, 'DisplayName', 'Rayleigh × Aerosol');
         xlabel('Wavelength (nm)');
         ylabel('Transmission');
         title('Combined Transmission');
         grid on;
         legend('Location', 'best');
         ylim([0.7, 1.0]);

         %% Print summary statistics
         fprintf('\n=== Transmission Summary at Key Wavelengths ===\n');
         Key_wavelengths = [350, 400, 500, 600, 700, 800, 900, 1000];

         fprintf('Wavelength |  Rayleigh  |  Aerosol   |    UMG     | Combined\n');
         fprintf('    (nm)   |            |            |            |         \n');
         fprintf('-----------|------------|------------|------------|---------\n');

         for i = 1:length(Key_wavelengths)
             wvl = Key_wavelengths(i);
             if wvl >= min(Lam) && wvl <= max(Lam)
                 ray_val = interp1(Lam, Trans_ray, wvl);
                 aer_val = interp1(Lam, Trans_aer, wvl);
                 umg_val = interp1(Lam, Trans_umg, wvl);
                 comb_val = ray_val * aer_val * umg_val;

                 fprintf('   %4.0f    |   %.4f   |   %.4f   |   %.4f   |  %.4f\n', ...
                         wvl, ray_val, aer_val, umg_val, comb_val);
             end
         end

         fprintf('\nParameters used:\n');
         fprintf('  Zenith angle: %.0f°\n', Z_);
         fprintf('  Pressure: %.1f mbar\n', Pressure);
         fprintf('  AOD500: %.2f\n', Aod500);
         fprintf('  Angstrom exp: %.1f\n', Alpha);
         fprintf('  Air temp: %.0f°C\n', Tair);
         fprintf('  CO2: %.0f ppm\n', Co2_ppm);

         fprintf('\nPlots created successfully!\n');
     end

