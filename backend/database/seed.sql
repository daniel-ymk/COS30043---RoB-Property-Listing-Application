-- =====================================================================
--  ROB Property - Seed (test) data
--  COS30043 Interface Design and Development - Group 4
--
--  Run AFTER schema.sql, on EMPTY tables (re-import schema.sql with the
--  DROP lines uncommented to start fresh). Select your database first,
--  then Import this file.
--
--  Every test account uses the password:  Password123!
--    Owners : aisha@example.com, jonathan@example.com,
--             priya@example.com, marcus@example.com
--    Viewers: sarah@example.com, hafiz@example.com, emily@example.com
--
--  Viewing days are relative to the day you import (CURDATE()), so they
--  are always in the future. Re-seed before the demo to refresh them.
--
--  Photos: property_images points at 10 shared files in uploads/seed/:
--    apartment.jpg condo.jpg house.jpg townhouse.jpg studio.jpg room.jpg
--    living.jpg bedroom.jpg kitchen.jpg bathroom.jpg
--  Put royalty-free photos with those names in backend/uploads/seed/.
-- =====================================================================


-- ---------------------------------------------------------------------
--  1. users  (4 owners, 3 viewers)
-- ---------------------------------------------------------------------
INSERT INTO users (user_id, full_name, email, password_hash, role, phone) VALUES
(1, 'Aisha Rahman',  'aisha@example.com',    '$2y$10$N4hwuqDfWSBJFLAq/BRIAOQwMl3It8KgLlYvSfFhX/0VZZq42xWt2', 'owner',  '60123456789'),
(2, 'Jonathan Wong', 'jonathan@example.com', '$2y$10$N4hwuqDfWSBJFLAq/BRIAOQwMl3It8KgLlYvSfFhX/0VZZq42xWt2', 'owner',  '60198765432'),
(3, 'Priya Nair',    'priya@example.com',    '$2y$10$N4hwuqDfWSBJFLAq/BRIAOQwMl3It8KgLlYvSfFhX/0VZZq42xWt2', 'owner',  '60167788990'),
(4, 'Marcus Lim',    'marcus@example.com',   '$2y$10$N4hwuqDfWSBJFLAq/BRIAOQwMl3It8KgLlYvSfFhX/0VZZq42xWt2', 'owner',  '6591234567'),
(5, 'Sarah Tan',     'sarah@example.com',    '$2y$10$N4hwuqDfWSBJFLAq/BRIAOQwMl3It8KgLlYvSfFhX/0VZZq42xWt2', 'viewer', NULL),
(6, 'Hafiz Ismail',  'hafiz@example.com',    '$2y$10$N4hwuqDfWSBJFLAq/BRIAOQwMl3It8KgLlYvSfFhX/0VZZq42xWt2', 'viewer', NULL),
(7, 'Emily Chen',    'emily@example.com',    '$2y$10$N4hwuqDfWSBJFLAq/BRIAOQwMl3It8KgLlYvSfFhX/0VZZq42xWt2', 'viewer', NULL);


-- ---------------------------------------------------------------------
--  2. properties  (30 listings, prices in MYR)
--  1-8 Kuala Lumpur (Aisha), 9-16 Kuching (Jonathan),
--  17-23 Penang (Priya), 24-30 Johor (Marcus).
--  4 are not available (7, 21 rented; 14, 28 sold) to test filtering.
-- ---------------------------------------------------------------------
INSERT INTO properties
(property_id, owner_id, title, description, listing_type, property_type, price,
 bedrooms, bathrooms, parking_spaces, floor_area_sqm, is_furnished,
 address, city, state, postcode, latitude, longitude, status, created_at) VALUES
-- Kuala Lumpur
(1, 1, 'Fully furnished 2-bed condo in Mont Kiara',
 'Bright corner unit with pool and gym access, 5 minutes to international schools and Publika.',
 'rent', 'condo', 3800.00, 2, 2, 1, 95.00, 1,
 'Jalan Kiara 3, Mont Kiara', 'Kuala Lumpur', 'Wilayah Persekutuan', '50480', 3.1700000, 101.6500000, 'available', NOW() - INTERVAL 2 DAY),
