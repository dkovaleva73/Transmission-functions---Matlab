function [Spec, Mag, Coords, LASTData, Metadata] = findCalibratorsWithCoords(CatFile, SearchRadius)
    % Find Gaia sources with low-resolution spectra around LAST source positions
    % Input :  - CatFile - Path to LAST catalog FITS file
    %          - SearchRadius - Search radius in arcsec (default: 3)
    % Output:  - Spec - Cell array {N x 2} with:
    %             - Column 1: Flux values (343 wavelength points)
    %             - Column 2: Flux error values (343 wavelength points)
    %             - Mag - Array of LAST PSF magnitudes for matched sources
    %             - Coords - Structure array with coordinate information:
    %                .Gaia_RA - Gaia DR3 RA (deg)
    %                .Gaia_Dec - Gaia DR3 Dec (deg)
    %                .LAST_RA - LAST catalog RA (deg)
    %                .LAST_Dec - LAST catalog Dec (deg)
    %                .LAST_X - LAST pixel X coordinate
    %                .LAST_Y - LAST pixel Y coordinate
    %                .LAST_idx - Original index in LAST catalog
    %          - LASTData - Array with LAST catalog data for matched sources
    %          - Metadata - Structure with LAST observation metadata:
    %                .airMassFromLAST - airmass from LAST observation (if available)
    %                .Temperature - Temperature in Celsius (if available)
    %                .Pressure - Atmospheric pressure in hPa (if available)
    %                .ExpTime - Exposure time in seconds
    %                .JD - Julian Date
    %                .CatalogFile - Name of LAST catalog file
    % Reference : Garrappa et al. 2025, A&A 699, A50.
    % Author: A. Krassilshchikov, D. Kovaleva (Aug 2025)
    % Example:  CatFile = '/path/to/LAST_catalog.fits';
    %           [Spec, Mag, Coords, LASTData, Metadata] = transmissionFast.data.findCalibratorsWithCoords(CatFile, 3);
   
    
    arguments
       CatFile = transmissionFast.inputConfig().Data.LAST_catalog_file;
    %    CatFile = "/home/dana/matlab/data/transmission_fitter/LASTfiles/LAST.01.10.04_20240311.193844.471_clear_923_000_001_001_sci_coadd_Cat_1.fits";
    %    CatFile = "/home/dana/matlab/data/transmission_fitter/LASTfiles/LAST.01.08.03_20230616.222625.384_clear_346+79_000_001_001_sci_coadd_Cat_1.fits";
    %    CatFile = "/home/dana/matlab/data/transmission_fitter/LASTfiles/LAST.01.10.04_20240311.194154.510_clear_923_010_001_004_sci_proc_Cat_1.fits"
    %%%% CatFile = "/home/dana/matlab/data/transmission_fitter/LASTfiles/LAST.01.10.04_20240311.194154.510_clear_923_010_001_016_sci_proc_Cat_1.fits"
    %/transmission_fitter/data/Image_Test/Stability_Single/LAST.01.10.04_20240303.191215.553_clear_923_001_001_016_sci_proc_Cat_1.fits
      SearchRadius = 1 % arcsec
    end
 tic
