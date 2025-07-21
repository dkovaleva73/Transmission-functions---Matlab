# MATLAB Transmission Package - Function Names

## ✅ **Updated Function Names (Following Convention)**

### **Naming Convention Applied:**
- First letter: **lowercase**
- Next words: **Capital letters** (camelCase)
- Abbreviations: **ALL CAPS** 
- **No underscores** unless abbreviations

---

## 📂 **Current Package Structure & Function Names**

### **Main Package Functions:**
```
+transmission/
├── atmosphericTotal.m                     # Combined atmospheric calculator
├── +atmospheric/                          # Atmospheric effects subpackage
│   ├── aerosolTransmittance.m            # Aerosol extinction
│   ├── rayleighTransmission.m            # Rayleigh scattering
│   ├── ozoneTransmission.m               # Ozone absorption
│   └── waterTransmittance.m              # Water vapor absorption
└── +utils/                               # Utilities subpackage
    ├── airmassFromSMARTS.m               # Airmass calculations
    └── makeWavelengthArray.m             # Wavelength array generation
```

---

## 🔧 **Function Call Syntax:**

### **Atmospheric Components:**
```matlab
transmission.atmospheric.rayleighTransmission(Z_, Pressure, Lam)
transmission.atmospheric.aerosolTransmittance(Z_, Tau_aod500, Alpha, Lam)  
transmission.atmospheric.ozoneTransmission(Z_, Dobson_units, Lam)
transmission.atmospheric.waterTransmittance(Z_, Precipitable_water, Pressure, Lam)
```

### **Combined Calculator:**
```matlab
transmission.atmosphericTotal(Z_, Params, Lam)
```

### **Utilities:**
```matlab
transmission.utils.makeWavelengthArray(Min_wvl, Max_wvl, Num_points)
transmission.utils.airmassFromSMARTS(Z_, Constituent)
```

---

## 📋 **Variable Naming Convention:**

### **Input Parameters:**
- **Z_** - Zenith angle in degrees
- **Lam** - Wavelength array in nm
- **Tau_something** - Optical depth values
- **Alpha** - Angstrom exponent
- **Pressure** - Surface pressure in mbar
- **Dobson_units** - Ozone column in Dobson units
- **Precipitable_water** - Water vapor in cm

### **Internal Variables:**
- **Am_** - Airmass values
- **Trans_component** - Transmission results
- **Absorption_coeff** - Absorption coefficients
- **Data_file** - File paths

---

## 💡 **Example Usage:**

```matlab
% Create wavelength array
Lam = transmission.utils.makeWavelengthArray(400, 800, 201);

% Individual components
Trans_rayleigh = transmission.atmospheric.rayleighTransmission(30, 1013.25, Lam);
Trans_aerosol = transmission.atmospheric.aerosolTransmittance(30, 0.1, 1.3, Lam);

% Combined transmission
Params.pressure = 1013.25;
Params.precipitable_water = 2.0;
Params.ozone_dobson = 300;
Params.aerosol_aod500 = 0.1;
Params.aerosol_alpha = 1.3;

Trans_total = transmission.atmosphericTotal(30, Params, Lam);
```

---

## ✅ **Status:**

### **Fully Working Functions:**
- ✅ `airmassFromSMARTS`
- ✅ `makeWavelengthArray` 
- ✅ `rayleighTransmission`
- ✅ `aerosolTransmittance`
- ✅ `ozoneTransmission`
- ✅ `atmosphericTotal` (without water component)

### **Partially Working:**
- ⚠️ `waterTransmittance` - requires internal variable name updates in helper functions

---

## 🎯 **Function Names Match Your Convention:**

**Original aerosolTransmission.m:**
```matlab
function transmission = aerosolTransmission(Z_, Tau_alpha500, Alpha, Lam)
```

**Package aerosolTransmittance.m:**
```matlab
function transmission = aerosolTransmittance(Z_, Tau_aod500, Alpha, Lam)
```

✅ **Perfect match** with your naming convention!