(2, 1, 'Bangsar townhouse near LRT',
 'Three-storey townhouse on a quiet street, walking distance to Bangsar LRT and Telawi cafes.',
 'rent', 'townhouse', 5200.00, 3, 3, 2, 160.00, 0,
 'Jalan Telawi 5, Bangsar', 'Kuala Lumpur', 'Wilayah Persekutuan', '59100', 3.1290000, 101.6790000, 'available', NOW() - INTERVAL 10 DAY),
(3, 1, 'KLCC view luxury condo',
 'High-floor unit with full Petronas Towers view, concierge, infinity pool and two car parks.',
 'sale', 'condo', 1850000.00, 3, 2, 2, 140.00, 1,
 'Jalan Ampang, KLCC', 'Kuala Lumpur', 'Wilayah Persekutuan', '50450', 3.1579000, 101.7123000, 'available', NOW() - INTERVAL 5 DAY),
(4, 1, 'Affordable family apartment in Cheras',
 'Spacious 3-bedroom apartment near MRT Taman Connaught, markets and schools nearby.',
 'rent', 'apartment', 1500.00, 3, 2, 1, 85.00, 0,
 'Jalan Cheras, Taman Connaught', 'Kuala Lumpur', 'Wilayah Persekutuan', '56000', 3.0850000, 101.7450000, 'available', NOW() - INTERVAL 20 DAY),
(5, 1, 'Studio in the heart of Bukit Bintang',
 'Compact furnished studio above Pavilion area, ideal for young professionals. Utilities included.',
 'rent', 'studio', 2200.00, 0, 1, 0, 42.00, 1,
 'Jalan Bukit Bintang', 'Kuala Lumpur', 'Wilayah Persekutuan', '55100', 3.1466000, 101.7101000, 'available', NOW() - INTERVAL 1 DAY),
(6, 1, 'Room for rent near Sentul LRT',
 'Furnished middle room in a shared condo, Wi-Fi and cleaning included. Female tenants preferred.',
 'rent', 'room', 750.00, 1, 1, 0, 14.00, 1,
 'Jalan Sentul', 'Kuala Lumpur', 'Wilayah Persekutuan', '51000', 3.1830000, 101.6930000, 'available', NOW() - INTERVAL 7 DAY),
(7, 1, 'Desa ParkCity family house',
 'Landed home facing the park with a private garden and maid room. Pet friendly.',
 'rent', 'house', 6500.00, 4, 4, 2, 260.00, 1,
 'Persiaran Prima, Desa ParkCity', 'Kuala Lumpur', 'Wilayah Persekutuan', '52200', 3.1860000, 101.6300000, 'rented', NOW() - INTERVAL 45 DAY),
(8, 1, 'Setapak apartment near TAR UMT',
 'Freehold apartment close to universities, a good starter home or investment unit.',
 'sale', 'apartment', 420000.00, 3, 2, 1, 90.00, 0,
 'Jalan Genting Kelang, Setapak', 'Kuala Lumpur', 'Wilayah Persekutuan', '53300', 3.2050000, 101.7270000, 'available', NOW() - INTERVAL 15 DAY),
-- Kuching
(9, 2, 'Tabuan Jaya terrace house',
 'Double-storey intermediate terrace with renovated kitchen, near Tabuan Jaya food court.',
 'rent', 'house', 1800.00, 4, 3, 2, 180.00, 0,
 'Lorong Tabuan Jaya 2', 'Kuching', 'Sarawak', '93350', 1.5170000, 110.3800000, 'available', NOW() - INTERVAL 3 DAY),
(10, 2, 'BDC condo near Swinburne',
 'Furnished condo with pool, 5 minutes drive to Swinburne Sarawak campus and The Spring mall.',
 'rent', 'condo', 1600.00, 3, 2, 1, 110.00, 1,
 'Jalan Stutong, BDC', 'Kuching', 'Sarawak', '93350', 1.5300000, 110.3650000, 'available', NOW() - INTERVAL 6 DAY),
(11, 2, 'Riverside apartment by the Waterfront',
 'Walk to the Kuching Waterfront and Main Bazaar. River view from the balcony.',
 'sale', 'apartment', 520000.00, 2, 2, 1, 88.00, 1,
 'Jalan Main Bazaar', 'Kuching', 'Sarawak', '93000', 1.5590000, 110.3460000, 'available', NOW() - INTERVAL 12 DAY),
(12, 2, 'Batu Kawa semi-detached house',
 'Corner semi-D with large compound, extended kitchen and covered car porch for two.',
 'sale', 'house', 780000.00, 4, 3, 2, 220.00, 0,
 'Jalan Batu Kawa', 'Kuching', 'Sarawak', '93250', 1.5100000, 110.3100000, 'available', NOW() - INTERVAL 25 DAY),
