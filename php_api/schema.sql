-- Schema for Kolkata Tour AI (MySQL)
CREATE DATABASE IF NOT EXISTS kolkata_ai CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE kolkata_ai;

CREATE TABLE IF NOT EXISTS places (
  id VARCHAR(64) PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  subcategory TEXT,
  description TEXT,
  history TEXT,
  nearby_recommendations JSON,
  personal_tips TEXT,
  lat DECIMAL(9,6) NOT NULL DEFAULT 0,
  lng DECIMAL(9,6) NOT NULL DEFAULT 0,
  opening_hours JSON,
  price TEXT,
  best_time TEXT,
  past_events TEXT,
  sentiment_tags JSON,
  source_url TEXT,
  image TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS place_images (
  id INT AUTO_INCREMENT PRIMARY KEY,
  place_id VARCHAR(64) NOT NULL,
  url TEXT NOT NULL,
  sort_order INT DEFAULT 0,
  CONSTRAINT fk_place FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE INDEX IF NOT EXISTS idx_places_category ON places (category(191));
CREATE INDEX IF NOT EXISTS idx_places_subcategory ON places (subcategory(191));
CREATE INDEX IF NOT EXISTS idx_places_name ON places (name(191));

-- Optional: enable better keyword search (requires InnoDB + MySQL 5.6+)
-- You can run this separately if your MySQL supports FULLTEXT on these columns
-- CREATE FULLTEXT INDEX ft_places_name_desc ON places (name, description);
