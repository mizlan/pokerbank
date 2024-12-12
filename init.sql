/*
 * Sqlite3 configuration for pokerbank
 */

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS players;
DROP TABLE IF EXISTS bank;
DROP TABLE IF EXISTS transactions;

BEGIN TRANSACTION;

/*
 * Each session has a unique session_id, a session name, and a create_time.
 */
CREATE TABLE sessions (
	session_id INTEGER PRIMARY KEY,
	session_name TEXT NOT NULL,
	create_time TEXT DEFAULT CURRENT_TIMESTAMP
) STRICT;

/*
 * Each player has a unique player_id, a unique username, and a winnings amount.
 */
CREATE TABLE players (
	player_id INTEGER PRIMARY KEY,
	username TEXT UNIQUE NOT NULL,
	winnings INTEGER NOT NULL DEFAULT 0
) STRICT;

/*
 * Each bank has a session_id and a player_id.
 */
CREATE TABLE bank (
	session_id INTEGER UNIQUE,
	player_id INTEGER,

	FOREIGN KEY (session_id) REFERENCES sessions(session_id),
	FOREIGN KEY (player_id) REFERENCES players(player_id)
) STRICT;

/*
 * Amount is positive for deposits and negative for withdrawals.
 */
CREATE TABLE transactions (
	transaction_id INTEGER PRIMARY KEY,
	session_id INTEGER,
	player_id INTEGER,
	bank_id INTEGER,
	amount INTEGER NOT NULL,
	time TEXT DEFAULT CURRENT_TIMESTAMP,

	FOREIGN KEY (session_id) REFERENCES sessions(session_id),
	FOREIGN KEY (player_id) REFERENCES players(player_id),
	FOREIGN KEY (bank_id) REFERENCES bank(player_id)
) STRICT;

COMMIT;