(13, 2, 'Student room near Swinburne Sarawak',
 'Single room within walking distance of campus. Shared kitchen, Wi-Fi and water included.',
 'rent', 'room', 450.00, 1, 1, 0, 12.00, 1,
 'Jalan Simpang Tiga', 'Kuching', 'Sarawak', '93350', 1.5323000, 110.3571000, 'available', NOW() - INTERVAL 2 DAY),
(14, 2, 'Petra Jaya townhouse',
 'Modern townhouse in a gated community near government offices and Petra Jaya schools.',
 'sale', 'townhouse', 450000.00, 3, 3, 2, 150.00, 0,
 'Jalan Bako, Petra Jaya', 'Kuching', 'Sarawak', '93050', 1.5850000, 110.3400000, 'sold', NOW() - INTERVAL 50 DAY),
(15, 2, 'Kota Samarahan studio near UNIMAS',
 'Furnished studio with one parking bay, popular with students and lecturers.',
 'rent', 'studio', 700.00, 0, 1, 1, 35.00, 1,
 'Jalan Datuk Mohammad Musa', 'Kota Samarahan', 'Sarawak', '94300', 1.4600000, 110.4900000, 'available', NOW() - INTERVAL 9 DAY),
(16, 2, 'Pending apartment, great value',
 'Two-bedroom unit close to Pending industrial area and Kuching city centre.',
 'rent', 'apartment', 950.00, 2, 1, 1, 70.00, 0,
 'Jalan Pending', 'Kuching', 'Sarawak', '93450', 1.5530000, 110.3870000, 'available', NOW() - INTERVAL 30 DAY),
-- Penang
(17, 3, 'Gurney Drive seaview condo',
 'Furnished seaview unit steps from Gurney Plaza and the hawker centre.',
 'rent', 'condo', 4500.00, 3, 2, 2, 130.00, 1,
 'Persiaran Gurney', 'George Town', 'Penang', '10250', 5.4370000, 100.3090000, 'available', NOW() - INTERVAL 4 DAY),
(18, 3, 'Tanjung Tokong apartment',
 'Well-kept unit near Straits Quay marina, schools and supermarkets.',
 'sale', 'apartment', 680000.00, 3, 2, 1, 105.00, 0,
 'Jalan Tanjung Tokong', 'George Town', 'Penang', '10470', 5.4560000, 100.3040000, 'available', NOW() - INTERVAL 14 DAY),
(19, 3, 'Restored heritage shophouse',
 'Pre-war shophouse in the UNESCO heritage zone, fully restored with an air well and courtyard.',
 'sale', 'house', 2800000.00, 4, 3, 0, 280.00, 0,
 'Lebuh Armenian', 'George Town', 'Penang', '10200', 5.4145000, 100.3292000, 'available', NOW() - INTERVAL 18 DAY),
(20, 3, 'Bayan Lepas studio near FTZ',
 'Furnished studio close to the Free Trade Zone and the airport. Ideal for engineers.',
 'rent', 'studio', 1100.00, 0, 1, 1, 38.00, 1,
 'Jalan Sultan Azlan Shah', 'Bayan Lepas', 'Penang', '11900', 5.2970000, 100.2660000, 'available', NOW() - INTERVAL 8 DAY),
(21, 3, 'Jelutong townhouse',
 'Townhouse near the Jelutong Expressway, easy access to the city and the Penang Bridge.',
 'rent', 'townhouse', 2300.00, 3, 2, 2, 140.00, 0,
 'Jalan Jelutong', 'George Town', 'Penang', '11600', 5.3900000, 100.3110000, 'rented', NOW() - INTERVAL 40 DAY),
(22, 3, 'Batu Ferringhi beach condo',
 'Beachfront resort-style condo with private beach access and sunset views.',
 'sale', 'condo', 1250000.00, 3, 3, 2, 165.00, 1,
 'Jalan Batu Ferringhi', 'Batu Ferringhi', 'Penang', '11100', 5.4710000, 100.2460000, 'available', NOW() - INTERVAL 11 DAY),