%for klm=1:10    
    RAD = constant.RAD;
    
    % Load LAST catalog
    AC = AstroCatalog(CatFile);
    if contains(CatFile,"coadd") 
    % filter by MergedCatMask
       F = bitget(AC.Table.MergedCatMask,1) > 0; % test the 1st bit of the mask (corresponds to GAIA DR3 objects)
       Tab = AC.Table(F,:);
    else 
       Tab = AC.Table(:,:);   
    end

    % Get total number of LAST sources
    Nsrc = height(Tab);
    % Initialize arrays
    SrcSpec = cell(Nsrc, 2);
    MagPSF  = repmat(0, Nsrc, 1);%#ok<*RPMT0>
    % SrcID   = repmat(int64(0), Nsrc, 1);
    
    % Initialize coordinate arrays Tab = AC.Table(:,:);   
    Gaia_RA = repmat(NaN, Nsrc, 1);%#ok<*RPMTN>
    Gaia_Dec = repmat(NaN, Nsrc, 1);
    LAST_RA = repmat(NaN, Nsrc, 1);
    LAST_Dec = repmat(NaN, Nsrc, 1);
    LAST_X = repmat(NaN, Nsrc, 1);
    LAST_Y = repmat(NaN, Nsrc, 1);
    LAST_idx = repmat(0, Nsrc, 1);
    
    % Search for Gaia sources with spectra around each LAST source
    matchCount = 0;
    
    for i = 1 : Nsrc
        [Sp,~,~,D] = catsHTM.cone_search('GAIADR3spec', Tab.RA(i)./RAD, Tab.Dec(i)./RAD, SearchRadius);
  %      Sp = catsHTM.sources_match('GAIADR3spec', AC);%, 'Args.SearchRadius', SearchRadius, 'Args.ColRA', Tab.RA(i)./RAD, 'Args.ColDec', Tab.Dec(i)./RAD);
  %   Sp = catsHTM.search_htm_ind('GAIADR3spec_htm.hdf5', Tab, Tab.RA(i)./RAD, Tab.Dec(i)./RAD, SearchRadius);
       if D > 0
            matchCount = matchCount + 1;
            
            % Extract spectra
            SrcSpec{i,1} = Sp(:,7:349);    % F
            SrcSpec{i,2} = Sp(:,350:692);  % Ferr
            
            % Store magnitude
            MagPSF(i) = Tab.MAG_PSF(i);
            
            % Store Gaia coordinates (convert from radians to degrees)
            Gaia_RA(i) = Sp(1, 1) * RAD;   % Column 1 is RA in radians
            Gaia_Dec(i) = Sp(1, 2) * RAD;  % Column 2 is Dec in radians
            
            % Store LAST coordinates and pixel positions
            LAST_RA(i) = Tab.RA(i);
            LAST_Dec(i) = Tab.Dec(i);
            LAST_X(i) = Tab.X(i);
            LAST_Y(i) = Tab.Y(i);
            
            % Store original LAST catalog index (from filtered table)
            LAST_idx(i) = i;
            
            % If needed, store Gaia source ID (with precision loss warning)
            % SrcID(i) = int64(Sp(1, 3));  % Column 3 is source_id
        end
    end
    
    % Filter out sources without spectra
    validMask = MagPSF > 0;
    
    % Check-up 1: Remove sources with Mag >= 16
    validMask = validMask & MagPSF < 16;
    
    % Check-up 2: Remove LAST sources with multiple Gaia matches
    if sum(validMask) > 0
        % Find LAST sources that have multiple valid Gaia matches
        valid_indices = validMask;
        last_idx_valid = LAST_idx(valid_indices);
        
        % Count occurrences of each LAST index
        [unique_last, ~, idx_map] = unique(last_idx_valid);
        counts = accumarray(idx_map, 1);
        
        % Find LAST indices that appear more than once
        duplicated = unique_last(counts > 1);
        
        % Mark all matches for duplicated LAST sources as invalid
        for i = 1:length(duplicated)
            validMask(LAST_idx == duplicated(i)) = false;
        end
    end
    
    % Extract valid entries
    Spec = SrcSpec(validMask, :);
    Mag = MagPSF(validMask);
    
    % Extract LAST catalog data for valid entries using logical indexing
    LASTData = Tab(validMask, :);  % Get LAST catalog data for matched sources
    
    % Create coordinate structure for valid entries using logical indexing
    valid_Gaia_RA = Gaia_RA(validMask);
    valid_Gaia_Dec = Gaia_Dec(validMask);
    valid_LAST_RA = LAST_RA(validMask);
    valid_LAST_Dec = LAST_Dec(validMask);
    valid_LAST_X = LAST_X(validMask);
    valid_LAST_Y = LAST_Y(validMask);
    valid_LAST_idx = LAST_idx(validMask);
    
    Coords = struct();
    numValid = sum(validMask);
    
    for i = 1:numValid
        Coords(i).Gaia_RA = valid_Gaia_RA(i);
        Coords(i).Gaia_Dec = valid_Gaia_Dec(i);
        Coords(i).LAST_RA = valid_LAST_RA(i);
        Coords(i).LAST_Dec = valid_LAST_Dec(i);
        Coords(i).LAST_X = valid_LAST_X(i);
        Coords(i).LAST_Y = valid_LAST_Y(i);
        Coords(i).LAST_idx = valid_LAST_idx(i);
    end
    
    % Display summary
    fprintf('Found %d LAST sources with Gaia spectra matches\n', matchCount);
    fprintf('Search radius: %.1f arcsec\n', SearchRadius);
    
    % Optional: Show coordinate differences
    if ~isempty(Coords)
        separations = repmat(0,length(Coords), 1); 
        for i = 1:length(Coords)
            % Calculate separation in arcsec
            sep = celestial.coo.sphere_dist_fast(Coords(i).LAST_RA, Coords(i).LAST_Dec, ...
                                                Coords(i).Gaia_RA, Coords(i).Gaia_Dec);
            separations(i) = sep * 3600; % Convert to arcsec
        end
        
 %       fprintf('LAST-Gaia separation: mean=%.2f", max=%.2f"\n', ...
 %               mean(separations), max(separations));
 %   end
    
    % Extract metadata from LAST catalog header using AstroHeader
    try
        Header = AstroHeader(CatFile, 3);
    catch
        Header = [];
    end
    
    Metadata = struct();
    
    % Extract exposure time and JD (always available)
    if ~isempty(Header)
        try
            Metadata.ExpTime = Header.getVal('EXPTIME');
        catch
            Metadata.ExpTime = NaN;
        end
        
        try
            Metadata.JD = Header.getVal('JD');
        catch
            Metadata.JD = NaN;
        end
        
        % Extract airmass from LAST 
        try
            Metadata.airMassFromLAST = Header.getVal('AIRMASS');
        catch
            Metadata.airMassFromLAST = NaN;
        end
        
        % Extract temperature from MNTTEMP field only
        try
            Metadata.Temperature = Header.getVal('MNTTEMP');
        catch
            Metadata.Temperature = NaN;
        end
        
        % Extract pressure (if available)
        try
            Metadata.Pressure = Header.getVal('PRESSURE');
        catch
            try
                Metadata.Pressure = Header.getVal('PRESS');
            catch
                Metadata.Pressure = NaN;
            end
        end
        
        % Add field center coordinates
        try
            Metadata.FieldRA = Header.getVal('RA');
        catch
            Metadata.FieldRA = NaN;
        end
        
        try
            Metadata.FieldDec = Header.getVal('DEC');
        catch
            Metadata.FieldDec = NaN;
        end
    else
        % Header failed to load - set all to NaN
        Metadata.ExpTime = NaN;
        Metadata.JD = NaN;
        Metadata.airMassFromLAST = NaN;
        Metadata.Temperature = NaN;
        Metadata.Pressure = NaN;
        Metadata.FieldRA = NaN;
        Metadata.FieldDec = NaN;
    end
  %  Metadata.airMassFromLAST = 1.715;
  %   Metadata.airMassFromLAST = 1.165;
    % Add catalog filename to metadata
    [~, filename, ext] = fileparts(CatFile);
    Metadata.CatalogFile = [filename ext];
   % Metadata.Temperature = 25;
    fprintf('\nMetadata extracted: AirMass=%.3f, Temp=%.1f°C, ExpTime=%.1fs, Pressure=%.1fmPA\n', ...
            Metadata.airMassFromLAST, Metadata.Temperature, Metadata.ExpTime, Metadata.Pressure);
 %   end   
 toc
end