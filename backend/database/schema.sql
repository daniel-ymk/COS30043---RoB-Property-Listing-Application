-- =====================================================================
--  ROB Property - Database Schema
--  COS30043 Interface Design and Development - Group 4
--
--  Target : MariaDB on Mercury (feenix-mariadb), imported via phpMyAdmin
--  Tables : users, properties, property_images, likes,
--           availability_slots, appointments
--
--  How to import:
--    1. Open phpMyAdmin and select your database (e.g. s1234567_db).
--    2. Open the "Import" tab, choose this file, and click "Import".
--       (Or paste the whole file into the "SQL" tab and click "Go".)
--  Tables are created parents first, so every foreign key resolves.
--
--  Compatibility: feenix runs an older server that allows only ONE
--  auto-timestamp column per table. So `created_at` fills itself, but
--  `updated_at` does not - every UPDATE must set updated_at = NOW().
-- =====================================================================


-- ---------------------------------------------------------------------
--  OPTIONAL RESET - uncomment these lines to delete ALL tables and data
--  and rebuild from scratch. Children are dropped before parents.
-- ---------------------------------------------------------------------
-- DROP TABLE IF EXISTS appointments;
-- DROP TABLE IF EXISTS availability_slots;
-- DROP TABLE IF EXISTS likes;
-- DROP TABLE IF EXISTS property_images;
-- DROP TABLE IF EXISTS properties;
-- DROP TABLE IF EXISTS users;


-- ---------------------------------------------------------------------
--  1. users
--  Owners and viewers share one table; `role` decides what they can do.
--  `phone` is the owner's WhatsApp number in international format,
--  digits only (no +, spaces or dashes), e.g. 60123456789 or 6591234567.
--  It is used to build the link https://wa.me/<phone>.
--  PHP must require a phone number when role = 'owner'.
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id        INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    full_name      VARCHAR(100)  NOT NULL,
    email          VARCHAR(150)  NOT NULL,
    password_hash  VARCHAR(255)  NOT NULL,          -- from PHP password_hash()
    role           ENUM('owner', 'viewer') NOT NULL DEFAULT 'viewer',
    phone          VARCHAR(20)   NULL,              -- WhatsApp number (owners)
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (user_id),
    UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------------------------------------------------------------------