(23, 3, 'Room in an Air Itam family home',
 'Quiet room with a private bathroom in a landed home, near Kek Lok Si temple.',
 'rent', 'room', 550.00, 1, 1, 0, 13.00, 1,
 'Jalan Air Itam', 'George Town', 'Penang', '11500', 5.4000000, 100.2800000, 'available', NOW() - INTERVAL 22 DAY),
-- Johor
(24, 4, 'Mount Austin double-storey house',
 'Renovated terrace in Mount Austin, surrounded by cafes, AEON Tebrau and international schools.',
 'rent', 'house', 2600.00, 4, 3, 2, 200.00, 0,
 'Jalan Austin Heights', 'Johor Bahru', 'Johor', '81100', 1.5600000, 103.7800000, 'available', NOW() - INTERVAL 1 DAY),
(25, 4, 'Danga Bay waterfront condo',
 'Waterfront unit with a sea view, a short drive to the Singapore causeway.',
 'sale', 'condo', 690000.00, 2, 2, 1, 92.00, 1,
 'Jalan Skudai, Danga Bay', 'Johor Bahru', 'Johor', '80200', 1.4720000, 103.7230000, 'available', NOW() - INTERVAL 16 DAY),
(26, 4, 'Bukit Indah townhouse',
 'Gated townhouse near AEON Bukit Indah and the Second Link expressway.',
 'sale', 'townhouse', 560000.00, 3, 3, 2, 155.00, 0,
 'Jalan Indah 15, Bukit Indah', 'Johor Bahru', 'Johor', '81200', 1.4820000, 103.6550000, 'available', NOW() - INTERVAL 19 DAY),
(27, 4, 'Taman Molek apartment',
 'Furnished apartment in a popular neighbourhood, close to Molek food street.',
 'rent', 'apartment', 1400.00, 3, 2, 1, 95.00, 1,
 'Jalan Molek 2', 'Johor Bahru', 'Johor', '81100', 1.5300000, 103.7900000, 'available', NOW() - INTERVAL 13 DAY),
(28, 4, 'Medini serviced studio',
 'Serviced studio next to LEGOLAND and EduCity, with a rental guarantee programme.',
 'sale', 'studio', 330000.00, 0, 1, 1, 40.00, 1,
 'Persiaran Medini', 'Iskandar Puteri', 'Johor', '79250', 1.4250000, 103.6300000, 'sold', NOW() - INTERVAL 55 DAY),
(29, 4, 'JB city room near CIQ',
 'Basic room a 10-minute walk from the CIQ checkpoint, ideal for Singapore commuters.',
 'rent', 'room', 650.00, 1, 1, 0, 12.00, 0,
 'Jalan Wong Ah Fook', 'Johor Bahru', 'Johor', '80000', 1.4630000, 103.7600000, 'available', NOW() - INTERVAL 6 DAY),
(30, 4, 'Tebrau landed bungalow',
 'Detached bungalow on a large freehold lot with a swimming pool and space for three cars.',
 'sale', 'house', 1600000.00, 5, 5, 3, 350.00, 0,
 'Jalan Tebrau', 'Johor Bahru', 'Johor', '81100', 1.5450000, 103.7950000, 'available', NOW() - INTERVAL 27 DAY);


