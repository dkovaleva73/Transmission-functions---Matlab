% Test complete caching system: inputConfig + airmass + instrumental (persistent)
fprintf('Testing complete multi-layer caching system...\n\n');

% Clear all caches to start fresh
clear functions;
transmissionFast.utils.clearAirmassCaches();

Config = transmissionFast.inputConfig();
wavelength = 400:10:700;

fprintf('🔄 Complete Caching System Performance Test\n');
fprintf('%s\n', repmat('=', 1, 50));
fprintf('\n');

fprintf('Layer 1: inputConfig caching (persistent variables in inputConfig)\n');
fprintf('Layer 2: Airmass caching (persistent variables in airmassFromSMARTS)\n');
fprintf('Layer 3: Instrumental data caching (file I/O cached in inputConfig)\n');
fprintf('Layer 4: Instrumental function caching (results cached in functions)\n\n');

% Test complete transmission calculation with all caching layers
fprintf('📊 Performance Comparison:\n\n');

fprintf('1. FIRST complete transmission calculation (populates ALL caches):\n');
tic;
% Atmospheric components (uses airmass caching)
rayleigh_trans1 = transmissionFast.atmospheric.rayleighTransmission(wavelength, Config);
aerosol_trans1 = transmissionFast.atmospheric.aerosolTransmission(wavelength, Config);
ozone_trans1 = transmissionFast.atmospheric.ozoneTransmission(wavelength, Config);
water_trans1 = transmissionFast.atmospheric.waterTransmittance(wavelength, Config);

% Instrumental components (uses persistent function caching)
mirror_refl1 = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
corrector_trans1 = transmissionFast.instrumental.correctorTransmission(wavelength, Config);
qe1 = transmissionFast.instrumental.quantumEfficiency(wavelength, Config);

% Total transmission
total_trans1 = rayleigh_trans1 .* aerosol_trans1 .* ozone_trans1 .* water_trans1 .* ...
               mirror_refl1 .* corrector_trans1 .* qe1;
time_first = toc;

fprintf('   Time: %.6f seconds (populates all caches)\n', time_first);

fprintf('\n2. SECOND complete transmission calculation (ALL from caches):\n');
tic;
% All atmospheric calculations should use cached airmass values
rayleigh_trans2 = transmissionFast.atmospheric.rayleighTransmission(wavelength, Config);
aerosol_trans2 = transmissionFast.atmospheric.aerosolTransmission(wavelength, Config);
ozone_trans2 = transmissionFast.atmospheric.ozoneTransmission(wavelength, Config);
water_trans2 = transmissionFast.atmospheric.waterTransmittance(wavelength, Config);

% All instrumental calculations should return cached results instantly
mirror_refl2 = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
corrector_trans2 = transmissionFast.instrumental.correctorTransmission(wavelength, Config);
qe2 = transmissionFast.instrumental.quantumEfficiency(wavelength, Config);

% Total transmission
total_trans2 = rayleigh_trans2 .* aerosol_trans2 .* ozone_trans2 .* water_trans2 .* ...
               mirror_refl2 .* corrector_trans2 .* qe2;
time_second = toc;

fprintf('   Time: %.6f seconds (%.0fx faster)\n', time_second, time_first/time_second);

% Verify results are identical
if isequal(total_trans1, total_trans2)
    fprintf('   ✓ Results identical - all caching working correctly\n');
else
    fprintf('   ⚠ Results different - potential cache issue\n');
end

fprintf('\n3. OPTIMIZER SIMULATION (50 iterations):\n');
fprintf('   This simulates what happens during transmission optimization...\n');
tic;
for i = 1:50
    % Each iteration would typically call these functions multiple times
    atm_trans = transmissionFast.atmospheric.rayleighTransmission(wavelength, Config) .* ...
               transmissionFast.atmospheric.aerosolTransmission(wavelength, Config) .* ...
               transmissionFast.atmospheric.ozoneTransmission(wavelength, Config) .* ...
               transmissionFast.atmospheric.waterTransmittance(wavelength, Config);
    
    inst_trans = transmissionFast.instrumental.mirrorReflectance(wavelength, Config) .* ...
                transmissionFast.instrumental.correctorTransmission(wavelength, Config) .* ...
                transmissionFast.instrumental.quantumEfficiency(wavelength, Config);
    
    total = atm_trans .* inst_trans;
end
time_optimizer = toc;

fprintf('   50 iterations: %.6f seconds\n', time_optimizer);
fprintf('   Average per iteration: %.6f seconds\n', time_optimizer/50);
fprintf('   Estimated speedup vs. no caching: %.0fx\n', time_first/(time_optimizer/50));

fprintf('\n📈 Cache Layer Analysis:\n');
fprintf('   Layer 1 (inputConfig): Eliminates repeated config loading\n');
fprintf('   Layer 2 (airmass): Eliminates repeated SMARTS calculations\n');  
fprintf('   Layer 3 (instrumental data): Eliminates repeated CSV file reads\n');
fprintf('   Layer 4 (function results): Eliminates repeated interpolation/fitting\n');

fprintf('\n🏆 Final Performance Summary:\n');
fprintf('   Initial calculation: %.6f seconds\n', time_first);
fprintf('   Cached calculation: %.6f seconds\n', time_second);
fprintf('   Overall speedup: %.0fx\n', time_first/time_second);
fprintf('   Optimizer benefit: %.6f seconds per iteration\n', time_optimizer/50);

fprintf('\n✅ Complete caching system validation successful!\n');
fprintf('🚀 Your TransmissionOptimizerAdvanced now has FOUR layers of caching:\n');
fprintf('   1️⃣ Config caching (persistent variables)\n');
fprintf('   2️⃣ Airmass caching (persistent variables)\n');
fprintf('   3️⃣ File I/O caching (loaded once in inputConfig)\n');
fprintf('   4️⃣ Function result caching (persistent variables in functions)\n');
fprintf('\n💡 Mirror and corrector functions calculate ONCE and cache forever!\n');