--  2. properties
--  One owner can post many listings (users 1 : N properties).
--  Columns cover search/sort (price, type, city, bedrooms, newest),
--  the map (latitude, longitude) and the comparison page
--  (price, size, bedrooms, bathrooms, parking, furnished, location).
-- ---------------------------------------------------------------------
CREATE TABLE properties (
    property_id     INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    owner_id        INT UNSIGNED      NOT NULL,
    title           VARCHAR(150)      NOT NULL,
    description     TEXT              NOT NULL,
    listing_type    ENUM('rent', 'sale') NOT NULL DEFAULT 'rent',
    property_type   ENUM('apartment', 'condo', 'house', 'townhouse', 'studio', 'room') NOT NULL,
    price           DECIMAL(12,2)     NOT NULL,     -- monthly rent, or sale price
    bedrooms        TINYINT UNSIGNED  NOT NULL DEFAULT 0,
    bathrooms       TINYINT UNSIGNED  NOT NULL DEFAULT 0,
    parking_spaces  TINYINT UNSIGNED  NOT NULL DEFAULT 0,
    floor_area_sqm  DECIMAL(8,2)      NULL,
    is_furnished    TINYINT(1)        NOT NULL DEFAULT 0,
    address         VARCHAR(255)      NOT NULL,
    city            VARCHAR(100)      NOT NULL,
    state           VARCHAR(100)      NULL,
    postcode        VARCHAR(10)       NULL,
    latitude        DECIMAL(10,7)     NULL,         -- set when the address is
    longitude       DECIMAL(10,7)     NULL,         -- converted to coordinates
    status          ENUM('available', 'rented', 'sold') NOT NULL DEFAULT 'available',
    created_at      TIMESTAMP         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP         NULL DEFAULT NULL,  -- PHP sets NOW() on edit

    PRIMARY KEY (property_id),
    KEY idx_properties_owner    (owner_id),
    KEY idx_properties_search   (status, city, property_type),
    KEY idx_properties_price    (price),
    KEY idx_properties_created  (created_at),
    KEY idx_properties_location (latitude, longitude),

    CONSTRAINT fk_properties_owner
        FOREIGN KEY (owner_id) REFERENCES users (user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_properties_price CHECK (price >= 0)  -- ignored by older
                                                        -- servers: PHP validates too
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------------------------------------------------------------------
--  3. property_images
--  Many photos per listing (properties 1 : N property_images).
--  `sort_order` is saved from the drag-to-reorder uploader;
--  the photo with the lowest sort_order is the cover photo.
--  Deleting a row does not delete the file - PHP must unlink() it.
-- ---------------------------------------------------------------------
CREATE TABLE property_images (
    image_id     INT UNSIGNED       NOT NULL AUTO_INCREMENT,
    property_id  INT UNSIGNED       NOT NULL,
    file_path    VARCHAR(255)       NOT NULL,       -- e.g. uploads/12/a3f9c1.jpg
    sort_order   SMALLINT UNSIGNED  NOT NULL DEFAULT 0,
    caption      VARCHAR(150)       NULL,           -- also the photo's alt text
    room_tag     ENUM('exterior', 'living', 'bedroom', 'kitchen', 'bathroom',
                      'dining', 'balcony', 'other') NULL,
    is_hidden    TINYINT(1)         NOT NULL DEFAULT 0, -- owner-only, never the cover
    uploaded_at  TIMESTAMP          NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (image_id),
    KEY idx_images_property_order (property_id, sort_order),

    CONSTRAINT fk_images_property
        FOREIGN KEY (property_id) REFERENCES properties (property_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------------------------------------------------------------------
--  4. likes  (social interaction requirement)
--  Junction table for the many-to-many link between users and
--  properties. The composite primary key allows one like per user
--  per property; "unlike" = DELETE the row.
-- ---------------------------------------------------------------------
CREATE TABLE likes (
    user_id      INT UNSIGNED  NOT NULL,
    property_id  INT UNSIGNED  NOT NULL,
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (user_id, property_id),
    KEY idx_likes_property (property_id),

    CONSTRAINT fk_likes_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_likes_property
        FOREIGN KEY (property_id) REFERENCES properties (property_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------------------------------------------------------------------
--  5. availability_slots  (booking calendar)
--  ONE VIEWING PER DAY: each row is a day the OWNER is free for a
--  viewing, with the time the viewing will happen that day
--  (users 1 : N slots).
--  UNIQUE (owner_id, viewing_date) lets an owner publish at most one
--  slot per day, so they can never have two viewings on the same day,
--  even across several listings.
--  `is_booked` = 1 while a pending or confirmed appointment holds it.
-- ---------------------------------------------------------------------
CREATE TABLE availability_slots (
    slot_id       INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    owner_id      INT UNSIGNED  NOT NULL,
    viewing_date  DATE          NOT NULL,           -- e.g. 2026-11-15
    viewing_time  TIME          NOT NULL,           -- e.g. 14:00:00, set by owner
    is_booked     TINYINT(1)    NOT NULL DEFAULT 0,
    created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (slot_id),
    UNIQUE KEY uq_slots_owner_day (owner_id, viewing_date),  -- 1 viewing per day

    CONSTRAINT fk_slots_owner
        FOREIGN KEY (owner_id) REFERENCES users (user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------------------------------------------------------------------
--  6. appointments  (booking calendar)
--  A viewer books one of the owner's free days to view one property,
--  with a message explaining the request. The owner then approves or
--  rejects it. Workflow: pending -> confirmed | declined | cancelled.
--  Declined/cancelled rows are kept as history and the slot is freed.
-- ---------------------------------------------------------------------
CREATE TABLE appointments (
    appointment_id  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    slot_id         INT UNSIGNED  NOT NULL,
    property_id     INT UNSIGNED  NOT NULL,
    viewer_id       INT UNSIGNED  NOT NULL,
    status          ENUM('pending', 'confirmed', 'declined', 'cancelled')
                    NOT NULL DEFAULT 'pending',
    message         VARCHAR(500)  NULL,             -- optional note from viewer
    created_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP     NULL DEFAULT NULL,  -- PHP sets NOW() on change

    PRIMARY KEY (appointment_id),
    KEY idx_appointments_slot     (slot_id),
    KEY idx_appointments_property (property_id),
    KEY idx_appointments_viewer   (viewer_id),

    CONSTRAINT fk_appointments_slot
        FOREIGN KEY (slot_id) REFERENCES availability_slots (slot_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_appointments_property
        FOREIGN KEY (property_id) REFERENCES properties (property_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_appointments_viewer
        FOREIGN KEY (viewer_id) REFERENCES users (user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================================
--  KEY QUERIES FOR THE PHP API (reference only - not run on import)
-- =====================================================================
--
--  Listing cards: cover photo + like count, with search, sort, pagination
--  -----------------------------------------------------------------------
--  SELECT p.*,
--         (SELECT file_path FROM property_images i
--           WHERE i.property_id = p.property_id
--           ORDER BY i.sort_order LIMIT 1)                 AS cover_image,
--         (SELECT COUNT(*) FROM likes l
--           WHERE l.property_id = p.property_id)           AS like_count
--  FROM properties p
--  WHERE p.status = 'available'
--    AND p.city = ? AND p.price BETWEEN ? AND ?
--  ORDER BY p.price ASC          -- or p.created_at DESC, like_count DESC
--  LIMIT ? OFFSET ?;
--
--  Map "search this area" (visible map bounds)
--  -----------------------------------------------------------------------
--  SELECT property_id, title, price, latitude, longitude
--  FROM properties
--  WHERE status = 'available'
--    AND latitude  BETWEEN ? AND ?     -- south, north
--    AND longitude BETWEEN ? AND ?;    -- west, east
--
--  Run once after connecting (db.php), so NOW() matches your users' clock
--  -----------------------------------------------------------------------
--  SET time_zone = '+08:00';
--
--  Free viewing days shown on a listing's detail page
--  -----------------------------------------------------------------------
--  SELECT s.slot_id, s.viewing_date, s.viewing_time
--  FROM availability_slots s
--  JOIN properties p ON p.owner_id = s.owner_id
--  WHERE p.property_id = ?
--    AND p.status = 'available'
--    AND s.is_booked = 0
--    AND TIMESTAMP(s.viewing_date, s.viewing_time) > NOW()
--  ORDER BY s.viewing_date;
--
--  Booking a day WITHOUT double-booking (run inside a transaction)
--  -----------------------------------------------------------------------
--  1) UPDATE availability_slots SET is_booked = 1
--     WHERE slot_id = ? AND is_booked = 0;
--     -> if rowCount() = 0, someone else booked it first: return 409.
--  2) INSERT INTO appointments (slot_id, property_id, viewer_id, message)
--     SELECT s.slot_id, p.property_id, :viewer_id, :message
--     FROM availability_slots s
--     JOIN properties p ON p.owner_id = s.owner_id
--     WHERE s.slot_id = :slot_id AND p.property_id = :property_id
--       AND p.owner_id <> :viewer_id          -- can't book your own listing
--       AND p.status = 'available'
--       AND TIMESTAMP(s.viewing_date, s.viewing_time) > NOW();
--     -> if rowCount() = 0, roll back the transaction: invalid request.
--
--  Owner's pending requests (notification badge + approval pop-up)
--  -----------------------------------------------------------------------
--  SELECT a.appointment_id, u.full_name AS viewer, p.title,
--         s.viewing_date, s.viewing_time, a.message
--  FROM appointments a
--  JOIN availability_slots s ON s.slot_id = a.slot_id
--  JOIN properties p         ON p.property_id = a.property_id
--  JOIN users u              ON u.user_id = a.viewer_id
--  WHERE s.owner_id = ? AND a.status = 'pending'
--  ORDER BY a.created_at, a.appointment_id;
--
--  Owner approves (only their own, only while pending)
--  -----------------------------------------------------------------------
--  UPDATE appointments a JOIN availability_slots s ON s.slot_id = a.slot_id
--  SET a.status = 'confirmed', a.updated_at = NOW()
--  WHERE a.appointment_id = ? AND s.owner_id = ? AND a.status = 'pending';
--
--  Owner rejects: status + free the day in ONE statement
--  -----------------------------------------------------------------------
--  UPDATE appointments a JOIN availability_slots s ON s.slot_id = a.slot_id
--  SET a.status = 'declined', a.updated_at = NOW(), s.is_booked = 0
--  WHERE a.appointment_id = ? AND s.owner_id = ? AND a.status = 'pending';
--
--  Viewer cancels: status + free the day in ONE statement
--  -----------------------------------------------------------------------
--  UPDATE appointments a JOIN availability_slots s ON s.slot_id = a.slot_id
--  SET a.status = 'cancelled', a.updated_at = NOW(), s.is_booked = 0
--  WHERE a.appointment_id = ? AND a.viewer_id = ?
--    AND a.status IN ('pending', 'confirmed');
--
--  Owner marks a listing rented/sold: close all its open requests
--  -----------------------------------------------------------------------
--  UPDATE properties SET status = 'rented', updated_at = NOW()
--  WHERE property_id = ? AND owner_id = ?;
--  UPDATE appointments a JOIN availability_slots s ON s.slot_id = a.slot_id
--  SET a.status = IF(a.status = 'pending', 'declined', 'cancelled'),
--      a.updated_at = NOW(), s.is_booked = 0
--  WHERE a.property_id = ? AND s.owner_id = ?
--    AND a.status IN ('pending', 'confirmed');
--
--  PHP must refuse to edit or delete a day while is_booked = 1.
--
--  Before deleting a listing, free any slots its active bookings hold
--  -----------------------------------------------------------------------
--  UPDATE availability_slots s
--  JOIN appointments a ON a.slot_id = s.slot_id
--  SET s.is_booked = 0
--  WHERE a.property_id = ? AND a.status IN ('pending', 'confirmed');
--  DELETE FROM properties WHERE property_id = ? AND owner_id = ?;
--
--  WhatsApp button on the detail page (built in Vue, not stored)
--  -----------------------------------------------------------------------
--  https://wa.me/<owner phone>?text=<URL-encoded message about the listing>
-- =====================================================================
