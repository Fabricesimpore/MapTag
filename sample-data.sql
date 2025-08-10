-- Sample addresses for testing
INSERT INTO addresses (code, latitude, longitude, place_name, category, verification_status, confidence_score) VALUES
('BF-OUA-1234-TEST', 12.3714, -1.5197, 'Maison Test Ouagadougou', 'Résidence', 'verified', 95),
('BF-BOB-5678-DEMO', 11.1784, -4.2953, 'Commerce Test Bobo', 'Commerce', 'verified', 90),
('BF-OUA-9999-SAMP', 12.3800, -1.5100, 'École Test', 'École', 'pending', 0);

INSERT INTO verification_queue (address_id, verification_type, status) 
SELECT id, 'photo_match', 'pending' FROM addresses WHERE verification_status = 'pending';