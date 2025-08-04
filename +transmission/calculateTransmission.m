function [Total, Components] = calculateTransmission(varargin)
    % Convenience function to calculate total transmission with flexible input options
    % This is a user-friendly wrapper around transmission.totalTransmission()
    %
    % Usage:
    %   Total = calculateTransmission()                           % Use all defaults
    %   Total = calculateTransmission(wavelengths)                % Custom wavelengths
    %   Total = calculateTransmission('scenario', 'photometric')  % Use predefined scenario
    %   Total = calculateTransmission(wavelengths, 'humid')       % Custom wavelengths + scenario
    %   [Total, Components] = calculateTransmission(...)          % Return components too
    %
    % Input Options:
    %   - wavelengths (double array): Wavelength array in nm (optional)
    %   - scenario (string): Predefined scenario name (optional)
    %     Available scenarios: 'default', 'photometric_night', 'humid_conditions',
    %                         'high_altitude', 'sea_level', 'dusty_conditions'
    %   - 'no_atmosphere' / 'atmosphere_off': Disable atmospheric transmission
    %   - 'quiet': Suppress summary output
    %   - 'plot': Generate plots
    %
    % Output:
    %   - Total (double array): Total system transmission (0-1)
    %   - Components (struct): Individual transmission components (optional)
    %
    % Examples:
    %   % Basic usage
    %   Total = transmission.calculateTransmission();
    %
    %   % Custom wavelength range
    %   Lam = linspace(350, 950, 301)';
    %   Total = transmission.calculateTransmission(Lam);
    %
    %   % Photometric night conditions
    %   Total = transmission.calculateTransmission('photometric_night');
    %
    %   % Instrumental only (no atmosphere)
    %   Total = transmission.calculateTransmission('no_atmosphere');
    %
    %   % Custom wavelengths with specific conditions
    %   Lam = linspace(400, 900, 201)';
    %   Total = transmission.calculateTransmission(Lam, 'high_altitude', 'plot');
    %
    %   % Get individual components
    %   [Total, Components] = transmission.calculateTransmission();
    %   plot(Components.Wavelength, Components.Instrumental, ...
    %        Components.Wavelength, Components.Atmospheric, ...
    %        Components.Wavelength, Components.Total);
    %
    % Author: D. Kovaleva (Jul 2025)
    % Reference: Garrappa et al. 2025, A&A 699, A50.

    % Parse input arguments
    [Lam, Config, options] = parseInputs(varargin{:});
    
    % Apply options to Config
    Config = applyOptions(Config, options);
    
    % Calculate individual components
    Instrumental = transmission.instrumental.otaTransmission(Lam, Config);
    
    if Config.Atmospheric.Enable
        Atmospheric = transmission.atmospheric.atmosphericTransmission(Lam, Config);
    else
        Atmospheric = ones(size(Lam));
    end
    
    % Calculate total transmission
    Total = Instrumental .* Atmospheric;
    
    % Apply physical bounds
    Total = max(0, min(1, Total));
    
    % Prepare components output if requested
    if nargout > 1
        Components = struct();
        Components.Wavelength = Lam;
        Components.Instrumental = Instrumental;
        Components.Atmospheric = Atmospheric;
        Components.Total = Total;
        
        % Add metadata
        Components.Config = Config;
        Components.Summary = struct();
        Components.Summary.Peak_wavelength_nm = Lam(Total == max(Total));
        Components.Summary.Peak_transmission = max(Total);
        Components.Summary.Mean_transmission = mean(Total);
        Components.Summary.Effective_range_nm = getEffectiveRange(Lam, Total);
    end
    
    % Display summary if not suppressed
    if ~options.quiet
        displaySummary(Lam, Instrumental, Atmospheric, Total, Config);
    end
    
    % Generate plots if requested
    if options.plot
        generatePlots(Lam, Instrumental, Atmospheric, Total, Config);
    end
end

