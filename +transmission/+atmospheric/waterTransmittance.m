function Trans = waterTransmittance(Lam, Config, Args)
    % Water vapor transmission of the Earth atmosphere. SMARTS 2.9.5 model implementation 
    % Input :  - Lam (double array): Wavelength array.
    %          - Config (struct): Configuration struct from inputConfig()
    %            Uses Config.Atmospheric.Zenith_angle_deg
    %            Uses Config.Atmospheric.Components.Water.Pwv_cm
    %            Uses Config.Atmospheric.Pressure_mbar
    %            Uses Config.Data.Wave_units
    %          * ...,key,val,...
    %            'AbsorptionData' - Pre-loaded absorption data to avoid file I/O
    % Output : - Trans (double array): The calculated transmission values (0-1).
    % Reference: Gueymard, C. A. (2019). Solar Energy, 187, 233-253.
    % Author : D. Kovaleva (Jul 2025) 
    % Example: Config = transmission.inputConfig('default');
    %          Lam = transmission.utils.makeWavelengthArray(Config);
    %          Trans = transmission.atmospheric.waterTransmittance(Lam, Config);
    %          % With pre-loaded data:
    %          AbsData = transmission.data.loadAbsorptionData([], {'H2O'}, false);
    %          Trans = transmission.atmospheric.waterTransmittance(Lam, Config, 'AbsorptionData', AbsData);

    arguments
        Lam = transmission.utils.makeWavelengthArray(transmission.inputConfig())
        Config = transmission.inputConfig()
        Args.AbsorptionData = []  % Optional pre-loaded absorption data
    end
    
    % Extract parameters from Config
    Z_ = Config.Atmospheric.Zenith_angle_deg;
    Pw_ = Config.Atmospheric.Components.Water.Pwv_cm;
    Pressure = Config.Atmospheric.Pressure_mbar;
    WaveUnits = Config.Data.Wave_units;

    % Input validation: critical physics bounds only
    if Z_ < 0 || Z_ > 90
        error('transmission:waterTransmission:invalidZenith', 'Zenith angle must be in [0,90] degrees');
    end
    if Pw_ < 0
        error('transmission:waterTransmission:invalidWater', 'Precipitable water must be non-negative');
    end
    if Pressure <= 0
        error('transmission:waterTransmission:invalidPressure', 'Pressure must be positive');  
    end

    % Load water vapor absorption data - use cached if provided
    if ~isempty(Args.AbsorptionData)
        Abs_data = Args.AbsorptionData;
    else
        Abs_data = transmission.data.loadAbsorptionData([], {'H2O'}, false);
    end

    % Direct data extraction with error handling
    if ~isfield(Abs_data, 'H2O')
        error('transmission:waterTransmission:missingData', 'H2O data required');
    end

    H2O_data = Abs_data.H2O;
    H2O_wavelength = H2O_data.wavelength;
    H2O_absorption = H2O_data.absorption;
    Band = H2O_data.band;
    
    if isfield(H2O_data, 'Bw_coeffs')
        % Using vectorized data structure - coefficients already organized in matrices
        Ifitw = H2O_data.ifitw;
        Bwa0 = H2O_data.Bw_coeffs(:,1);
        Bwa1 = H2O_data.Bw_coeffs(:,2);
        Bwa2 = H2O_data.Bw_coeffs(:,3);
        Ifitm = H2O_data.ifitm;
        Bma0 = H2O_data.Bm_coeffs(:,1);
        Bma1 = H2O_data.Bm_coeffs(:,2);
        Bma2 = H2O_data.Bm_coeffs(:,3);
        Ifitmw = H2O_data.ifitmw;
        Bmwa0 = H2O_data.Bmw_coeffs(:,1);
        Bmwa1 = H2O_data.Bmw_coeffs(:,2);
        Bmwa2 = H2O_data.Bmw_coeffs(:,3);
        Bpa1 = H2O_data.Bp_coeffs(:,1);
        Bpa2 = H2O_data.Bp_coeffs(:,2);
    else
        % Fallback to standard data structure
        Fit_coeffs = H2O_data.fit_coeffs;
        Ifitw = Fit_coeffs.Ifitw;
        Bwa0 = Fit_coeffs.Bwa0;
        Bwa1 = Fit_coeffs.Bwa1;
        Bwa2 = Fit_coeffs.Bwa2;
        Ifitm = Fit_coeffs.Ifitm;
        Bma0 = Fit_coeffs.Bma0;
        Bma1 = Fit_coeffs.Bma1;
        Bma2 = Fit_coeffs.Bma2;
        Ifitmw = Fit_coeffs.Ifitmw;
        Bmwa0 = Fit_coeffs.Bmwa0;
        Bmwa1 = Fit_coeffs.Bmwa1;
        Bmwa2 = Fit_coeffs.Bmwa2;
        Bpa1 = Fit_coeffs.Bpa1;
        Bpa2 = Fit_coeffs.Bpa2;
    end

    % Calculate airmass using SMARTS coefficients
    Am_ = transmission.utils.airmassFromSMARTS('h2o', Config);

    % =========================================================================
    % INLINED Bw CALCULATION. Use pre-computed pw0 lookup if available
    % =========================================================================

    % Reference precipitable water values by band 
    if isfield(H2O_data, 'pw0_lookup')
        Pw0 = H2O_data.pw0_lookup;
    else
        % Fallback computation
        Pw0 = 4.11467 * ones(size(Band));
        Pw0(Band == 2) = 2.92232;
        Pw0(Band == 3) = 1.41642;
        Pw0(Band == 4) = 0.41612;
        Pw0(Band == 5) = 0.05663;
    end

    Pww0 = Pw_ - Pw0;

    % Basic quadratic fit (vectorized)
    Bw = 1 + Bwa0 .* Pww0 + Bwa1 .* (Pww0.^2);

    % Apply different fitting functions based on Ifitw 
    mask1 = (Ifitw == 1);
    if any(mask1)
        Bw(mask1) = Bw(mask1) ./ (1 + Bwa2(mask1) .* Pww0(mask1));
    end

    mask2 = (Ifitw == 2);  
    if any(mask2)
        Bw(mask2) = Bw(mask2) ./ (1 + Bwa2(mask2) .* (Pww0(mask2).^2));
    end

    mask6 = (Ifitw == 6);
    if any(mask6)
        Bw(mask6) = Bwa0(mask6) + Bwa1(mask6) .* Pww0(mask6);
    end

    % Set Bw = 1 where absorption is negligible (vectorized)
    Bw(H2O_absorption <= 0) = 1;

    % Clip to valid range (vectorized)
    Bw = max(0.05, min(7.0, Bw));

    % =========================================================================
    % INLINED Bm CALCULATION 
    % =========================================================================

    Am1 = Am_ - 1;
    Am12 = Am1^2;

    Bm = ones(size(Ifitm));

    % Different fitting functions based on Ifitm (vectorized)
    mask0 = (Ifitm == 0);
    if any(mask0)
        Bm(mask0) = Bma1(mask0) .* (Am_.^Bma2(mask0));
    end

    mask1 = (Ifitm == 1);
    if any(mask1)
        Bmx = (1 + Bma0(mask1)*Am1 + Bma1(mask1)*Am12) ./ (1 + Bma2(mask1)*Am1);
        Bm(mask1) = Bmx;
    end

    mask2 = (Ifitm == 2);
    if any(mask2)
        Bmx = (1 + Bma0(mask2)*Am1 + Bma1(mask2)*Am12) ./ (1 + Bma2(mask2)*Am12);
        Bm(mask2) = Bmx;
    end

    mask3 = (Ifitm == 3);
    if any(mask3)
        Bmx = (1 + Bma0(mask3)*Am1 + Bma1(mask3)*Am12) ./ (1 + Bma2(mask3)*sqrt(Am1));
        Bm(mask3) = Bmx;
    end

    mask5 = (Ifitm == 5);
    if any(mask5)
        Bmx = (1 + Bma0(mask5)*(Am1.^0.25)) ./ (1 + Bma2(mask5)*(Am1.^0.1));
        Bm(mask5) = Bmx;
    end

    % Set Bm = 1 where absorption is negligible
    Bm(H2O_absorption <= 0) = 1;

    % Clip to valid range
    Bm = max(0.05, min(7.0, Bm));

    % =========================================================================
    % INLINED Bmw CALCULATION 
    % =========================================================================

    Bmw = Bm .* Bw;

    % Define conditions where simple multiplication applies (vectorized)
    Cond1 = abs(Bw - 1) < 1e-6;
    Cond2 = ((Ifitm ~= 0) | (H2O_absorption <= 0)) & (abs(Bm - 1) < 1e-6);
    Cond3 = ((Ifitm == 0) | (H2O_absorption <= 0)) & (Bm > 0.968) & (Bm < 1.0441);
    Cond4 = (Ifitmw == -1) | (H2O_absorption <= 0);
    Combined_cond = Cond1 | Cond2 | Cond3 | Cond4;

    % For complex cases, use advanced fitting (inlined)
    complex_mask = ~Combined_cond;
    if any(complex_mask)
        % Reference water values by band
        % MEMORY OPTIMIZATION: Reuse Pw0 if already computed
        W0 = Pw0;  % Reuse pre-computed values

        Amw = Am_ * (Pw_ ./ W0);
        Amw1 = Amw - 1;
        Amw12 = Amw1.^2;

        Bmwx = ones(size(Bmw));

        % Different fitting functions based on Ifitmw (vectorized)
        mask0 = (Ifitmw == 0) & (H2O_absorption > 0);
        if any(mask0)
            Bmwx(mask0) = Bmwa1(mask0) .* (Amw(mask0).^Bmwa2(mask0));
        end

        mask1 = (Ifitmw == 1) & (H2O_absorption > 0);  
        if any(mask1)
            Bmwx(mask1) = (1 + Bmwa0(mask1).*Amw1(mask1) + Bmwa1(mask1).*Amw12(mask1)) ./ ...
                          (1 + Bmwa2(mask1).*Amw1(mask1));
        end

        mask2 = (Ifitmw == 2) & (H2O_absorption > 0);
        if any(mask2)
            Bmwx(mask2) = (1 + Bmwa0(mask2).*Amw1(mask2) + Bmwa1(mask2).*Amw12(mask2)) ./ ...
                          (1 + Bmwa2(mask2).*Amw12(mask2));
        end

        % Apply advanced fitting where conditions are not met
        Bmw(complex_mask) = Bmwx(complex_mask);
    end

    % Clip to valid range
    Bmw = max(0.05, min(7.0, Bmw));

    % =========================================================================
    % INLINED Bp CALCULATION 
    % =========================================================================

    Pwm = Pw_ * Am_;
    Pp0 = Pressure / 1013.25;
    Pp01 = max(0.65, Pp0);
    Pp02 = Pp01^2;
    Qp = 1 - Pp0;
    Qp1 = min(0.35, Qp);
    Qp2 = Qp1^2;

    % Default pressure correction (vectorized)
    Bp = (1 + 0.1623 * Qp) * ones(size(Band));

    % Band-specific corrections (vectorized)
    mask2 = (Band == 2) & (H2O_absorption > 0);
    if any(mask2)
        Bp(mask2) = 1 + 0.08721 * Qp1;
    end

    mask3 = (Band == 3) & (H2O_absorption > 0);
    if any(mask3)
        A = 1 - Bpa1(mask3) .* Qp1 - Bpa2(mask3) .* Qp2;
        Bp(mask3) = A;
    end

    mask4 = (Band == 4) & (H2O_absorption > 0);
    if any(mask4)
        A4 = 1 - Bpa1(mask4) .* Qp1 - Bpa2(mask4) .* Qp2;
        B4 = 1 - Pwm .* exp(-0.63486 + 6.9149*Pp01 - 13.853*Pp02);
        Bp(mask4) = A4 .* B4;
    end

    mask5 = (Band == 5) & (H2O_absorption > 0);
    if any(mask5)
        A5 = 1 - Bpa1(mask5) .* Qp1 - Bpa2(mask5) .* Qp2;
        B5 = 1 - Pwm .* exp(8.9243 - 18.197*Pp01 + 2.4141*Pp02);
        Bp(mask5) = A5 .* B5;
    end

    % Set Bp = 1 where pressure effects are negligible
    Bp((abs(Qp) < 1e-5) | (H2O_absorption <= 0)) = 1;

    % Clip to valid range
    Bp = max(0.3, min(1.7, Bp));

    % Water vapor optical depth 
    Pwm = (Pw_ * Am_).^0.9426;
    Tauw_l = Bmw .* Bp .* H2O_absorption * Pwm;

    % Interpolation 
    if ~isequal(H2O_wavelength, Lam)
        Tauw_l_interp = interp1(H2O_wavelength, Tauw_l, Lam, 'linear', 0);
    else
        Tauw_l_interp = Tauw_l;
    end

    % Transmission calculation with bounds 
    Trans = exp(-Tauw_l_interp);
    % No clipping to preserve error detection

    % =========================================================================
end