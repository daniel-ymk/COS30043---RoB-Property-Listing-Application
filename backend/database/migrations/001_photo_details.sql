-- =====================================================================
--  Migration 001: photo details for the media manager
--  For a database created from an older schema.sql (e.g. the live feenix
--  database). New databases get these columns from schema.sql already.
--
--  Plain ALTER TABLE so it works on older MariaDB / MySQL (feenix does not
--  accept ADD COLUMN IF NOT EXISTS). Run it ONCE: a second run stops with
--  "Duplicate column name 'caption'", which means it is already done.
--  Then run 002_design_photos.sql.
-- =====================================================================

ALTER TABLE property_images
    ADD COLUMN caption   VARCHAR(150) NULL AFTER sort_order,
    ADD COLUMN room_tag  ENUM('exterior', 'living', 'bedroom', 'kitchen', 'bathroom',
                              'dining', 'balcony', 'other') NULL AFTER caption,
    ADD COLUMN is_hidden TINYINT(1) NOT NULL DEFAULT 0 AFTER room_tag;
