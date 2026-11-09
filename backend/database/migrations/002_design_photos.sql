-- =====================================================================
--  Migration 002: the design's listing photos
--  Replaces the seed listings' placeholder photos (one per property type)
--  with the photos from the agreed design. Run AFTER 001_photo_details.sql.
--  Photos owners uploaded themselves (uploads/<id>/...) are not touched.
--  Needs the new files in backend/uploads/seed/ (pNN.jpg) on the server.
--
--  Uses only INSERT and DELETE (feenix accounts can't create temporary
--  tables). Safe order: the design photos are added before the old
--  placeholders are removed, so a failure part-way never leaves a listing
--  without photos. Safe to run again.
-- =====================================================================

-- 1. Clear design photos from an earlier run (none the first time)
DELETE FROM property_images WHERE file_path LIKE 'uploads/seed/p__.jpg';

-- 2. Add the design photos, only for seed listings that still exist
INSERT INTO property_images (property_id, file_path, sort_order, caption, room_tag, is_hidden)
SELECT d.property_id, d.file_path, d.sort_order, d.caption, d.room_tag, d.is_hidden
FROM (
    SELECT 1 AS property_id, 'uploads/seed/p09.jpg' AS file_path, 0 AS sort_order, 'The building' AS caption, 'exterior' AS room_tag, 0 AS is_hidden
    UNION ALL SELECT 1, 'uploads/seed/p17.jpg', 1, 'Living room', 'living', 0
    UNION ALL SELECT 1, 'uploads/seed/p08.jpg', 2, 'Kitchen', 'kitchen', 0
    UNION ALL SELECT 1, 'uploads/seed/p12.jpg', 3, 'Main bedroom', 'bedroom', 0
    UNION ALL SELECT 1, 'uploads/seed/p24.jpg', 4, 'Dining area', 'dining', 0
    UNION ALL SELECT 2, 'uploads/seed/p10.jpg', 0, 'The row of townhouses', 'exterior', 0
    UNION ALL SELECT 2, 'uploads/seed/p07.jpg', 1, 'Open-plan living room', 'living', 0
    UNION ALL SELECT 2, 'uploads/seed/p22.jpg', 2, 'Kitchen with island', 'kitchen', 0
    UNION ALL SELECT 2, 'uploads/seed/p23.jpg', 3, 'Bedroom', 'bedroom', 0
    UNION ALL SELECT 3, 'uploads/seed/p13.jpg', 0, 'Living room', 'living', 0
    UNION ALL SELECT 3, 'uploads/seed/p17.jpg', 1, 'Living room', 'living', 0
    UNION ALL SELECT 3, 'uploads/seed/p22.jpg', 2, 'Kitchen with island', 'kitchen', 0
    UNION ALL SELECT 3, 'uploads/seed/p12.jpg', 3, 'Main bedroom', 'bedroom', 0
    UNION ALL SELECT 4, 'uploads/seed/p07.jpg', 0, 'Open-plan living room', 'living', 0
    UNION ALL SELECT 4, 'uploads/seed/p08.jpg', 1, 'Kitchen', 'kitchen', 0
    UNION ALL SELECT 4, 'uploads/seed/p23.jpg', 2, 'Bedroom', 'bedroom', 0
    UNION ALL SELECT 5, 'uploads/seed/p11.jpg', 0, 'Reading corner', 'living', 0
    UNION ALL SELECT 5, 'uploads/seed/p06.jpg', 1, 'Living and dining area', 'living', 0
    UNION ALL SELECT 5, 'uploads/seed/p08.jpg', 2, 'Kitchen', 'kitchen', 0
    UNION ALL SELECT 6, 'uploads/seed/p23.jpg', 0, 'Bedroom', 'bedroom', 0
    UNION ALL SELECT 6, 'uploads/seed/p06.jpg', 1, 'Living and dining area', 'living', 0
    UNION ALL SELECT 7, 'uploads/seed/p18.jpg', 0, 'Front of the house', 'exterior', 0
    UNION ALL SELECT 7, 'uploads/seed/p17.jpg', 1, 'Living room', 'living', 0
    UNION ALL SELECT 7, 'uploads/seed/p22.jpg', 2, 'Kitchen with island', 'kitchen', 0
    UNION ALL SELECT 8, 'uploads/seed/p06.jpg', 0, 'Living and dining area', 'living', 0
    UNION ALL SELECT 8, 'uploads/seed/p07.jpg', 1, 'Open-plan living room', 'living', 0
    UNION ALL SELECT 8, 'uploads/seed/p23.jpg', 2, 'Bedroom', 'bedroom', 0
    UNION ALL SELECT 9, 'uploads/seed/p21.jpg', 0, 'Front door and garage', 'exterior', 0
    UNION ALL SELECT 9, 'uploads/seed/p22.jpg', 1, 'Kitchen with island', 'kitchen', 0
    UNION ALL SELECT 9, 'uploads/seed/p12.jpg', 2, 'Main bedroom', 'bedroom', 0
    UNION ALL SELECT 10, 'uploads/seed/p24.jpg', 0, 'Dining area', 'dining', 0
    UNION ALL SELECT 10, 'uploads/seed/p13.jpg', 1, 'Living room', 'living', 0
    UNION ALL SELECT 10, 'uploads/seed/p23.jpg', 2, 'Bedroom', 'bedroom', 0
    UNION ALL SELECT 11, 'uploads/seed/p22.jpg', 0, 'Kitchen with island', 'kitchen', 0
    UNION ALL SELECT 11, 'uploads/seed/p17.jpg', 1, 'Living room', 'living', 0
    UNION ALL SELECT 11, 'uploads/seed/p12.jpg', 2, 'Main bedroom', 'bedroom', 0
    UNION ALL SELECT 12, 'uploads/seed/p14.jpg', 0, 'Pool and garden', 'exterior', 0
    UNION ALL SELECT 12, 'uploads/seed/p22.jpg', 1, 'Kitchen with island', 'kitchen', 0
    UNION ALL SELECT 12, 'uploads/seed/p23.jpg', 2, 'Bedroom', 'bedroom', 0
    UNION ALL SELECT 13, 'uploads/seed/p12.jpg', 0, 'Main bedroom', 'bedroom', 0
    UNION ALL SELECT 13, 'uploads/seed/p06.jpg', 1, 'Living and dining area', 'living', 0
    UNION ALL SELECT 14, 'uploads/seed/p21.jpg', 0, 'Front door and garage', 'exterior', 0
    UNION ALL SELECT 14, 'uploads/seed/p07.jpg', 1, 'Open-plan living room', 'living', 0
    UNION ALL SELECT 14, 'uploads/seed/p08.jpg', 2, 'Kitchen', 'kitchen', 0
    UNION ALL SELECT 14, 'uploads/seed/p23.jpg', 3, 'Bedroom', 'bedroom', 0
    UNION ALL SELECT 15, 'uploads/seed/p17.jpg', 0, 'Living room', 'living', 0
    UNION ALL SELECT 15, 'uploads/seed/p08.jpg', 1, 'Kitchen', 'kitchen', 0
    UNION ALL SELECT 16, 'uploads/seed/p09.jpg', 0, 'The building', 'exterior', 0
    UNION ALL SELECT 16, 'uploads/seed/p06.jpg', 1, 'Living and dining area', 'living', 0
    UNION ALL SELECT 16, 'uploads/seed/p22.jpg', 2, 'Kitchen with island', 'kitchen', 0
    UNION ALL SELECT 16, 'uploads/seed/p23.jpg', 3, 'Bedroom', 'bedroom', 0
    UNION ALL SELECT 17, 'uploads/seed/p20.jpg', 0, 'Pool and garden', 'exterior', 0
    UNION ALL SELECT 17, 'uploads/seed/p17.jpg', 1, 'Living room', 'living', 0
    UNION ALL SELECT 17, 'uploads/seed/p12.jpg', 2, 'Main bedroom', 'bedroom', 0
    UNION ALL SELECT 17, 'uploads/seed/p22.jpg', 3, 'Kitchen with island', 'kitchen', 0
    UNION ALL SELECT 18, 'uploads/seed/p02.jpg', 0, 'Pool and terrace', 'exterior', 0
    UNION ALL SELECT 18, 'uploads/seed/p07.jpg', 1, 'Open-plan living room', 'living', 0
    UNION ALL SELECT 18, 'uploads/seed/p23.jpg', 2, 'Bedroom', 'bedroom', 0
    UNION ALL SELECT 19, 'uploads/seed/p24.jpg', 0, 'Dining area', 'dining', 0
    UNION ALL SELECT 19, 'uploads/seed/p13.jpg', 1, 'Living room', 'living', 0
    UNION ALL SELECT 20, 'uploads/seed/p11.jpg', 0, 'Reading corner', 'living', 0
    UNION ALL SELECT 20, 'uploads/seed/p22.jpg', 1, 'Kitchen with island', 'kitchen', 0
    UNION ALL SELECT 21, 'uploads/seed/p10.jpg', 0, 'The row of townhouses', 'exterior', 0
    UNION ALL SELECT 21, 'uploads/seed/p13.jpg', 1, 'Living room', 'living', 0
    UNION ALL SELECT 21, 'uploads/seed/p08.jpg', 2, 'Kitchen', 'kitchen', 0
    UNION ALL SELECT 21, 'uploads/seed/p12.jpg', 3, 'Main bedroom', 'bedroom', 0
    UNION ALL SELECT 22, 'uploads/seed/p15.jpg', 0, 'Pool and terrace', 'exterior', 0
    UNION ALL SELECT 22, 'uploads/seed/p17.jpg', 1, 'Living room', 'living', 0
    UNION ALL SELECT 22, 'uploads/seed/p22.jpg', 2, 'Kitchen with island', 'kitchen', 0
    UNION ALL SELECT 22, 'uploads/seed/p23.jpg', 3, 'Bedroom', 'bedroom', 0
    UNION ALL SELECT 22, 'uploads/seed/p24.jpg', 4, 'Dining area', 'dining', 0
    UNION ALL SELECT 23, 'uploads/seed/p23.jpg', 0, 'Bedroom', 'bedroom', 0
    UNION ALL SELECT 23, 'uploads/seed/p07.jpg', 1, 'Open-plan living room', 'living', 0
    UNION ALL SELECT 24, 'uploads/seed/p03.jpg', 0, 'Front of the house at dusk', 'exterior', 0
    UNION ALL SELECT 24, 'uploads/seed/p13.jpg', 1, 'Living room', 'living', 0
    UNION ALL SELECT 24, 'uploads/seed/p22.jpg', 2, 'Kitchen with island', 'kitchen', 0
    UNION ALL SELECT 24, 'uploads/seed/p12.jpg', 3, 'Main bedroom', 'bedroom', 0
    UNION ALL SELECT 25, 'uploads/seed/p14.jpg', 0, 'Pool and garden', 'exterior', 0
    UNION ALL SELECT 25, 'uploads/seed/p17.jpg', 1, 'Living room', 'living', 0
    UNION ALL SELECT 25, 'uploads/seed/p08.jpg', 2, 'Kitchen', 'kitchen', 0
    UNION ALL SELECT 25, 'uploads/seed/p12.jpg', 3, 'Main bedroom', 'bedroom', 0
    UNION ALL SELECT 26, 'uploads/seed/p21.jpg', 0, 'Front door and garage', 'exterior', 0
    UNION ALL SELECT 26, 'uploads/seed/p06.jpg', 1, 'Living and dining area', 'living', 0
    UNION ALL SELECT 26, 'uploads/seed/p22.jpg', 2, 'Kitchen with island', 'kitchen', 0
    UNION ALL SELECT 26, 'uploads/seed/p23.jpg', 3, 'Bedroom', 'bedroom', 0
    UNION ALL SELECT 27, 'uploads/seed/p09.jpg', 0, 'The building', 'exterior', 0
    UNION ALL SELECT 27, 'uploads/seed/p07.jpg', 1, 'Open-plan living room', 'living', 0
    UNION ALL SELECT 27, 'uploads/seed/p08.jpg', 2, 'Kitchen', 'kitchen', 0
    UNION ALL SELECT 27, 'uploads/seed/p12.jpg', 3, 'Main bedroom', 'bedroom', 0
    UNION ALL SELECT 28, 'uploads/seed/p06.jpg', 0, 'Living and dining area', 'living', 0
    UNION ALL SELECT 28, 'uploads/seed/p22.jpg', 1, 'Kitchen with island', 'kitchen', 0
    UNION ALL SELECT 29, 'uploads/seed/p23.jpg', 0, 'Bedroom', 'bedroom', 0
    UNION ALL SELECT 29, 'uploads/seed/p11.jpg', 1, 'Reading corner', 'living', 0
    UNION ALL SELECT 30, 'uploads/seed/p04.jpg', 0, 'Front of the house and garden', 'exterior', 0
    UNION ALL SELECT 30, 'uploads/seed/p17.jpg', 1, 'Living room', 'living', 0
    UNION ALL SELECT 30, 'uploads/seed/p22.jpg', 2, 'Kitchen with island', 'kitchen', 0
    UNION ALL SELECT 30, 'uploads/seed/p12.jpg', 3, 'Main bedroom', 'bedroom', 0
    UNION ALL SELECT 30, 'uploads/seed/p24.jpg', 4, 'Dining area', 'dining', 0
    UNION ALL SELECT 1, 'uploads/seed/p23.jpg', 5, 'Second bedroom (before renovation)', 'bedroom', 1
) d
JOIN properties p ON p.property_id = d.property_id;

-- 3. Remove the old placeholder photos (condo.jpg, living.jpg, ...)
DELETE FROM property_images
WHERE file_path LIKE 'uploads/seed/%' AND file_path NOT LIKE 'uploads/seed/p__.jpg';