-- ---------------------------------------------------------------------
--  3. property_images
--  The photo sets from the agreed design (design/js/data.js) for listings
--  1-12 and 17-19; the other listings use the same photos, picked by type.
--  Files: backend/uploads/seed/pNN.jpg (copies of design/img).
--  Captions and room tags feed the media manager; one hidden photo (#1's
--  second bedroom) shows what owners see that the public doesn't.
-- ---------------------------------------------------------------------
INSERT INTO property_images (property_id, file_path, sort_order, caption, room_tag, is_hidden) VALUES
(1, 'uploads/seed/p09.jpg', 0, 'The building', 'exterior', 0),
(1, 'uploads/seed/p17.jpg', 1, 'Living room', 'living', 0),
(1, 'uploads/seed/p08.jpg', 2, 'Kitchen', 'kitchen', 0),
(1, 'uploads/seed/p12.jpg', 3, 'Main bedroom', 'bedroom', 0),
(1, 'uploads/seed/p24.jpg', 4, 'Dining area', 'dining', 0),
(2, 'uploads/seed/p10.jpg', 0, 'The row of townhouses', 'exterior', 0),
(2, 'uploads/seed/p07.jpg', 1, 'Open-plan living room', 'living', 0),
(2, 'uploads/seed/p22.jpg', 2, 'Kitchen with island', 'kitchen', 0),
(2, 'uploads/seed/p23.jpg', 3, 'Bedroom', 'bedroom', 0),
(3, 'uploads/seed/p13.jpg', 0, 'Living room', 'living', 0),
(3, 'uploads/seed/p17.jpg', 1, 'Living room', 'living', 0),
(3, 'uploads/seed/p22.jpg', 2, 'Kitchen with island', 'kitchen', 0),
(3, 'uploads/seed/p12.jpg', 3, 'Main bedroom', 'bedroom', 0),
(4, 'uploads/seed/p07.jpg', 0, 'Open-plan living room', 'living', 0),
(4, 'uploads/seed/p08.jpg', 1, 'Kitchen', 'kitchen', 0),
(4, 'uploads/seed/p23.jpg', 2, 'Bedroom', 'bedroom', 0),
(5, 'uploads/seed/p11.jpg', 0, 'Reading corner', 'living', 0),
(5, 'uploads/seed/p06.jpg', 1, 'Living and dining area', 'living', 0),
(5, 'uploads/seed/p08.jpg', 2, 'Kitchen', 'kitchen', 0),
(6, 'uploads/seed/p23.jpg', 0, 'Bedroom', 'bedroom', 0),
(6, 'uploads/seed/p06.jpg', 1, 'Living and dining area', 'living', 0),
(7, 'uploads/seed/p18.jpg', 0, 'Front of the house', 'exterior', 0),
(7, 'uploads/seed/p17.jpg', 1, 'Living room', 'living', 0),
(7, 'uploads/seed/p22.jpg', 2, 'Kitchen with island', 'kitchen', 0),
(8, 'uploads/seed/p06.jpg', 0, 'Living and dining area', 'living', 0),
(8, 'uploads/seed/p07.jpg', 1, 'Open-plan living room', 'living', 0),
(8, 'uploads/seed/p23.jpg', 2, 'Bedroom', 'bedroom', 0),
(9, 'uploads/seed/p21.jpg', 0, 'Front door and garage', 'exterior', 0),
(9, 'uploads/seed/p22.jpg', 1, 'Kitchen with island', 'kitchen', 0),
(9, 'uploads/seed/p12.jpg', 2, 'Main bedroom', 'bedroom', 0),
(10, 'uploads/seed/p24.jpg', 0, 'Dining area', 'dining', 0),
(10, 'uploads/seed/p13.jpg', 1, 'Living room', 'living', 0),
(10, 'uploads/seed/p23.jpg', 2, 'Bedroom', 'bedroom', 0),
(11, 'uploads/seed/p22.jpg', 0, 'Kitchen with island', 'kitchen', 0),
(11, 'uploads/seed/p17.jpg', 1, 'Living room', 'living', 0),
(11, 'uploads/seed/p12.jpg', 2, 'Main bedroom', 'bedroom', 0),
(12, 'uploads/seed/p14.jpg', 0, 'Pool and garden', 'exterior', 0),
(12, 'uploads/seed/p22.jpg', 1, 'Kitchen with island', 'kitchen', 0),
(12, 'uploads/seed/p23.jpg', 2, 'Bedroom', 'bedroom', 0),
(13, 'uploads/seed/p12.jpg', 0, 'Main bedroom', 'bedroom', 0),
(13, 'uploads/seed/p06.jpg', 1, 'Living and dining area', 'living', 0),
(14, 'uploads/seed/p21.jpg', 0, 'Front door and garage', 'exterior', 0),
(14, 'uploads/seed/p07.jpg', 1, 'Open-plan living room', 'living', 0),
(14, 'uploads/seed/p08.jpg', 2, 'Kitchen', 'kitchen', 0),
(14, 'uploads/seed/p23.jpg', 3, 'Bedroom', 'bedroom', 0),
(15, 'uploads/seed/p17.jpg', 0, 'Living room', 'living', 0),
(15, 'uploads/seed/p08.jpg', 1, 'Kitchen', 'kitchen', 0),
(16, 'uploads/seed/p09.jpg', 0, 'The building', 'exterior', 0),
(16, 'uploads/seed/p06.jpg', 1, 'Living and dining area', 'living', 0),
(16, 'uploads/seed/p22.jpg', 2, 'Kitchen with island', 'kitchen', 0),
(16, 'uploads/seed/p23.jpg', 3, 'Bedroom', 'bedroom', 0),
(17, 'uploads/seed/p20.jpg', 0, 'Pool and garden', 'exterior', 0),
(17, 'uploads/seed/p17.jpg', 1, 'Living room', 'living', 0),
(17, 'uploads/seed/p12.jpg', 2, 'Main bedroom', 'bedroom', 0),
(17, 'uploads/seed/p22.jpg', 3, 'Kitchen with island', 'kitchen', 0),
(18, 'uploads/seed/p02.jpg', 0, 'Pool and terrace', 'exterior', 0),
(18, 'uploads/seed/p07.jpg', 1, 'Open-plan living room', 'living', 0),
(18, 'uploads/seed/p23.jpg', 2, 'Bedroom', 'bedroom', 0),
(19, 'uploads/seed/p24.jpg', 0, 'Dining area', 'dining', 0),
(19, 'uploads/seed/p13.jpg', 1, 'Living room', 'living', 0),
(20, 'uploads/seed/p11.jpg', 0, 'Reading corner', 'living', 0),
(20, 'uploads/seed/p22.jpg', 1, 'Kitchen with island', 'kitchen', 0),
(21, 'uploads/seed/p10.jpg', 0, 'The row of townhouses', 'exterior', 0),
(21, 'uploads/seed/p13.jpg', 1, 'Living room', 'living', 0),
(21, 'uploads/seed/p08.jpg', 2, 'Kitchen', 'kitchen', 0),
(21, 'uploads/seed/p12.jpg', 3, 'Main bedroom', 'bedroom', 0),
(22, 'uploads/seed/p15.jpg', 0, 'Pool and terrace', 'exterior', 0),
(22, 'uploads/seed/p17.jpg', 1, 'Living room', 'living', 0),
(22, 'uploads/seed/p22.jpg', 2, 'Kitchen with island', 'kitchen', 0),
(22, 'uploads/seed/p23.jpg', 3, 'Bedroom', 'bedroom', 0),
(22, 'uploads/seed/p24.jpg', 4, 'Dining area', 'dining', 0),
(23, 'uploads/seed/p23.jpg', 0, 'Bedroom', 'bedroom', 0),
(23, 'uploads/seed/p07.jpg', 1, 'Open-plan living room', 'living', 0),
(24, 'uploads/seed/p03.jpg', 0, 'Front of the house at dusk', 'exterior', 0),
(24, 'uploads/seed/p13.jpg', 1, 'Living room', 'living', 0),
(24, 'uploads/seed/p22.jpg', 2, 'Kitchen with island', 'kitchen', 0),
(24, 'uploads/seed/p12.jpg', 3, 'Main bedroom', 'bedroom', 0),
(25, 'uploads/seed/p14.jpg', 0, 'Pool and garden', 'exterior', 0),
(25, 'uploads/seed/p17.jpg', 1, 'Living room', 'living', 0),
(25, 'uploads/seed/p08.jpg', 2, 'Kitchen', 'kitchen', 0),
(25, 'uploads/seed/p12.jpg', 3, 'Main bedroom', 'bedroom', 0),
(26, 'uploads/seed/p21.jpg', 0, 'Front door and garage', 'exterior', 0),
(26, 'uploads/seed/p06.jpg', 1, 'Living and dining area', 'living', 0),
(26, 'uploads/seed/p22.jpg', 2, 'Kitchen with island', 'kitchen', 0),
(26, 'uploads/seed/p23.jpg', 3, 'Bedroom', 'bedroom', 0),
(27, 'uploads/seed/p09.jpg', 0, 'The building', 'exterior', 0),
(27, 'uploads/seed/p07.jpg', 1, 'Open-plan living room', 'living', 0),
(27, 'uploads/seed/p08.jpg', 2, 'Kitchen', 'kitchen', 0),
(27, 'uploads/seed/p12.jpg', 3, 'Main bedroom', 'bedroom', 0),
(28, 'uploads/seed/p06.jpg', 0, 'Living and dining area', 'living', 0),
(28, 'uploads/seed/p22.jpg', 1, 'Kitchen with island', 'kitchen', 0),
(29, 'uploads/seed/p23.jpg', 0, 'Bedroom', 'bedroom', 0),
(29, 'uploads/seed/p11.jpg', 1, 'Reading corner', 'living', 0),
(30, 'uploads/seed/p04.jpg', 0, 'Front of the house and garden', 'exterior', 0),
(30, 'uploads/seed/p17.jpg', 1, 'Living room', 'living', 0),
(30, 'uploads/seed/p22.jpg', 2, 'Kitchen with island', 'kitchen', 0),
(30, 'uploads/seed/p12.jpg', 3, 'Main bedroom', 'bedroom', 0),
(30, 'uploads/seed/p24.jpg', 4, 'Dining area', 'dining', 0),
(1, 'uploads/seed/p23.jpg', 5, 'Second bedroom (before renovation)', 'bedroom', 1);


