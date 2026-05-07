CREATE DATABASE IF NOT EXISTS blackjack_db;
USE blackjack_db;

CREATE TABLE IF NOT EXISTS ranking (
    id INT AUTO_INCREMENT PRIMARY KEY,
    jugador VARCHAR(50) NOT NULL,
    victorias INT DEFAULT 0,
    saldo_fichas INT DEFAULT 0
);
