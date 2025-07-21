function transmission = waterTransmittance(Z_, Precipitable_water, Pressure, Lam)
    % Calculate water vapor transmission.
    %
    % Parameters:
    %   Z_ (double): The zenith angle in degrees.
    %   Precipitable_water (double): The precipitable water in cm.
    %   Pressure (double): The pressure in hPa.
    %   Lam (double array): Wavelength array in nm.
    %
    % Returns:
    %   transmission (double array): The calculated transmission values (0-1).
    %
    % Example:
    %   Lam = transmission.utils.make_wavelength_array();
    %   Trans = transmission.atmospheric.water(30, 2.0, 1013.25, Lam);
    
    % Try multiple possible locations for water data file
    Possible_paths = {
        '/home/dana/Documents/MATLAB/inwork/data/Templates/Abs_H2O.dat', ...
        '/home/dana/anaconda3/lib/python3.12/site-packages/transmission_fitter/data/Templates/Abs_H2O.dat'
    };
    
    Data_file = '';
    for I = 1:length(Possible_paths)
        if exist(Possible_paths{I}, 'file')
            Data_file = Possible_paths{I};
            break;
        end
    end
    
    if isempty(Data_file)
        error('Water vapor data file (Abs_H2O.dat) not found in any expected location');
    end
    
    % Read water absorption data (skip header line)
    Data = readtable(Data_file, 'Delimiter', '\t', 'ReadVariableNames', false, 'HeaderLines', 1);
    
    % Extract column data based on the format:
    % Col 1: Wavelength, Col 2: Abs coeff, Col 3: Band, Col 4: empty, 
    % Col 5: fit(Bw), Col 6: a0(Bw), Col 7: a1(Bw), Col 8: a2(Bw), Col 9: empty,
    % Col 10: fit(Bm), Col 11: a0(Bm), Col 12: a1(Bm), Col 13: a2(Bm), Col 14: empty,
    % Col 15: fit(Bmw), Col 16: a0(Bmw), Col 17: a1(Bmw), Col 18: a2(Bmw), Col 19: empty,
    % Col 20: a1(Bp), Col 21: a2(Bp)
    
    H2o_wavelength = Data.Var1;
    H2o_absorption = Data.Var2;
    Iband = Data.Var3;
    
    % Get coefficients for different fitting methods
    Ifitw = Data.Var5;
    Bwa0 = Data.Var6;
    Bwa1 = Data.Var7;
    Bwa2 = Data.Var8;
    
    Ifitm = Data.Var10;
    Bma0 = Data.Var11;
    Bma1 = Data.Var12;
    Bma2 = Data.Var13;
    
    Ifitmw = Data.Var15;
    Bmwa0 = Data.Var16;
    Bmwa1 = Data.Var17;
    Bmwa2 = Data.Var18;
    
    Bpa1 = Data.Var20;
    Bpa2 = Data.Var21;
    
    % Calculate airmass
    import transmission.utils.airmassFromSMARTS
    Am_ = airmassFromSMARTS(Z_, 'h2o');
    
    % Calculate transmittance factors using helper functions
    Bw = calculate_Bw(Precipitable_water, Iband, Ifitw, Bwa0, Bwa1, Bwa2, H2o_absorption);
    Bm = calculate_Bm(Am_, Ifitm, Bma0, Bma1, Bma2, H2o_absorption);
    Bmw = calculate_Bmw(Precipitable_water, Am_, Iband, Ifitmw, Bmwa0, Bmwa1, Bmwa2, ...
                        Bw, Bm, H2o_absorption);
    Bp = calculate_Bp(Precipitable_water, Pressure, Am_, Iband, Bpa1, Bpa2, H2o_absorption);
    
    % Calculate water optical depth
    Precipitable_water_airmass = (Precipitable_water * Am_)^0.9426;
    Tau_water = Bmw .* Bp .* H2o_absorption .* Precipitable_water_airmass;
    
    % Interpolate to requested wavelength array
    Tau_water_interp = interp1(H2o_wavelength, Tau_water, Lam, 'linear', 0);
    
    % Calculate transmission and clip to [0,1]
    transmission = exp(-Tau_water_interp);
    transmission = max(0, min(1, transmission));
end

function Bw = calculate_Bw(Pw, Iband, Ifitw, Bwa0, Bwa1, Bwa2, H2o_abs)
    % Calculate water transmittance factor Bw
    Pw0 = 4.11467 * ones(size(Iband));
    Pw0(Iband == 2) = 2.92232;
    Pw0(Iband == 3) = 1.41642;
    Pw0(Iband == 4) = 0.41612;
    Pw0(Iband == 5) = 0.05663;
    
    Pww0 = Pw - Pw0;
    
    Bw = 1 + Bwa0 .* Pww0 + Bwa1 .* Pww0.^2;
    
    % Apply different fitting methods based on Ifitw
    Mask1 = (Ifitw == 1);
    Bw(Mask1) = Bw(Mask1) ./ (1 + Bwa2(Mask1) .* Pww0(Mask1));
    
    Mask2 = (Ifitw == 2);
    Bw(Mask2) = Bw(Mask2) ./ (1 + Bwa2(Mask2) .* Pww0(Mask2).^2);
    
    Mask6 = (Ifitw == 6);
    Bw(Mask6) = Bwa0(Mask6) + Bwa1(Mask6) .* Pww0(Mask6);
    
    % Set to 1 where absorption is negligible
    Bw(H2o_abs <= 0) = 1;
    
    % Clip to reasonable range
    Bw = max(0.05, min(7.0, Bw));
end

