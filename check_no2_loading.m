% Check what NO2 data looks like after loading

% Load NO2 data
Abs_data = transmission.data.loadAbsorptionData([], {'NO2'}, false);

% Check at 350 nm
idx_350 = find(abs(Abs_data.NO2.wavelength - 350) < 0.1);
if ~isempty(idx_350)
    fprintf('NO2 data at 350 nm:\n');
    fprintf('  Wavelength: %.1f nm\n', Abs_data.NO2.wavelength(idx_350(1)));
    fprintf('  Absorption value: %.4e\n', Abs_data.NO2.absorption(idx_350(1)));
    fprintf('  Correction applied: %s\n', Abs_data.NO2.correction_applied);
end

% Check raw file values
fprintf('\nRaw file values at 350 nm (from Abs_NO2.dat):\n');
fprintf('  sigma = 3.83010E-19\n');
fprintf('  b0 = 4.90E-22\n');
fprintf('  Expected after correction: %.4e\n', ...
    constant.Loschmidt * (3.83010E-19 + 4.90E-22 * (228.7 - 220)));

% Check the actual loaded data dimensions
fprintf('\nLoaded data info:\n');
fprintf('  Wavelength range: [%.1f, %.1f] nm\n', ...
    min(Abs_data.NO2.wavelength), max(Abs_data.NO2.wavelength));
fprintf('  Data shape: %d x %d\n', size(Abs_data.NO2.absorption));
fprintf('  Number of columns: %d\n', size(Abs_data.NO2.absorption, 2));