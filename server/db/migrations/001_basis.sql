-- F4.1 — basisschema (bouwplan §5.1). Campagnetabellen mogen alvast mee en
-- blijven leeg tot F5; arena-tabellen bewust NIET (B10: arena-uitvoer is
-- reproduceerbaar uit config+seed en hoort niet in de spel-database).

CREATE TABLE users (
  id            CHAR(36)     NOT NULL PRIMARY KEY,
  device_token  CHAR(36)     NOT NULL,               -- gast-eerst: het apparaat IS het account
  naam          VARCHAR(20)  NOT NULL,
  email         VARCHAR(255) NULL,                   -- pas gevuld na upgrade (cross-device)
  wachtwoord    VARCHAR(255) NULL,                   -- scrypt: salt$hash (alleen na upgrade)
  avatar_doctrine TINYINT    NOT NULL DEFAULT 0,     -- doctrine-embleem (0..5)
  avatar_kleur  VARCHAR(7)   NOT NULL DEFAULT '#c0392b',
  vriendcode    CHAR(8)      NOT NULL,               -- 31-alfabet, deelbaar
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_device (device_token),
  UNIQUE KEY uq_email (email),
  UNIQUE KEY uq_vriendcode (vriendcode)
);

CREATE TABLE sessies (
  token       CHAR(64)  NOT NULL PRIMARY KEY,
  user_id     CHAR(36)  NOT NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_user (user_id),
  CONSTRAINT fk_sessie_user FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE TABLE vrienden (
  user_id    CHAR(36)  NOT NULL,
  vriend_id  CHAR(36)  NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, vriend_id),
  CONSTRAINT fk_vriend_a FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT fk_vriend_b FOREIGN KEY (vriend_id) REFERENCES users (id)
);

CREATE TABLE matches (
  id            CHAR(36)    NOT NULL PRIMARY KEY,
  status        ENUM('lobby','bezig','klaar') NOT NULL DEFAULT 'lobby',
  rules_version VARCHAR(16) NOT NULL,
  rules_config  JSON        NOT NULL,      -- de volledige RulesConfig-dict van de match
  winnaar_seat  TINYINT     NULL,
  eind_reden    VARCHAR(32) NULL,
  created_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE match_seats (
  match_id  CHAR(36) NOT NULL,
  seat      TINYINT  NOT NULL,             -- 1 of 2 (= engine player_id)
  user_id   CHAR(36) NOT NULL,
  PRIMARY KEY (match_id, seat),
  KEY ix_seat_user (user_id),
  CONSTRAINT fk_seat_match FOREIGN KEY (match_id) REFERENCES matches (id),
  CONSTRAINT fk_seat_user FOREIGN KEY (user_id) REFERENCES users (id)
);

-- Het hart van het protocol (bouwplan §10): een append-only event-log per
-- match met een dicht seq-nummer. idem_key maakt POST /acties idempotent;
-- de unieke index is de daadwerkelijke bewaker (geen check-then-act-race).
CREATE TABLE match_events (
  match_id    CHAR(36)    NOT NULL,
  seq         INT         NOT NULL,
  player_seat TINYINT     NOT NULL,        -- 0 = systeem/server
  type        VARCHAR(32) NOT NULL,
  payload     JSON        NOT NULL,
  idem_key    CHAR(36)    NULL,
  created_at  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (match_id, seq),
  UNIQUE KEY uq_idem (match_id, idem_key),
  CONSTRAINT fk_event_match FOREIGN KEY (match_id) REFERENCES matches (id)
);

-- Snapshot elke N events (F4.2-worker schrijft; laden = snapshot + staart).
CREATE TABLE snapshots (
  match_id  CHAR(36) NOT NULL,
  seq       INT      NOT NULL,
  staat     JSON     NOT NULL,             -- Serializer.state_to_dict
  PRIMARY KEY (match_id, seq),
  CONSTRAINT fk_snapshot_match FOREIGN KEY (match_id) REFERENCES matches (id)
);

-- Leeg tot F6 (Glicko-2 per queue).
CREATE TABLE ratings (
  user_id  CHAR(36)    NOT NULL,
  queue    VARCHAR(16) NOT NULL,
  rating   DOUBLE      NOT NULL DEFAULT 1500,
  rd       DOUBLE      NOT NULL DEFAULT 350,
  vol      DOUBLE      NOT NULL DEFAULT 0.06,
  PRIMARY KEY (user_id, queue),
  CONSTRAINT fk_rating_user FOREIGN KEY (user_id) REFERENCES users (id)
);

-- Leeg tot F5 (online campagne): zelfde append-only vorm als match_events.
CREATE TABLE campaign_events (
  campaign_id CHAR(36) NOT NULL,
  seq         INT      NOT NULL,
  payload     JSON     NOT NULL,
  created_at  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (campaign_id, seq)
);