function Bm = calculate_Bm(Am, Ifitm, Bma0, Bma1, Bma2, H2o_abs)
    % Calculate molecular transmittance factor Bm
    Am1 = Am - 1;
    Am12 = Am1^2;
    
    Bm = ones(size(Bma1));
    
    % Apply different fitting methods based on Ifitm
    Mask0 = (Ifitm == 0);
    Bm(Mask0) = Bma1(Mask0) .* (Am .^ Bma2(Mask0));
    
    Mask1 = (Ifitm == 1);
    Bm(Mask1) = (1 + Bma0(Mask1) .* Am1 + Bma1(Mask1) .* Am12) ./ ...
                (1 + Bma2(Mask1) .* Am1);
    
    Mask2 = (Ifitm == 2);
    Bm(Mask2) = (1 + Bma0(Mask2) .* Am1 + Bma1(Mask2) .* Am12) ./ ...
                (1 + Bma2(Mask2) .* Am12);
    
    Mask3 = (Ifitm == 3);
    Bm(Mask3) = (1 + Bma0(Mask3) .* Am1 + Bma1(Mask3) .* Am12) ./ ...
                (1 + Bma2(Mask3) .* Am1^0.5);
    
    Mask5 = (Ifitm == 5);
    Bm(Mask5) = (1 + Bma0(Mask5) .* Am1^0.25) ./ ...
                (1 + Bma2(Mask5) .* Am1^0.1);
    
    % Set to 1 where absorption is negligible
    Bm(H2o_abs <= 0) = 1;
    
    % Clip to reasonable range
    Bm = max(0.05, min(7.0, Bm));
end

function Bmw = calculate_Bmw(Pw, Am, Iband, Ifitmw, Bmwa0, Bmwa1, Bmwa2, Bw, Bm, H2o_abs)
    % Calculate combined water and molecular transmittance factor Bmw
    Bmw = Bm .* Bw;
    
    % Define reference water vapor amounts by band
    W0 = 4.11467 * ones(size(Iband));
    W0(Iband == 2) = 2.92232;
    W0(Iband == 3) = 1.41642;
    W0(Iband == 4) = 0.41612;
    W0(Iband == 5) = 0.05663;
    
    % Check conditions for using alternative formulation
    Cond1 = abs(Bw - 1) < 1e-6;
    Cond2 = (abs(Bm - 1) < 1e-6);
    Cond3 = (Bm > 0.968) & (Bm < 1.0441);
    Cond4 = (Ifitmw == -1) | (H2o_abs <= 0);
    
    Use_original = Cond1 | Cond2 | Cond3 | Cond4;
    
    % Calculate alternative formulation where needed
    Amw = Am * (Pw ./ W0);
    Amw1 = Amw - 1;
    Amw12 = Amw1.^2;
    
    Bmw_alt = ones(size(Bmw));
    
    Mask0 = (Ifitmw == 0) & (H2o_abs > 0);
    Bmw_alt(Mask0) = Bmwa1(Mask0) .* (Amw(Mask0) .^ Bmwa2(Mask0));
    
    Mask1 = (Ifitmw == 1) & (H2o_abs > 0);
    Bmw_alt(Mask1) = (1 + Bmwa0(Mask1) .* Amw1(Mask1) + Bmwa1(Mask1) .* Amw12(Mask1)) ./ ...
                     (1 + Bmwa2(Mask1) .* Amw1(Mask1));
    
    Mask2 = (Ifitmw == 2) & (H2o_abs > 0);
    Bmw_alt(Mask2) = (1 + Bmwa0(Mask2) .* Amw1(Mask2) + Bmwa1(Mask2) .* Amw12(Mask2)) ./ ...
                     (1 + Bmwa2(Mask2) .* Amw12(Mask2));
    
    % Use alternative where conditions are not met
    Bmw(~Use_original) = Bmw_alt(~Use_original);
    
    % Clip to reasonable range
    Bmw = max(0.05, min(7.0, Bmw));
end

function Bp = calculate_Bp(Pw, Pr, Am, Iband, Bpa1, Bpa2, H2o_abs)
    % Calculate pressure transmittance factor Bp
    Pwm = Pw * Am;
    Pp0 = Pr / 1013.25;
    Pp01 = max(0.65, Pp0);
    Pp02 = Pp01^2;
    Qp = 1 - Pp0;
    Qp1 = min(0.35, Qp);
    Qp2 = Qp1^2;
    
    Bp = (1 + 0.1623 * Qp) * ones(size(Iband));
    
    Mask2 = (Iband == 2) & (H2o_abs > 0);
    Bp(Mask2) = 1 + 0.08721 * Qp1;
    
    Mask3 = (Iband == 3) & (H2o_abs > 0);
    A = 1 - Bpa1(Mask3) .* Qp1 - Bpa2(Mask3) .* Qp2;
    Bp(Mask3) = A;
    
    Mask4 = (Iband == 4) & (H2o_abs > 0);
    A4 = 1 - Bpa1(Mask4) .* Qp1 - Bpa2(Mask4) .* Qp2;
    B4 = 1 - Pwm * exp(-0.63486 + 6.9149 * Pp01 - 13.853 * Pp02);
    Bp(Mask4) = A4 .* B4;
    
    Mask5 = (Iband == 5) & (H2o_abs > 0);
    A5 = 1 - Bpa1(Mask5) .* Qp1 - Bpa2(Mask5) .* Qp2;
    B5 = 1 - Pwm * exp(8.9243 - 18.197 * Pp01 + 2.4141 * Pp02);
    Bp(Mask5) = A5 .* B5;
    
    % Set to 1 where pressure correction is negligible or absorption is zero
    Bp((abs(Qp) < 1e-5) | (H2o_abs <= 0)) = 1;
    
    % Clip to reasonable range
    Bp = max(0.3, min(1.7, Bp));
end