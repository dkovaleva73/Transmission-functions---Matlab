function [Spec, Mag, Coords, LASTData, Metadata] = findCalibratorsForAstroImage_search_htmcat(AIFile, SearchRadius, ImageNum)
    % Find Gaia sources with low-resolution spectra around LAST source positions
    % Input :  - AIFile - Path to LAST AstroImage
    %          - SearchRadius - Search radius in arcsec (default: 1)
    %          - ImageNum - number of the Field in AstroImage [1:24]
    % Output:  - Spec - Cell array {N x 2} with:
    %             - Column 1: Flux values (343 wavelength points)
    %             - Column 2: Flux error values (343 wavelength points)
    %             - Mag - Array of LAST PSF magnitudes for matched sources%
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
    %                .airMassFromLAST - air mass (if available)
    %                .Temperature - Temperature in Celsius (if available)
    %                .Pressure - Atmospheric pressure in hPa (if available)
    %                .ExpTime - Exposure time in seconds
    %                .JD - Julian Date
    %                .CatalogFile - Name of LAST catalog file
    % Reference : Garrappa et al. 2025, A&A 699, A50.
    % Author: A. Krassilshchikov, D. Kovaleva (Aug 2025)
    % Example:  AIfile = '/path/to/LAST_catalog.fits';
    %           [Spec, Mag, Coords, LASTData, Metadata] = transmissionFast.data.findCalibratorsWithCoords(AIfile, 3);
   
    
    arguments
        AIFile = transmissionFast.inputConfig().Data.LAST_AstroImage_file
        SearchRadius = transmissionFast.inputConfig().Data.Search_radius_arcsec
        ImageNum = 1 % number of the field in the AstroImage, Integer [1:24]
     end

      FluxIni = 7 ;    % 7 to 349: number of fields for flux values in GAIADR3spec 
      FluxEnd = 349;
      EFluxIni = 350;  % 350 to 692: number of fields for flux error values in GAIADR3spec 
      EFluxEnd = 692;    
      Npoint = 343;
      FlagMatchGaia = 1;
      MagFilterPSF = 16.0; % sources with MAG_PSF > MagFilterPSF are considered too faint for having sampled Gaia spectra
      MinSN = 5;     % Minimum and maximum LAST SN for calibrators
      MaxSN = 1000;

 tic
%for klm=1:10    
    RAD = constant.RAD;
    
    % Load LAST catalog
    if isa(AIFile,'AstroImage')
        AI = AIFile;
    else        
        AI=io.files.load2(AIFile);
    end

    AC = AI(ImageNum).CatData;
    % filter by MergedCatMask
    F = bitget(AC.Table.MergedCatMask,FlagMatchGaia) > 0; % test the 1st bit of the mask (corresponds to GAIA DR3 objects)
    Tab = AC.Table(F,:);
    
    % Apply quality filters before cone search
    % Filter: Remove sources with MAG_PSF > 16.0 (too faint for having sampled Gaia spectra)
    magFilterMask = true(height(Tab), 1);
    if ismember('MAG_PSF', Tab.Properties.VariableNames)
        magFilterMask = Tab.MAG_PSF < MagFilterPSF;  % Keep sources with MAG_PSF < 16.0
    end
    
    Tab = Tab(magFilterMask, :);
    
    fprintf('Magnitude filtering: removed %d sources with MAG_PSF >= 16.0\n', ...
        sum(~magFilterMask));
    
     % Filter 1: Remove sources with bad FLAGS  
     badFlagsMask = false(height(Tab), 1);
     if ismember('FLAGS', Tab.Properties.VariableNames)
         for i = 1:height(Tab)
              flags = Tab.FLAGS(i);
            % Decode FLAGS using bit operations (common LAST flag structure)
            % Skip sources that are ONLY bad (Saturated, NaN, Negative, CR_DeltaHT, NearEdge)
             isSaturated = bitget(flags, 1);  % Bit 1: Saturated
             isNaN = bitget(flags, 2);        % Bit 2: NaN  
             isNegative = bitget(flags, 3);   % Bit 3: Negative
             isCR = bitget(flags, 4);         % Bit 4: CR_DeltaHT (cosmic ray)
             isNearEdge = bitget(flags, 5);   % Bit 5: NearEdge
            
             % Mark as bad if it has ONLY problematic flags and no good flags
             onlyBadFlags = (isSaturated && isNaN && isNegative && isCR && isNearEdge);
          %   onlyBadFlags = false;
          
             if onlyBadFlags
                 badFlagsMask(i) = true;
             end
         end
     end
    % 
    % Filter 2: Remove sources with S/N outside acceptable range 
     badSNMask = false(height(Tab), 1);
     if ismember('SN', Tab.Properties.VariableNames)
         sn_values = Tab.SN;
         badSNMask = (sn_values < MinSN) | (sn_values > MaxSN);
     end
    % 
    % Combine quality filters
     qualityMask = ~badFlagsMask & ~badSNMask;
     Tab = Tab(qualityMask, :);
     
     fprintf('Quality filtering: removed %d sources with bad flags or S/N\n', ...
         sum(~qualityMask));
    
    % Get total number of LAST sources after filtering
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
    
    %for i = 1 : Nsrc
        [~, ~, ~, Sp] = VO.search.search_htmcat('GAIADR3spec', AC.Table.RA, AC.Table.Dec, SearchRadius);  
          if ~isempty(Sp)
                SpTab = Sp.Table;
                matchCount = height(SpTab);
                SpArray = table2array(SpTab);
                SrcSpecCol1 = mat2cell(SpArray(:,FluxIni:FluxEnd), ones(matchCount,1), Npoint);   % F
                SrcSpecCol2 = mat2cell(SpArray(:,EFluxIni:EFluxEnd), ones(matchCount,1), Npoint); % Ferr
                SrcSpec = [SrcSpecCol1, SrcSpecCol2];
                
                % Store magnitude
                MagPSF = Tab.MAG_PSF;
                
                % Store Gaia coordinates (convert from radians to degrees) - first match only
                Gaia_RA = SpArray(:, 1) * RAD;   % Column 1 is RA in radians, first row
                Gaia_Dec = SpArray(:, 2) * RAD;  % Column 2 is Dec in radians, first row
                
                % Store LAST coordinates and pixel positions~.Table
                LAST_RA = Tab.RA;
                LAST_Dec = Tab.Dec;
                LAST_X = Tab.X;
                LAST_Y = Tab.Y;
                
                % Store original LAST catalog index (from filtered table)
            %    LAST_idx(i) = i;
                
                % If needed, store Gaia source ID (with precision loss warning)
                % SrcID(i) = int64(Sp(1, 3));  % Column 3 is source_id
          end
    %end
   % end
                
    
    % Filter out sources without spectra
 % *  validMask = MagPSF > 0;
    
 %   % Check-up 2: Remove LAST sources with multiple Gaia matches
 %   if sum(validMask) > 0
 %       % Find LAST sources that have multiple valid Gaia matches
 %       valid_indices = validMask;
 %       last_idx_valid = LAST_idx(valid_indices);
 %       
 %       % Count occurrences of each LAST index
 %       [unique_last, ~, idx_map] = unique(last_idx_valid);
 %       counts = accumarray(idx_map, 1);
 %       
 %       % Find LAST indices that appear more than once
 %       duplicated = unique_last(counts > 1);
 %       
 %       % Mark all matches for duplicated LAST sources as invalid
 %       for i = 1:length(duplicated)
 %           validMask(LAST_idx == duplicated(i)) = false;
 %       end
 %   end
    
    % Extract valid entries
