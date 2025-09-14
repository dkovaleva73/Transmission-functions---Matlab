function Total_transmission = totalTransmission(Lam, Config, Args)
    % Calculate total transmission by multiplying instrumental and atmospheric components
    % Input :  - Lam (double array): Wavelength array in nm
    %          - Config (struct): Configuration struct from inputConfig()
    %            Uses Config.Instrumental for instrumental components
    %            Uses Config.Atmospheric for atmospheric components
    %          * ...,key,val,...
    %            'AbsorptionData' - Pre-loaded absorption data to avoid file I/O
    % Output : - Total_transmission (double array): Complete system transmission (0-1)
    % Author : D. Kovaleva (Jul 2025)
    % Reference: Garrappa et al. 2025, A&A 699, A50.
    % Example: Config = transmissionFast.inputConfig('default');
    %          Lam = transmissionFast.utils.makeWavelengthArray(Config);
    %          Total = transmissionFast.totalTransmission(Lam, Config);
    %          % With pre-loaded absorption data:
    %          AbsData = transmissionFast.data.loadAbsorptionData([], {}, false);
    %          Total = transmissionFast.totalTransmission(Lam, Config, 'AbsorptionData', AbsData);

    arguments
        Lam = []  % Will use cached wavelength array from Config if empty
        Config = transmissionFast.inputConfig()
        Args.AbsorptionData = []  % Optional pre-loaded absorption data
    end
    
    % Use cached wavelength array if Lam not provided
    if isempty(Lam)
        if isfield(Config, 'WavelengthArray') && ~isempty(Config.WavelengthArray)
            Lam = Config.WavelengthArray;
        else
            % Fallback to calculation if cached array not available
            Lam = transmissionFast.utils.makeWavelengthArray(Config);
        end
    end
    
    % 1. Calculate instrumental transmission (OTA)
    Instrumental_transmission = transmissionFast.instrumental.otaTransmission(Lam, Config);
    
    % 2. Calculate atmospheric transmission (if enabled)
    if Config.Atmospheric.Enable
        % Pass cached absorption data if available
        if ~isempty(Args.AbsorptionData)
            Atmospheric_transmission = transmissionFast.atmospheric.atmosphericTransmission(Lam, Config, 'AbsorptionData', Args.AbsorptionData);
        else
            Atmospheric_transmission = transmissionFast.atmospheric.atmosphericTransmission(Lam, Config);
        end
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
end