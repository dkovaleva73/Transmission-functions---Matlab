function Trans_atmtotal = atmosphericTransmission(Lam, Config)
    % Calculate total atmospheric transmission combining all components
    % Input  : - Lam (double array): Wavelength array in nm
    %          - Config (struct): Configuration struct from inputConfig()
    %            Uses Config.Atmospheric settings for all components
    % Output : - Trans_amtotal (double array): Total atmospheric transmission (0-1)
    % Author : D. Kovaleva (Jul 2025)
    % Example: Config = transmission.inputConfig('default');
    %          Lam = transmission.utils.makeWavelengthArray(Config);
    %          Trans = transmission.atmosphericTransmission(Lam, Config);
    %          % Disable aerosols:
    %          Config.Atmospheric.Components.Aerosol.Enable = false;
    %          Trans = transmission.atmosphericTransmission(Lam, Config);
    
    arguments
        Lam = transmission.utils.makeWavelengthArray(transmission.inputConfig())
        Config = transmission.inputConfig()
    end
    
    % Check if atmospheric transmission is enabled
    if ~Config.Atmospheric.Enable
        % Return unity transmission if atmospheric effects disabled
        Trans_atmtotal = ones(size(Lam));
        return;
    end
    
    % Initialize total transmission as unity
    Trans_atmtotal = ones(size(Lam));
    
    % Verbose output control
    verbose = Config.Output.Verbose;
    
    % Store individual components if requested
    if Config.Output.Save_components
        Components = struct();
    end
    
    % =========================================================================
    % RAYLEIGH SCATTERING
    % =========================================================================
    if Config.Atmospheric.Components.Rayleigh.Enable
        if verbose
            fprintf('Calculating Rayleigh scattering...\n');
        end
        Trans_rayleigh = transmission.atmospheric.rayleighTransmission(Lam, Config);
        Trans_atmtotal = Trans_atmtotal .* Trans_rayleigh;
        
        if Config.Output.Save_components
            Components.Rayleigh = Trans_rayleigh;
        end
    end
    
    % =========================================================================
    % OZONE ABSORPTION
    % =========================================================================
    if Config.Atmospheric.Components.Ozone.Enable
        if verbose
            fprintf('Calculating ozone absorption...\n');
        end
        Trans_ozone = transmission.atmospheric.ozoneTransmission(Lam, Config);
        Trans_atmtotal = Trans_atmtotal .* Trans_ozone;
        
        if Config.Output.Save_components
            Components.Ozone = Trans_ozone;
        end
    end
    
    % =========================================================================
    % WATER VAPOR ABSORPTION
    % =========================================================================
    if Config.Atmospheric.Components.Water.Enable
        if verbose
            fprintf('Calculating water vapor absorption...\n');
        end
        Trans_water = transmission.atmospheric.waterTransmittance(Lam, Config);
        Trans_atmtotal = Trans_atmtotal .* Trans_water;
        
        if Config.Output.Save_components
            Components.Water = Trans_water;
        end
    end
    
    % =========================================================================
    % AEROSOL SCATTERING
    % =========================================================================
    if Config.Atmospheric.Components.Aerosol.Enable
        if verbose
            fprintf('Calculating aerosol scattering...\n');
        end
        Trans_aerosol = transmission.atmospheric.aerosolTransmission(Lam, Config);
        Trans_atmtotal = Trans_atmtotal .* Trans_aerosol;
        
        if Config.Output.Save_components
            Components.Aerosol = Trans_aerosol;
        end
    end
    
    % =========================================================================
    % MOLECULAR ABSORPTION (UMG)
    % =========================================================================
    if Config.Atmospheric.Components.Molecular_absorption.Enable
        if verbose
            fprintf('Calculating molecular absorption (UMG)...\n');
        end
        Trans_umg = transmission.atmospheric.umgTransmittance(Lam, Config);
        Trans_atmtotal = Trans_atmtotal .* Trans_umg;
        
        if Config.Output.Save_components
            Components.Molecular = Trans_umg;
        end
    end
    
    % =========================================================================
    % VALIDATION AND OUTPUT
    % =========================================================================
    
    % Check for transmission bounds if requested
    if Config.Total.Check_bounds
        out_of_bounds = Trans_atmtotal < 0 | Trans_atmtotal > 1;
        if any(out_of_bounds)
            num_oob = sum(out_of_bounds);
            if Config.Total.Warn_out_of_bounds
                warning('transmission:atmosphericTransmission:outOfBounds', ...
                    '%d wavelength points have transmission outside [0,1] range', num_oob);
            end
        end
    end
    
    % Plot results if requested
    if Config.Output.Plot_results
        figure('Name', 'Atmospheric Transmission Components');
        
        % Main plot - total transmission
        subplot(2,1,1);
        plot(Lam, Trans_atmtotal, 'k-', 'LineWidth', 2);
        xlabel('Wavelength (nm)');
        ylabel('Transmission');
        title('Total Atmospheric Transmission');
        grid on;
        ylim([0, 1.05]);
        
        % Component plot
        if Config.Output.Save_components
            subplot(2,1,2);
            hold on;
            
            if isfield(Components, 'Rayleigh')
                plot(Lam, Components.Rayleigh, '-', 'DisplayName', 'Rayleigh');
            end
            if isfield(Components, 'Ozone')
                plot(Lam, Components.Ozone, '-', 'DisplayName', 'Ozone');
            end
            if isfield(Components, 'Water')
                plot(Lam, Components.Water, '-', 'DisplayName', 'Water');
            end
            if isfield(Components, 'Aerosol')
                plot(Lam, Components.Aerosol, '-', 'DisplayName', 'Aerosol');
            end
            if isfield(Components, 'Molecular')
                plot(Lam, Components.Molecular, '-', 'DisplayName', 'Molecular (UMG)');
            end
            
            plot(Lam, Trans_atmtotal, 'k--', 'LineWidth', 2, 'DisplayName', 'Total');
            
            xlabel('Wavelength (nm)');
            ylabel('Transmission');
            title('Atmospheric Transmission Components');
            legend('Location', 'best');
            grid on;
            ylim([0, 1.05]);
            hold off;
        end
    end
    
    % Return components if requested
    if Config.Output.Save_components && nargout > 1
        % This would require modifying the function signature
        % For now, components are only used for plotting
    end
    
    % Ensure output shape matches input
    if size(Lam, 1) > 1 && size(Trans_atmtotal, 1) == 1
        Trans_atmtotal = Trans_atmtotal';
    end
end