% *    Spec = SrcSpec(validMask, :);
% *    Mag = MagPSF(validMask);
    Spec = SrcSpec;
    Mag = MagPSF;

    % Extract LAST catalog data for valid entries using logical indexing
% *    LASTData = Tab(validMask, :);  % Get LAST catalog data for matched sources
    LASTData = Tab;    
    % Create coordinate structure for valid entries using logical indexing
% *    valid_Gaia_RA = Gaia_RA(validMask);
% *    valid_Gaia_Dec = Gaia_Dec(validMask);
% *   valid_LAST_RA = LAST_RA(validMask);
% *    valid_LAST_Dec = LAST_Dec(validMask);
% *   valid_LAST_X = LAST_X(validMask);
% *   valid_LAST_Y = LAST_Y(validMask);
% *   valid_LAST_idx = LAST_idx(validMask);
    
    Coords = struct();
% *    numValid = sum(validMask);
    numValid = matchCount; 

  %  for i = 1 : numValid
   %*     Coords.Gaia_RA = valid_Gaia_RA;
   %*     Coords.Gaia_Dec = valid_Gaia_Dec;
   %*     Coords.LAST_RA = valid_LAST_RA;
   %*     Coords.LAST_Dec = valid_LAST_Dec;
   %*     Coords.LAST_X = valid_LAST_X;
   %*     Coords.LAST_Y = valid_LAST_Y;
   %*     Coords.LAST_idx = valid_LAST_idx;
  %  end
         Coords.Gaia_RA = Gaia_RA;
         Coords.Gaia_Dec = Gaia_Dec;
         Coords.LAST_RA = LAST_RA;
         Coords.LAST_Dec = LAST_Dec;
         Coords.LAST_X = LAST_X;
         Coords.LAST_Y = LAST_Y;
         
    % Display summary
    fprintf('Found %d LAST sources with Gaia spectra matches\n', numValid);
    fprintf('Search radius: %.1f arcsec\n', SearchRadius);
    
    % Optional: Show coordinate differences
   if ~isempty(Coords)
     %   separations = repmat(0,length(Coords), 1); 
     %   for i = 1:length(Coords)
     %       % Calculate separation in arcsec
     %       sep = celestial.coo.sphere_dist_fast(Coords(i).LAST_RA, Coords(i).LAST_Dec, ...
     %                                           Coords(i).Gaia_RA, Coords(i).Gaia_Dec);
     %       separations(i) = sep * 3600; % Convert to arcsec
     %   end
        
    % Extract metadata from LAST catalog header using AstroHeader

    Metadata = struct();  
    try
        Header = AI(1).HeaderData;
    catch
        Header = [];
    end
    
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
    end
   % end
   end
        
        try
            Metadata.FieldDec = Header.getVal('DEC');
        catch
            Metadata.FieldDec = NaN;
        end
  
    
    % Add catalog filename to metadata
    [~, filename, ext] = fileparts(AIFile);
    Metadata.CatalogFile = [filename ext];
    
    fprintf('\nMetadata extracted: AirMass=%.3f, Temp=%.1f°C, ExpTime=%.1fs\n', ...
            Metadata.airMassFromLAST, Metadata.Temperature, Metadata.ExpTime);
 %   end   
 ElapsedTime = toc;  % Store elapsed time instead of printing it
end