function [Lam, Config, options] = parseInputs(varargin)
    % Parse and validate input arguments
    
    % Default values
    Lam = [];
    scenario = 'default';
    options = struct('quiet', false, 'plot', false, 'no_atmosphere', false);
    
    % Process arguments
    i = 1;
    while i <= length(varargin)
        arg = varargin{i};
        
        if isnumeric(arg)
            % Wavelength array
            Lam = arg(:);  % Ensure column vector
            
        elseif ischar(arg) || isstring(arg)
            arg = char(arg);  % Convert to char for consistency
            
            switch lower(arg)
                case {'no_atmosphere', 'atmosphere_off', 'instrumental_only'}
                    options.no_atmosphere = true;
                    
                case {'quiet', 'silent', 'no_output'}
                    options.quiet = true;
                    
                case {'plot', 'plots', 'show_plots'}
                    options.plot = true;
                    
                case {'default', 'photometric_night', 'humid_conditions', ...
                      'high_altitude', 'sea_level', 'dusty_conditions', 'minimal', 'custom'}
                    scenario = arg;
                    
                otherwise
                    warning('transmission:calculateTransmission:unknownOption', ...
                            'Unknown option: %s', arg);
            end
        else
            error('transmission:calculateTransmission:invalidInput', ...
                  'Invalid input argument type: %s', class(arg));
        end
        
        i = i + 1;
    end
    
    % Create configuration
    Config = transmission.inputConfig(scenario);
    
    % Set default wavelength array if not provided
    if isempty(Lam)
        Lam = transmission.utils.makeWavelengthArray(Config);
    end
    
    % Validate wavelength array
    if ~isnumeric(Lam) || ~isvector(Lam) || any(Lam <= 0)
        error('transmission:calculateTransmission:invalidWavelengths', ...
              'Wavelength array must be a numeric vector with positive values');
    end
    
    % Ensure column vector
    Lam = Lam(:);
end

function Config = applyOptions(Config, options)
    % Apply user options to configuration
    
    if options.no_atmosphere
        Config.Atmospheric.Enable = false;
    end
    
    if options.quiet
        Config.Utils.Display.Show_summary = false;
    end
    
    if options.plot
        Config.Utils.Display.Show_plots = true;
    end
end

function displaySummary(Lam, Instrumental, Atmospheric, Total, Config)
    % Display transmission summary
    
    fprintf('\n=== Transmission Calculation Summary ===\n');
    fprintf('Wavelength range: %.1f - %.1f nm (%d points)\n', ...
            min(Lam), max(Lam), length(Lam));
    
    fprintf('Instrumental: %.6f - %.6f (mean: %.6f)\n', ...
            min(Instrumental), max(Instrumental), mean(Instrumental));
    
    if Config.Atmospheric.Enable
        fprintf('Atmospheric:  %.6f - %.6f (mean: %.6f)\n', ...
                min(Atmospheric), max(Atmospheric), mean(Atmospheric));
    else
        fprintf('Atmospheric:  disabled (unity)\n');
    end
    
    fprintf('Total:        %.6f - %.6f (mean: %.6f)\n', ...
            min(Total), max(Total), mean(Total));
    
    % Peak information
    [peak_val, peak_idx] = max(Total);
    fprintf('Peak: %.6f at %.1f nm\n', peak_val, Lam(peak_idx));
    
    % Effective range
    eff_range = getEffectiveRange(Lam, Total);
    if ~isempty(eff_range)
        fprintf('Effective range (>1%% peak): %.1f - %.1f nm\n', eff_range(1), eff_range(2));
    end
    
    fprintf('=======================================\n\n');
end

function range_vals = getEffectiveRange(Lam, Trans)
    % Get effective transmission range (>1% of peak)
    
    peak_val = max(Trans);
    effective_mask = Trans > 0.01 * peak_val;
    
    if any(effective_mask)
        range_vals = [min(Lam(effective_mask)), max(Lam(effective_mask))];
    else
        range_vals = [];
    end
end

function generatePlots(Lam, Instrumental, Atmospheric, Total, Config)
    % Generate transmission plots
    
    figure('Name', 'Transmission Analysis', 'NumberTitle', 'off');
    
    % Main transmission plot
    subplot(2, 1, 1);
    plot(Lam, Instrumental, 'b-', 'LineWidth', 2, 'DisplayName', 'Instrumental');
    hold on;
    
    if Config.Atmospheric.Enable
        plot(Lam, Atmospheric, 'r--', 'LineWidth', 2, 'DisplayName', 'Atmospheric');
    end
    
    plot(Lam, Total, 'k-', 'LineWidth', 3, 'DisplayName', 'Total');
    
    xlabel('Wavelength (nm)');
    ylabel('Transmission');
    title('System Transmission Components');
    legend('Location', 'best');
    grid on;
    ylim([0, 1]);
    
    % Logarithmic plot
    subplot(2, 1, 2);
    semilogy(Lam, Total, 'k-', 'LineWidth', 2);
    xlabel('Wavelength (nm)');
    ylabel('Total Transmission (log scale)');
    title('Total Transmission (Logarithmic Scale)');
    grid on;
    ylim([1e-6, 1]);
    
    % Add summary text
    peak_val = max(Total);
    mean_val = mean(Total);
    sgtitle(sprintf('Peak: %.3f | Mean: %.3f | Range: %.0f-%.0f nm', ...
                   peak_val, mean_val, min(Lam), max(Lam)), ...
           'FontWeight', 'bold');
end