-- ---------------------------------------------------------------------
--  4. likes  (uneven counts so "most liked" sorting is visible)
--  Top: #3 (6), #17 (5), #10 (4), #1 and #22 (3).
-- ---------------------------------------------------------------------
INSERT INTO likes (user_id, property_id) VALUES
(5, 3), (6, 3), (7, 3), (2, 3), (3, 3), (4, 3),
(5, 17), (6, 17), (7, 17), (1, 17), (2, 17),
(5, 10), (6, 10), (7, 10), (3, 10),
(5, 1), (6, 1), (7, 1),
(5, 22), (7, 22), (4, 22),
(6, 13), (7, 13),
(5, 25), (6, 25),
(6, 19), (1, 19),
(7, 5), (5, 9), (6, 24), (7, 12), (5, 27), (6, 7);


-- ---------------------------------------------------------------------
--  5. availability_slots  (one per owner per day)
--  Slot 5 is in the past, to test that past days are hidden.
--  is_booked = 1 matches the pending/confirmed appointments below.
-- ---------------------------------------------------------------------
INSERT INTO availability_slots (slot_id, owner_id, viewing_date, viewing_time, is_booked) VALUES
(1,  1, CURDATE() + INTERVAL 2 DAY,  '10:00:00', 1),
(2,  1, CURDATE() + INTERVAL 4 DAY,  '14:00:00', 1),
(3,  1, CURDATE() + INTERVAL 6 DAY,  '11:00:00', 0),
(4,  1, CURDATE() + INTERVAL 9 DAY,  '15:30:00', 0),
(5,  1, CURDATE() - INTERVAL 3 DAY,  '10:00:00', 1),
(6,  2, CURDATE() + INTERVAL 1 DAY,  '09:30:00', 0),
(7,  2, CURDATE() + INTERVAL 3 DAY,  '16:00:00', 1),
(8,  2, CURDATE() + INTERVAL 5 DAY,  '10:00:00', 0),
(9,  2, CURDATE() + INTERVAL 8 DAY,  '14:00:00', 0),
(10, 3, CURDATE() + INTERVAL 2 DAY,  '11:00:00', 0),
(11, 3, CURDATE() + INTERVAL 7 DAY,  '15:00:00', 0),
(12, 3, CURDATE() + INTERVAL 10 DAY, '10:30:00', 0),
(13, 4, CURDATE() + INTERVAL 3 DAY,  '13:00:00', 1),
(14, 4, CURDATE() + INTERVAL 5 DAY,  '10:00:00', 0),
(15, 4, CURDATE() + INTERVAL 12 DAY, '17:00:00', 0);


-- ---------------------------------------------------------------------
--  6. appointments  (one of each status)
--  Declined/cancelled rows keep their slot free (is_booked = 0).
-- ---------------------------------------------------------------------
INSERT INTO appointments (appointment_id, slot_id, property_id, viewer_id, status, message, updated_at) VALUES
(1, 1,  1,  5, 'pending',   'Hi, I would like to view the Mont Kiara unit. Is parking included?', NULL),
(2, 2,  3,  6, 'confirmed', 'Interested in buying. Can I bring my wife along?',                   NOW() - INTERVAL 1 DAY),
(3, 6,  9,  5, 'declined',  'Could I view the house early in the morning?',                       NOW() - INTERVAL 2 DAY),
(4, 7,  10, 7, 'pending',   'I am a Swinburne student looking to move in next month.',            NULL),
(5, 10, 17, 6, 'cancelled', 'Looking forward to seeing the seaview.',                             NOW() - INTERVAL 1 DAY),
(6, 13, 24, 7, 'confirmed', 'Family of four relocating from Singapore.',                          NOW() - INTERVAL 1 DAY),
(7, 5,  2,  7, 'confirmed', 'Viewing for the Bangsar townhouse, thanks!',                         NOW() - INTERVAL 5 DAY);
