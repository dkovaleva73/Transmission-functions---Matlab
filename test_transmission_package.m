function test_transmission_package()
    % Test function for the atmospheric transmission package
    % Run this to verify the package is working correctly
    
    fprintf('Testing MATLAB Atmospheric Transmission Package\n');
    fprintf('===============================================\n\n');
    
    % Test parameters
    zenith_angle = 30;
    wavelength = transmission.utils.makeWavelengthArray(400, 800, 101);
    
    %% Test 1: Utility functions
    fprintf('Test 1: Utility functions\n');
    try
        % Test wavelength array generation
        wvl1 = transmission.utils.makeWavelengthArray();
        wvl2 = transmission.utils.makeWavelengthArray(500, 700, 51);
        
        assert(length(wvl1) == 401, 'Default wavelength array length incorrect');
        assert(abs(wvl2(1) - 500) < 1e-10, 'Wavelength array start incorrect');
        assert(abs(wvl2(end) - 700) < 1e-10, 'Wavelength array end incorrect');
        
        % Test airmass calculation
        am_rayleigh = transmission.utils.airmassFromSMARTS(30, 'rayleigh');
        am_aerosol = transmission.utils.airmassFromSMARTS(30, 'aerosol');
        
        assert(am_rayleigh > 1, 'Airmass should be > 1 for zenith angle > 0');
        assert(am_aerosol > 1, 'Airmass should be > 1 for zenith angle > 0');
        assert(abs(am_rayleigh - am_aerosol) < 1, 'Airmass values should be similar');
        
        fprintf('  ✓ Wavelength array generation works\n');
        fprintf('  ✓ Airmass calculation works\n');
        
    catch ME
        fprintf('  ✗ Utility functions failed: %s\n', ME.message);
        return;
    end
    
    %% Test 2: Rayleigh scattering
    fprintf('\nTest 2: Rayleigh scattering\n');
    try
        trans_rayleigh = transmission.atmospheric.rayleighTransmission(zenith_angle, 1013.25, wavelength);
        
        assert(all(trans_rayleigh >= 0 & trans_rayleigh <= 1), 'Transmission not in [0,1]');
        assert(trans_rayleigh(1) < trans_rayleigh(end), 'Rayleigh should decrease with wavelength');
        
        fprintf('  ✓ Rayleigh transmission calculated\n');
        fprintf('  ✓ Values in valid range [0,1]\n');
        fprintf('  ✓ Wavelength dependence correct\n');
        
    catch ME
        fprintf('  ✗ Rayleigh scattering failed: %s\n', ME.message);
        return;
    end
    
    %% Test 3: Aerosol extinction
    fprintf('\nTest 3: Aerosol extinction\n');
    try
        trans_aerosol = transmission.atmospheric.aerosolTransmittance(zenith_angle, 0.1, 1.3, wavelength);
        
        assert(all(trans_aerosol >= 0 & trans_aerosol <= 1), 'Transmission not in [0,1]');
        assert(trans_aerosol(1) < trans_aerosol(end), 'Aerosol should decrease with wavelength');
        
        % Test different AOD values
        trans_low_aod = transmission.atmospheric.aerosolTransmittance(zenith_angle, 0.05, 1.3, wavelength);
        trans_high_aod = transmission.atmospheric.aerosolTransmittance(zenith_angle, 0.2, 1.3, wavelength);
        
        assert(all(trans_low_aod >= trans_high_aod), 'Higher AOD should give lower transmission');
        
        fprintf('  ✓ Aerosol transmission calculated\n');
        fprintf('  ✓ Values in valid range [0,1]\n');
        fprintf('  ✓ Wavelength dependence correct\n');
        fprintf('  ✓ AOD dependence correct\n');
        
    catch ME
        fprintf('  ✗ Aerosol extinction failed: %s\n', ME.message);
        return;
    end
    
    %% Test 4: Ozone absorption
    fprintf('\nTest 4: Ozone absorption\n');
    try
        trans_ozone = transmission.atmospheric.ozoneTransmission(zenith_angle, 300, wavelength);
        
        assert(all(trans_ozone >= 0 & trans_ozone <= 1), 'Transmission not in [0,1]');
        
        fprintf('  ✓ Ozone transmission calculated\n');
        fprintf('  ✓ Values in valid range [0,1]\n');
        
    catch ME
        if contains(ME.message, 'Ozone data file')
            fprintf('  ⚠ Ozone data file not found (expected in some installations)\n');
        else
            fprintf('  ✗ Ozone absorption failed: %s\n', ME.message);
            return;
        end
    end
    
    %% Test 5: Water vapor absorption
    fprintf('\nTest 5: Water vapor absorption\n');
    try
        trans_water = transmission.atmospheric.waterTransmittance(zenith_angle, 2.0, 1013.25, wavelength);
        
        assert(all(trans_water >= 0 & trans_water <= 1), 'Transmission not in [0,1]');
        
        fprintf('  ✓ Water vapor transmission calculated\n');
        fprintf('  ✓ Values in valid range [0,1]\n');
        
    catch ME
        if contains(ME.message, 'Water vapor data file')
            fprintf('  ⚠ Water vapor data file not found (expected in some installations)\n');
        else
            fprintf('  ✗ Water vapor absorption failed: %s\n', ME.message);
            return;
        end
    end
    
    %% Test 6: Combined atmospheric transmission
    fprintf('\nTest 6: Combined atmospheric transmission\n');
    try
        params.pressure = 1013.25;
        params.precipitable_water = 2.0;
        params.ozone_dobson = 300;
        params.aerosol_aod500 = 0.1;
        params.aerosol_alpha = 1.3;
        
        trans_total = transmission.atmosphericTotal(zenith_angle, params, wavelength);
        
        assert(all(trans_total >= 0 & trans_total <= 1), 'Transmission not in [0,1]');
        
        % Test that individual components can be disabled
        trans_no_aerosol = transmission.atmosphericTotal(zenith_angle, params, wavelength, ...
                                                         'include_aerosol', false);
        
        assert(all(trans_no_aerosol >= trans_total), ...
               'Removing aerosol should increase transmission');
        
        fprintf('  ✓ Combined transmission calculated\n');
        fprintf('  ✓ Values in valid range [0,1]\n');
        fprintf('  ✓ Component selection works\n');
        
    catch ME
        fprintf('  ✗ Combined atmospheric transmission failed: %s\n', ME.message);
        return;
    end
    
    %% Test 7: Physical consistency
    fprintf('\nTest 7: Physical consistency checks\n');
    try
        % Test zenith angle dependence
        trans_zenith_0 = transmission.atmosphericTotal(0, params, wavelength);
        trans_zenith_60 = transmission.atmosphericTotal(60, params, wavelength);
        
        assert(all(trans_zenith_0 >= trans_zenith_60), ...
               'Higher zenith angle should give lower transmission');
        
        % Test wavelength coverage
        uv_wavelengths = 300:50:400;
        vis_wavelengths = 400:100:700;
        nir_wavelengths = 700:100:1100;
        
        trans_uv = transmission.atmosphericTotal(zenith_angle, params, uv_wavelengths);
        trans_vis = transmission.atmosphericTotal(zenith_angle, params, vis_wavelengths);
        trans_nir = transmission.atmosphericTotal(zenith_angle, params, nir_wavelengths);
        
        assert(all([trans_uv, trans_vis, trans_nir] >= 0), 'All transmissions should be non-negative');
        
        fprintf('  ✓ Zenith angle dependence correct\n');
        fprintf('  ✓ Wavelength coverage adequate\n');
        fprintf('  ✓ Physical constraints satisfied\n');
        
    catch ME
        fprintf('  ✗ Physical consistency failed: %s\n', ME.message);
        return;
    end
    
    %% Summary
    fprintf('\n===============================================\n');
    fprintf('✓ All tests passed successfully!\n');
    fprintf('The atmospheric transmission package is working correctly.\n\n');
    
    fprintf('Available functions:\n');
    fprintf('  transmission.atmospheric.rayleighTransmission\n');
    fprintf('  transmission.atmospheric.aerosolTransmittance\n');
    fprintf('  transmission.atmospheric.ozoneTransmission\n');
    fprintf('  transmission.atmospheric.waterTransmittance\n');
    fprintf('  transmission.atmospheric.umgTransmittance\n');
    fprintf('  transmission.atmosphericTotal\n');
    fprintf('  transmission.utils.makeWavelengthArray\n');
    fprintf('  transmission.utils.airmassFromSMARTS\n\n');
    
    fprintf('Run example_atmospheric_transmission.m for detailed examples.\n');
end