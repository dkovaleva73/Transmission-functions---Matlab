function Trans = waterTransmission(Z_, Pw_, Pressure, Lam, Args)
    % Water vapor transmission of the Earth atmosphere.
    % Based on SMARTS 2.9.5 model with advanced fitting coefficients.
    % Input :  - Z_ (double): The zenith angle in degrees.
    %          - Pw_ (double): The precipitable water in cm.
    %          - Pressure (double): The atmospheric pressure in mbar.
    %          - Lam (double array): Wavelength array (by default, in nm).
    %          - Abs_data (struct, optional): Pre-loaded absorption data from loadAbsorptionData()
    %          * ...,key,val,...
    %             'WaveUnits' -  'A','Ang'|'nm'
    %             'AbsData' - Pre-loaded absorption data structure
    % Output : - Trans (double array): The calculated transmission values (0-1).
    % Reference: SMARTS 2.9.5 model implementation
    % Author : D. Kovaleva (Jul 2025)
    % Example: % Standalone usage:
    %          Lam = transmission.utils.makeWavelengthArray();
    %          Trans = transmission.atmospheric.waterTransmission(30, 2.5, 1013.25, Lam);
    %          % Pipeline usage:
    %          Abs_data = transmission.data.loadAbsorptionData();
    %          Trans = transmission.atmospheric.waterTransmission(30, 2.5, 1013.25, Lam, 'AbsData', Abs_data);
    
    arguments
        Z_
        Pw_
        Pressure
        Lam
        Args.WaveUnits = 'nm';
        Args.AbsData = [];
    end
    
    % Input validation
    if Z_ > 90 || Z_ < 0
        error('Zenith angle out of range [0, 90] deg');
    end
    
    if Pw_ < 0
        error('Precipitable water must be non-negative');
    end
    
    if Pressure <= 0
        error('Pressure must be positive');
    end
    
    % Get water vapor absorption data
    if isempty(Args.AbsData)
        % Load data if not provided (standalone usage)
        Abs_data = transmission.data.loadAbsorptionData([], {'H2O'}, false);
    else
        % Use pre-loaded data (efficient pipeline usage)
        Abs_data = Args.AbsData;
    end
    
    % Extract water vapor data directly
    if ~isfield(Abs_data, 'H2O')
        error('H2O data not found in absorption data structure');
    end
    
    H2O_data = Abs_data.H2O;
    
    % Extract fitting coefficients from water vapor data
    % The H2O data file contains multiple columns with fitting coefficients
    H2O_wavelength = H2O_data.wavelength;    % nm
    H2O_absorption = H2O_data.absorption;     % Base absorption
    
    % Check if fitting coefficients are available
    if isfield(H2O_data, 'fit_coeffs') && ~isempty(H2O_data.fit_coeffs)
        Fit_coeffs = H2O_data.fit_coeffs;
        
        % Extract all fitting parameters
        Band = H2O_data.band;
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
    else
        error('Water vapor fitting coefficients not found in absorption data');
    end
    
    % Calculate airmass using SMARTS coefficients
    Am_ = transmission.utils.airmassFromSMARTS(Z_, 'h2o');
    
    % Calculate correction factors
    Bw = calculateBw(Pw_, Band, Ifitw, Bwa0, Bwa1, Bwa2, H2O_absorption);
    Bm = calculateBm(Am_, Ifitm, Bma0, Bma1, Bma2, H2O_absorption);
    Bmw = calculateBmw(Pw_, Am_, Bw, Bm, Band, Ifitm, Ifitmw, H2O_absorption, ...
                       Bmwa0, Bmwa1, Bmwa2);
    Bp = calculateBp(Pw_, Pressure, Am_, Band, Bpa1, Bpa2, H2O_absorption);
    
    % Calculate water vapor optical depth
    Pwm = (Pw_ * Am_).^0.9426;
    Tauw_l = Bmw .* Bp .* H2O_absorption * Pwm;
    
    % Interpolate to desired wavelength array
    if ~isequal(H2O_wavelength, Lam)
        Tauw_l_interp = interp1(H2O_wavelength, Tauw_l, Lam, 'linear', 0);
    else
        Tauw_l_interp = Tauw_l;
    end
    
    % Calculate transmission and clip to [0,1]
    Trans = exp(-Tauw_l_interp);
    Trans = max(0, min(1, Trans));
end

function Bw = calculateBw(Pw, Band, Ifitw, Bwa0, Bwa1, Bwa2, H2O_absorption)
    % Calculate water transmittance factor Bw
    
    % Define reference precipitable water values by band
    Pw0 = 4.11467 * ones(size(Band));
    Pw0(Band == 2) = 2.92232;
    Pw0(Band == 3) = 1.41642;
    Pw0(Band == 4) = 0.41612;
    Pw0(Band == 5) = 0.05663;
    
    Pww0 = Pw - Pw0;
    
    % Basic quadratic fit
    Bw = 1 + Bwa0 .* Pww0 + Bwa1 .* (Pww0.^2);
    
    % Apply different fitting functions based on Ifitw
    mask1 = (Ifitw == 1);
    Bw(mask1) = Bw(mask1) ./ (1 + Bwa2(mask1) .* Pww0(mask1));
    
    mask2 = (Ifitw == 2);
    Bw(mask2) = Bw(mask2) ./ (1 + Bwa2(mask2) .* (Pww0(mask2).^2));
    
    mask6 = (Ifitw == 6);
    Bw(mask6) = Bwa0(mask6) + Bwa1(mask6) .* Pww0(mask6);
    
    % Set Bw = 1 where absorption is negligible
    Bw(H2O_absorption <= 0) = 1;
    
    % Clip to valid range
    Bw = max(0.05, min(7.0, Bw));
