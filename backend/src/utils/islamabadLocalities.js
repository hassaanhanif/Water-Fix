/**
 * Genuine, verified Islamabad localities and recognized sectors with real coordinates.
 * Includes Hostel City (Park Road / COMSATS area) for testing and nearby supplier discovery.
 */

const ISLAMABAD_LOCALITIES = [
  { name: 'Hostel City, Park Road (Near COMSATS)', sector: 'Hostel City', lat: 33.6515, lng: 73.1566 },
  { name: 'F-6 Markaz (Super Market)', sector: 'F-6', lat: 33.7297, lng: 73.0746 },
  { name: 'F-7 Markaz (Jinnah Super)', sector: 'F-7', lat: 33.7215, lng: 73.056 },
  { name: 'F-8 Markaz (Ayub Market)', sector: 'F-8', lat: 33.7126, lng: 73.0381 },
  { name: 'F-10 Markaz', sector: 'F-10', lat: 33.6931, lng: 73.0033 },
  { name: 'F-11 Markaz', sector: 'F-11', lat: 33.6842, lng: 72.988 },
  { name: 'G-6 (Melody Market / Aabpara)', sector: 'G-6', lat: 73.0827, lng: 33.7078, lat: 33.7078, lng: 73.0827 },
  { name: 'G-7 Markaz (Sitara Market)', sector: 'G-7', lat: 33.7029, lng: 73.0645 },
  { name: 'G-8 Markaz', sector: 'G-8', lat: 33.6923, lng: 73.0458 },
  { name: 'G-9 Markaz (Karachi Company)', sector: 'G-9', lat: 33.6881, lng: 73.0289 },
  { name: 'G-10 Markaz', sector: 'G-10', lat: 33.6795, lng: 73.0116 },
  { name: 'G-11 Markaz', sector: 'G-11', lat: 33.6702, lng: 72.9961 },
  { name: 'G-13 Markaz', sector: 'G-13', lat: 33.6518, lng: 72.9702 },
  { name: 'G-14 Sector', sector: 'G-14', lat: 33.6425, lng: 72.9554 },
  { name: 'G-15 Sector', sector: 'G-15', lat: 33.6338, lng: 72.9412 },
  { name: 'H-8 Educational Sector', sector: 'H-8', lat: 33.6789, lng: 73.0691 },
  { name: 'H-9 Higher Tech Sector', sector: 'H-9', lat: 33.6712, lng: 73.0487 },
  { name: 'H-10 Sector (IIUI Campus)', sector: 'H-10', lat: 33.6601, lng: 73.0276 },
  { name: 'H-11 Police Lines', sector: 'H-11', lat: 33.6512, lng: 73.0054 },
  { name: 'H-12 Sector (NUST Campus)', sector: 'H-12', lat: 33.6428, lng: 72.9905 },
  { name: 'H-13 Sector', sector: 'H-13', lat: 33.6334, lng: 72.9723 },
  { name: 'I-8 Markaz', sector: 'I-8', lat: 33.6685, lng: 73.0768 },
  { name: 'I-9 Industrial Area', sector: 'I-9', lat: 33.6592, lng: 73.0562 },
  { name: 'I-10 Markaz', sector: 'I-10', lat: 33.6479, lng: 73.0369 },
  { name: 'I-11 Sabzi Mandi', sector: 'I-11', lat: 33.6391, lng: 73.0182 },
  { name: 'I-12 Sector', sector: 'I-12', lat: 33.6295, lng: 73.0012 },
  { name: 'I-14 Sector (Riphah Vicinity)', sector: 'I-14', lat: 33.612, lng: 72.965 },
  { name: 'E-7 Margalla Greens', sector: 'E-7', lat: 33.7378, lng: 73.0482 },
  { name: 'E-8 Air University & Naval Complex', sector: 'E-8', lat: 33.7291, lng: 73.0315 },
  { name: 'E-9 PAF Complex', sector: 'E-9', lat: 33.7198, lng: 73.0152 },
  { name: 'E-11 MPCHS / Golra Road', sector: 'E-11', lat: 33.7005, lng: 72.9782 },
  { name: 'D-12 Sector Foothills', sector: 'D-12', lat: 33.7121, lng: 72.9615 },
  { name: 'Blue Area (Jinnah Avenue)', sector: 'Blue Area', lat: 33.7136, lng: 73.0652 },
  { name: 'Diplomatic Enclave (G-5)', sector: 'G-5', lat: 33.718, lng: 73.1095 },
  { name: 'F-5 Red Zone', sector: 'F-5', lat: 33.7312, lng: 73.092 },
  { name: 'Bani Gala (Imran Khan Chowk)', sector: 'Bani Gala', lat: 33.7082, lng: 73.1554 },
  { name: 'Chak Shahzad Farms', sector: 'Chak Shahzad', lat: 33.6672, lng: 73.1389 },
  { name: 'Park Road (Tarlai / COMSATS)', sector: 'Park Road', lat: 33.6558, lng: 73.1492 },
  { name: 'Tarlai Kalan', sector: 'Tarlai', lat: 33.6421, lng: 73.1365 },
  { name: 'Shehzad Town', sector: 'Shehzad Town', lat: 33.659, lng: 73.125 },
  { name: 'Rawal Town / Rawal Dam', sector: 'Rawal Town', lat: 33.695, lng: 73.1235 },
  { name: 'Bahria Enclave Islamabad', sector: 'Bahria Enclave', lat: 33.6825, lng: 73.238 },
  { name: 'Park View City Islamabad', sector: 'Park View City', lat: 33.6705, lng: 73.195 },
  { name: 'Gulberg Greens Islamabad', sector: 'Gulberg Greens', lat: 33.5975, lng: 73.138 },
  { name: 'DHA Phase 2 Islamabad', sector: 'DHA 2', lat: 33.528, lng: 73.159 },
  { name: 'Bahria Town Phase 7/8 Expressway', sector: 'Bahria Town', lat: 33.5185, lng: 73.1025 },
  { name: 'Soan Garden', sector: 'Soan Garden', lat: 33.5821, lng: 73.1482 },
  { name: 'PWD Housing Scheme', sector: 'PWD', lat: 33.578, lng: 73.139 },
  { name: 'CBR Town', sector: 'CBR Town', lat: 33.5932, lng: 73.021 },
  { name: 'Police Foundation (O-9)', sector: 'Police Foundation', lat: 33.582, lng: 73.127 },
  { name: 'Faisal Mosque Area', sector: 'Margalla', lat: 33.7296, lng: 73.0373 },
  { name: 'Daman-e-Koh Hilltop', sector: 'Margalla', lat: 33.7485, lng: 73.062 },
  { name: 'Shakarparian National Park', sector: 'Shakarparian', lat: 33.6912, lng: 73.0845 },
  { name: 'B-17 Multi Gardens', sector: 'B-17', lat: 33.683, lng: 72.825 },
  { name: 'Korang Town', sector: 'Korang Town', lat: 33.589, lng: 73.132 },
];

function searchIslamabadLocalities(query = '') {
  const q = String(query).trim().toLowerCase();
  if (!q) return ISLAMABAD_LOCALITIES;
  return ISLAMABAD_LOCALITIES.filter(
    (loc) => loc.name.toLowerCase().includes(q) || loc.sector.toLowerCase().includes(q)
  );
}

module.exports = {
  ISLAMABAD_LOCALITIES,
  searchIslamabadLocalities,
};
