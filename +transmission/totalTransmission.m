function Total_transmission = totalTransmission(Lam, Config)
    % Calculate total transmission by multiplying instrumental and atmospheric components
    % Input :  - Lam (double array): Wavelength array in nm
    %          - Config (struct): Configuration struct from inputConfig()
    %            Uses Config.Instrumental for instrumental components
    %            Uses Config.Atmospheric for atmospheric components
    % Output : - Total_transmission (double array): Complete system transmission (0-1)
    % Author : D. Kovaleva (Jul 2025)
    % Reference: Garrappa et al. 2025, A&A 699, A50.
    % Example: Config = transmission.inputConfig('default');
    %          Lam = transmission.utils.makeWavelengthArray(Config);
    %          Total = transmission.totalTransmission(Lam, Config);
    %          % Disable atmospheric effects
    %          Config.Atmospheric.Enable = false;
    %          Total_instrumental_only = transmission.totalTransmission(Lam, Config);
    %          % Custom wavelength range
    %          Lam_custom = linspace(400, 900, 201)';
    %          Total_custom = transmission.totalTransmission(Lam_custom, Config);

    arguments
        Lam = transmission.utils.makeWavelengthArray(transmission.inputConfig())
        Config = transmission.inputConfig()
    end
    
    % 1. Calculate instrumental transmission (OTA)
    Instrumental_transmission = transmission.instrumental.otaTransmission(Lam, Config);
    
    % 2. Calculate atmospheric transmission (if enabled)
    if Config.Atmospheric.Enable
        Atmospheric_transmission = transmission.atmospheric.atmosphericTransmission(Lam, Config);
    else
        % No atmospheric effects - perfect transmission
        Atmospheric_transmission = ones(size(Lam));
        fprintf('Atmospheric transmission disabled - using unity transmission\n');
    end
    
    % 3. Calculate total transmission as product of all components
    Total_transmission = Instrumental_transmission .* Atmospheric_transmission;
    
    % 4. Display summary information
    if nargout == 0 || Config.Utils.Display.Show_summary
        fprintf('\n=== Total Transmission Summary ===\n');
        fprintf('Wavelength range: %.1f - %.1f nm (%d points)\n', ...
                min(Lam), max(Lam), length(Lam));
        fprintf('Instrumental transmission: %.6f - %.6f (mean: %.6f)\n', ...
                min(Instrumental_transmission), max(Instrumental_transmission), ...
                mean(Instrumental_transmission));
        
        if Config.Atmospheric.Enable
            fprintf('Atmospheric transmission:  %.6f - %.6f (mean: %.6f)\n', ...
                    min(Atmospheric_transmission), max(Atmospheric_transmission), ...
                    mean(Atmospheric_transmission));
        else
            fprintf('Atmospheric transmission:  disabled (unity)\n');
        end
        
        fprintf('Total transmission:        %.6f - %.6f (mean: %.6f)\n', ...
                min(Total_transmission), max(Total_transmission), ...
                mean(Total_transmission));
        
        % Peak wavelength information
        [max_total, max_idx] = max(Total_transmission);
        fprintf('Peak transmission: %.6f at %.1f nm\n', max_total, Lam(max_idx));
        
        % Effective transmission range (where transmission > 1% of peak)
        effective_mask = Total_transmission > 0.01 * max_total;
        if any(effective_mask)
            effective_range = [min(Lam(effective_mask)), max(Lam(effective_mask))];
            fprintf('Effective range (>1%% peak): %.1f - %.1f nm\n', ...
                    effective_range(1), effective_range(2));
        end
        fprintf('===================================\n\n');
    end
    
    % 5. Optional plotting (if no output requested and plotting enabled)
    if nargout == 0 && Config.Utils.Display.Show_plots
        figure('Name', 'Total Transmission', 'NumberTitle', 'off');
        
        subplot(2, 1, 1);
        plot(Lam, Instrumental_transmission, 'b-', 'LineWidth', 2, 'DisplayName', 'Instrumental');
        hold on;
        if Config.Atmospheric.Enable
            plot(Lam, Atmospheric_transmission, 'r--', 'LineWidth', 2, 'DisplayName', 'Atmospheric');
        end
        plot(Lam, Total_transmission, 'k-', 'LineWidth', 3, 'DisplayName', 'Total');
        xlabel('Wavelength (nm)');
        ylabel('Transmission');
        title('System Transmission Components');
        legend('Location', 'best');
        grid on;
        ylim([0, 1]);
        
        subplot(2, 1, 2);
        semilogy(Lam, Total_transmission, 'k-', 'LineWidth', 2);
        xlabel('Wavelength (nm)');
        ylabel('Transmission (log scale)');
        title('Total Transmission (Logarithmic Scale)');
        grid on;
        ylim([1e-6, 1]);
        
        % Add text annotation with key statistics
        max_trans = max(Total_transmission);
        mean_trans = mean(Total_transmission);
        annotation('textbox', [0.15, 0.02, 0.7, 0.08], ...
                  'String', sprintf('Peak: %.3f | Mean: %.3f | Range: %.1f-%.1f nm', ...
                                  max_trans, mean_trans, min(Lam), max(Lam)), ...
                  'FitBoxToText', 'on', 'BackgroundColor', 'white', ...
                  'EdgeColor', 'black');
    end
end