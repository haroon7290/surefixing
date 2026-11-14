// Neighbourhoods people pick when they don't share their exact position, and
// the names shown next to distances ("2.3 km · DHA Phase 5"). Coordinates are
// approximate centre points — good to a kilometre or so, which is all a
// "near me" search needs.
const AREAS = [
  // Lahore
  ['Lahore', 'Gulberg', 31.515, 74.344],
  ['Lahore', 'DHA Phase 3', 31.481, 74.392],
  ['Lahore', 'DHA Phase 4', 31.468, 74.383],
  ['Lahore', 'DHA Phase 5', 31.463, 74.408],
  ['Lahore', 'DHA Phase 6', 31.472, 74.45],
  ['Lahore', 'Cantt', 31.515, 74.39],
  ['Lahore', 'Model Town', 31.4835, 74.3255],
  ['Lahore', 'Garden Town', 31.503, 74.322],
  ['Lahore', 'Faisal Town', 31.479, 74.305],
  ['Lahore', 'Johar Town', 31.469, 74.273],
  ['Lahore', 'Township', 31.452, 74.306],
  ['Lahore', 'Wapda Town', 31.433, 74.265],
  ['Lahore', 'Iqbal Town', 31.511, 74.286],
  ['Lahore', 'Samanabad', 31.534, 74.296],
  ['Lahore', 'Shadman', 31.541, 74.332],
  ['Lahore', 'Mall Road', 31.564, 74.314],
  ['Lahore', 'Walled City', 31.58, 74.32],
  ['Lahore', 'Shahdara', 31.624, 74.284],
  ['Lahore', 'Valencia', 31.406, 74.256],
  ['Lahore', 'Bahria Town', 31.37, 74.186],
  // Karachi
  ['Karachi', 'Clifton', 24.8138, 67.03],
  ['Karachi', 'DHA', 24.8, 67.065],
  ['Karachi', 'Saddar', 24.856, 67.028],
  ['Karachi', 'PECHS', 24.87, 67.064],
  ['Karachi', 'Bahadurabad', 24.883, 67.07],
  ['Karachi', 'Gulshan-e-Iqbal', 24.92, 67.096],
  ['Karachi', 'Gulistan-e-Jauhar', 24.907, 67.129],
  ['Karachi', 'Nazimabad', 24.916, 67.031],
  ['Karachi', 'North Nazimabad', 24.942, 67.04],
  ['Karachi', 'Federal B Area', 24.933, 67.078],
  ['Karachi', 'North Karachi', 24.985, 67.06],
  ['Karachi', 'Korangi', 24.831, 67.125],
  ['Karachi', 'Malir', 24.893, 67.2],
  // Islamabad
  ['Islamabad', 'Blue Area', 33.71, 73.06],
  ['Islamabad', 'F-6', 33.729, 73.075],
  ['Islamabad', 'F-7', 33.7215, 73.056],
  ['Islamabad', 'F-8', 33.709, 73.04],
  ['Islamabad', 'F-10', 33.695, 73.013],
  ['Islamabad', 'F-11', 33.683, 72.99],
  ['Islamabad', 'G-9', 33.693, 73.03],
  ['Islamabad', 'G-10', 33.678, 73.015],
  ['Islamabad', 'G-11', 33.668, 72.998],
  ['Islamabad', 'E-11', 33.699, 72.972],
  ['Islamabad', 'I-8', 33.668, 73.072],
  ['Islamabad', 'DHA', 33.53, 73.153],
  // Rawalpindi
  ['Rawalpindi', 'Saddar', 33.596, 73.055],
  ['Rawalpindi', 'Satellite Town', 33.636, 73.064],
  ['Rawalpindi', 'Westridge', 33.605, 73.025],
  ['Rawalpindi', 'Chaklala', 33.588, 73.087],
  ['Rawalpindi', 'Bahria Town', 33.526, 73.096],
  // Faisalabad
  ['Faisalabad', 'D Ground', 31.418, 73.079],
  ['Faisalabad', 'Madina Town', 31.431, 73.113],
  ['Faisalabad', 'Peoples Colony', 31.401, 73.096],
  ['Faisalabad', 'Satiana Road', 31.399, 73.071],
  // Multan
  ['Multan', 'Cantt', 30.196, 71.444],
  ['Multan', 'Gulgasht', 30.214, 71.488],
  ['Multan', 'Bosan Road', 30.228, 71.482],
  // Peshawar
  ['Peshawar', 'Hayatabad', 33.99, 71.45],
  ['Peshawar', 'University Town', 34.005, 71.492],
  ['Peshawar', 'Saddar', 34.0, 71.54],
  // Quetta
  ['Quetta', 'Jinnah Town', 30.201, 66.991],
  ['Quetta', 'Cantt', 30.21, 67.01],
  // Sialkot
  ['Sialkot', 'Cantt', 32.505, 74.54],
  ['Sialkot', 'Model Town', 32.512, 74.526],
  // Gujranwala
  ['Gujranwala', 'Satellite Town', 32.174, 74.18],
  ['Gujranwala', 'Model Town', 32.17, 74.2]
].map(([city, name, lat, lng]) => ({ city, name, lat, lng }));

module.exports = { AREAS };