end

function Bm = calculateBm(Am_, Ifitm, Bma0, Bma1, Bma2, H2O_absorption)
    % Calculate molecular transmittance factor Bm
    
    Am1 = Am_ - 1;
    Am12 = Am1.^2;
    
    Bm = ones(size(Ifitm));
    
    % Different fitting functions based on Ifitm
    mask0 = (Ifitm == 0);
    Bm(mask0) = Bma1(mask0) .* (Am_.^Bma2(mask0));
    
    mask1 = (Ifitm == 1);
    Bmx = (1 + Bma0(mask1)*Am1 + Bma1(mask1)*Am12) ./ (1 + Bma2(mask1)*Am1);
    Bm(mask1) = Bmx;
    
    mask2 = (Ifitm == 2);
    Bmx = (1 + Bma0(mask2)*Am1 + Bma1(mask2)*Am12) ./ (1 + Bma2(mask2)*Am12);
    Bm(mask2) = Bmx;
    
    mask3 = (Ifitm == 3);
    Bmx = (1 + Bma0(mask3)*Am1 + Bma1(mask3)*Am12) ./ (1 + Bma2(mask3)*sqrt(Am1));
    Bm(mask3) = Bmx;
    
    mask5 = (Ifitm == 5);
    Bmx = (1 + Bma0(mask5)*(Am1^0.25)) ./ (1 + Bma2(mask5)*(Am1^0.1));
    Bm(mask5) = Bmx;
    
    % Set Bm = 1 where absorption is negligible
    Bm(H2O_absorption <= 0) = 1;
    
    % Clip to valid range
    Bm = max(0.05, min(7.0, Bm));
end

function Bmw = calculateBmw(Pw, Am_, Bw, Bm, Band, Ifitm, Ifitmw, H2O_absorption, ...
                           Bmwa0, Bmwa1, Bmwa2)
    % Calculate combined water and molecular transmittance factor Bmw
    
    Bmw = Bm .* Bw;
    
    % Define conditions where simple multiplication applies
    Cond1 = abs(Bw - 1) < 1e-6;
    Cond2 = ((Ifitm ~= 0) | (H2O_absorption <= 0)) & (abs(Bm - 1) < 1e-6);
    Cond3 = ((Ifitm == 0) | (H2O_absorption <= 0)) & (Bm > 0.968) & (Bm < 1.0441);
    Cond4 = (Ifitmw == -1) | (H2O_absorption <= 0);
    Combined_cond = Cond1 | Cond2 | Cond3 | Cond4;
    
    % For complex cases, use advanced fitting
    if any(~Combined_cond)
        % Reference water values by band
        W0 = 4.11467 * ones(size(Band));
        W0(Band == 2) = 2.92232;
        W0(Band == 3) = 1.41642;
        W0(Band == 4) = 0.41612;
        W0(Band == 5) = 0.05663;
        
        Amw = Am_ * (Pw ./ W0);
        Amw1 = Amw - 1;
        Amw12 = Amw1.^2;
        
        Bmwx = ones(size(Bmw));
        
        % Different fitting functions based on Ifitmw
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
        Bmw(~Combined_cond) = Bmwx(~Combined_cond);
    end
    
    % Clip to valid range
    Bmw = max(0.05, min(7.0, Bmw));
end

function Bp = calculateBp(Pw, Pressure, Am_, Band, Bpa1, Bpa2, H2O_absorption)
    % Calculate pressure transmittance factor Bp
    
    Pwm = Pw * Am_;
    Pp0 = Pressure / 1013.25;
    Pp01 = max(0.65, Pp0);
    Pp02 = Pp01.^2;
    Qp = 1 - Pp0;
    Qp1 = min(0.35, Qp);
    Qp2 = Qp1.^2;
    
    % Default pressure correction
    Bp = (1 + 0.1623 * Qp) * ones(size(Band));
    
    % Band-specific corrections
    mask2 = (Band == 2) & (H2O_absorption > 0);
    Bp(mask2) = 1 + 0.08721 * Qp1;
    
    mask3 = (Band == 3) & (H2O_absorption > 0);
    A = 1 - Bpa1(mask3) .* Qp1 - Bpa2(mask3) .* Qp2;
    Bp(mask3) = A;
    
    mask4 = (Band == 4) & (H2O_absorption > 0);
    if any(mask4)
        A4 = 1 - Bpa1(mask4) .* Qp1 - Bpa2(mask4) .* Qp2;
        B4 = 1 - Pwm * exp(-0.63486 + 6.9149*Pp01 - 13.853*Pp02);
        Bp(mask4) = A4 .* B4;
    end
    
    mask5 = (Band == 5) & (H2O_absorption > 0);
    if any(mask5)
        A5 = 1 - Bpa1(mask5) .* Qp1 - Bpa2(mask5) .* Qp2;
        B5 = 1 - Pwm * exp(8.9243 - 18.197*Pp01 + 2.4141*Pp02);
        Bp(mask5) = A5 .* B5;
    end
    
    % Set Bp = 1 where pressure effects are negligible
    Bp((abs(Qp) < 1e-5) | (H2O_absorption <= 0)) = 1;
    
    % Clip to valid range
    Bp = max(0.3, min(1.7, Bp));
end