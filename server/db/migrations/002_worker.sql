-- F4.2 — de kloktijd per actie (F4.0b): zonder now_ms in de rij is een
-- partij met klokken niet hash-getrouw na te spelen. NULL = klokloos.
ALTER TABLE match_events ADD COLUMN now_ms BIGINT NULL;
