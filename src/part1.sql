------------------------------------------------------------------------------------------------------
--                                                                                                  --
--                                                                                                  --
--                                         CREATE DATABASE                                          --
--                                                                                                  --
--                                                                                                  --
------------------------------------------------------------------------------------------------------


CREATE TABLE Peers(
	Nickname VARCHAR PRIMARY KEY,
	Birthday DATE NOT NULL
);

CREATE TABLE Tasks(
	Title VARCHAR PRIMARY KEY,
	ParentTask VARCHAR, 
	MaxXP INTEGER NOT NULL
);

CREATE TYPE Review_status AS ENUM ('0', '1', '2');
-- '0' - Start — начало проверки;
-- '1' - Success — успешное окончание проверки;
-- '2' - Failure — неудачное окончание проверки.

CREATE TABLE Checks(
	ID BIGINT PRIMARY KEY,
	Peer VARCHAR NOT NULL,
	Task VARCHAR NOT NULL,
	Date DATE NOT NULL,
	CONSTRAINT fk_checks_task FOREIGN KEY (Task) REFERENCES Tasks(Title),
	CONSTRAINT fk_checks_peer FOREIGN KEY (Peer) REFERENCES Peers(Nickname)
);

CREATE TABLE P2P(
	ID BIGINT PRIMARY KEY,
	Checkslot BIGINT NOT NULL, 
	CheckingPeer VARCHAR NOT NULL,
	State Review_status NOT NULL,
	Time TIME NOT NULL,
	CONSTRAINT fk_p2p_check FOREIGN KEY (Checkslot) REFERENCES Checks(ID),
	CONSTRAINT fk_p2p_checking_peer FOREIGN KEY (CheckingPeer) REFERENCES Peers(Nickname),
	CONSTRAINT uk_p2p_uniq_check UNIQUE (Checkslot, State)
);


CREATE TABLE Verter(
	ID BIGINT PRIMARY KEY,
	Checkslot BIGINT NOT NULL,
	State Review_status NOT NULL,
	Time TIME NOT NULL,
	CONSTRAINT fk_verter_check FOREIGN KEY (Checkslot) REFERENCES Checks(ID),
	CONSTRAINT uk_verter_uniq_check UNIQUE (Checkslot, State)
);

CREATE TABLE Transferred_Points(
	ID BIGINT PRIMARY KEY,
	CheckingPeer VARCHAR NOT NULL,
	CheckedPeer VARCHAR NOT NULL,
	PointsAmount INTEGER NOT NULL,
	CONSTRAINT fk_transferred_points_checking_peer FOREIGN KEY (CheckingPeer) REFERENCES Peers(Nickname),
	CONSTRAINT fk_transferred_points_checked_peer FOREIGN KEY (CheckedPeer) REFERENCES Peers(Nickname)
);

CREATE TABLE Friends(
	ID BIGINT PRIMARY KEY,
	Peer1 VARCHAR NOT NULL,
	Peer2 VARCHAR NOT NULL,
	CONSTRAINT fk_friends_peer1 FOREIGN KEY (Peer1) REFERENCES Peers(Nickname),
	CONSTRAINT fk_friends_peer2 FOREIGN KEY (Peer2) REFERENCES Peers(Nickname)
);

CREATE TABLE Recommendations(
	ID BIGINT PRIMARY KEY,
	Peer VARCHAR NOT NULL,
	RecommendedPeer VARCHAR NOT NULL,
	CONSTRAINT fk_recommendations_peer FOREIGN KEY (Peer) REFERENCES Peers(Nickname),
	CONSTRAINT fk_recommendations_recommended_peer FOREIGN KEY (RecommendedPeer) REFERENCES Peers(Nickname)
);

CREATE TABLE XP(
	ID BIGINT PRIMARY KEY,
	Checkslot BIGINT NOT NULL,
	XPAmmount INTEGER NOT NULL,
	CONSTRAINT fk_xp_check FOREIGN KEY (Checkslot) REFERENCES Checks(ID)
);

CREATE TABLE Time_Tracking(
	ID BIGINT PRIMARY KEY,
	Peer VARCHAR NOT NULL,
	Date DATE NOT NULL,
	Time TIME NOT NULL,
	State INTEGER NOT NULL,
	CONSTRAINT fk_time_tracking_peer FOREIGN KEY (Peer) REFERENCES Peers(Nickname),
	CONSTRAINT ch_state check ( State in (1, 2) )
);


------------------------------------------------------------------------------------------------------
--                                                                                                  --
--                                                                                                  --
--                                         IMPORT & EXPORT                                          --
--                                                                                                  --
--                                                                                                  --
------------------------------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE import_from_csv(title TEXT, sep CHAR) AS $$
DECLARE
    command TEXT;
BEGIN
    command := format('COPY %s FROM ''C:\Users\Public\datasets\%s.csv'' DELIMITER ''%s'' CSV HEADER;', title, title, sep);
    EXECUTE command;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE export_to_csv(title TEXT, sep CHAR) AS $$
DECLARE
    command TEXT;
BEGIN
    command := format('COPY %s TO ''C:\Users\Public\datasets\export\%s.csv'' DELIMITER ''%s'' CSV HEADER;', title, title, sep);
    EXECUTE command;
END;
$$ LANGUAGE plpgsql;


------------------------------------------------------------------------------------------------------
--                                                                                                  --
--                                                                                                  --
--                                      ADD EXTRA CONSTRAINTS                                       --
--                                                                                                  --
--                                                                                                  --
------------------------------------------------------------------------------------------------------


CREATE OR REPLACE FUNCTION check_base_function()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) FROM Tasks WHERE ParentTask = 'None') = 0 THEN
        IF NEW.ParentTask != 'None' THEN
            RAISE EXCEPTION 'Base task not found';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER check_base_trigger
BEFORE INSERT OR UPDATE ON Tasks
FOR EACH ROW EXECUTE FUNCTION check_base_function();

CREATE OR REPLACE FUNCTION p2p_monitoring_function()
RETURNS TRIGGER AS $$
DECLARE
    col INTEGER;
BEGIN
    SELECT COUNT(ID) INTO col FROM P2P WHERE Checkslot = NEW.Checkslot;
    IF col >= 2 THEN
		RAISE EXCEPTION 'This check has already been completed';
	ELSIF col = 1 THEN
		IF NEW.State not in ('1', '2') THEN
			RAISE EXCEPTION 'This check has already started';
		END IF;
	ELSE
		IF NEW.State != '0' THEN
			RAISE EXCEPTION 'You need to start the check before giving the result';
		END IF;
	END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER p2p_monitoring_trigger
BEFORE INSERT OR UPDATE ON P2P
FOR EACH ROW EXECUTE FUNCTION p2p_monitoring_function();


CREATE OR REPLACE FUNCTION check_success(slot BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
    exists_flag BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM (SELECT * FROM Checks JOIN P2P ON checks.id = p2p.checkslot) 
		WHERE checkslot = slot AND State =  '1'
    ) INTO exists_flag;
    RETURN exists_flag;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_success_on_v(slot BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
    exists_flag BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM (SELECT * FROM Checks JOIN Verter ON Checks.id = Verter.checkslot) 
		WHERE checkslot = slot AND State =  '1'
    ) INTO exists_flag;
    RETURN exists_flag;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_verter_function()
RETURNS TRIGGER AS $$
DECLARE
    col INTEGER;
BEGIN
    SELECT COUNT(ID) INTO col FROM Verter WHERE Checkslot = NEW.Checkslot;
    IF col >= 2 AND col % 2 = 0 AND NEW.State != '0' THEN
		RAISE EXCEPTION 'This check has already been completed';
	ELSIF col % 2 != 0 THEN
		IF NEW.State not in ('1', '2') THEN
			RAISE EXCEPTION 'This check has already started';
		END IF;
	ELSE
		IF NEW.State != '0' THEN
			RAISE EXCEPTION 'You need to start the check before giving the result';
		END IF;
	END IF;
	IF check_success(NEW.Checkslot) = False THEN
		RAISE EXCEPTION 'This task is failed';
	END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER check_verter_trigger
BEFORE INSERT OR UPDATE ON Verter
FOR EACH ROW EXECUTE FUNCTION check_verter_function();

CREATE OR REPLACE FUNCTION get_max_xp(slot BIGINT)
RETURNS INTEGER AS $$
DECLARE
    max_xp INTEGER;
BEGIN
    SELECT MaxXP FROM (
        (SELECT * FROM XP JOIN Checks on XP.Checkslot = Checks.ID) as tmp
		JOIN Tasks
		ON tmp.Task = Tasks.Title
    ) as tmp2 WHERE tmp2.Checkslot = slot
	INTO max_xp;
    RETURN max_xp;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION check_points_function()
RETURNS TRIGGER AS $$
BEGIN
	IF check_success(NEW.Checkslot) = False THEN
		RAISE EXCEPTION 'This task is failed';
	ELSIF check_success_on_v(NEW.Checkslot) = False THEN
		RAISE EXCEPTION 'This task is failed on Verter';
	ELSIF NEW.XPAmmount > get_max_xp(NEW.Checkslot) THEN
		RAISE EXCEPTION 'Too much XP for this task!';
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER check_points_trigger
BEFORE INSERT OR UPDATE ON XP
FOR EACH ROW EXECUTE FUNCTION check_points_function();



------------------------------------------------------------------------------------------------------
--                                                                                                  --
--                                                                                                  --
--                                          FILL DATABASE                                           --
--                                                                                                  --
--                                                                                                  --
------------------------------------------------------------------------------------------------------

CALL import_from_csv('peers', ';');
CALL import_from_csv('tasks', ';');
CALL import_from_csv('checks', ';');
CALL import_from_csv('p2p', ';');
CALL import_from_csv('verter', ';');
CALL import_from_csv('xp', ';');
CALL import_from_csv('transferred_points', ';');
CALL import_from_csv('friends', ';');
CALL import_from_csv('recommendations', ';');
CALL import_from_csv('time_tracking', ';');

-- CALL export_to_csv('peers', ';');
-- CALL export_to_csv('tasks', ';');
-- CALL export_to_csv('checks', ';');
-- CALL export_to_csv('p2p', ';');
-- CALL export_to_csv('verter', ';');
-- CALL export_to_csv('xp', ';');
-- CALL export_to_csv('transferred_points', ';');
-- CALL export_to_csv('friends', ';');
-- CALL export_to_csv('recommendations', ';');
-- CALL export_to_csv('time_tracking', ';');

-- DROP TABLE peers CASCADE;
-- DROP TABLE checks CASCADE;
-- DROP TABLE friends CASCADE;
-- DROP TABLE p2p CASCADE;
-- DROP TABLE recommendations CASCADE;
-- DROP TABLE tasks CASCADE;
-- DROP TABLE timetracking CASCADE;
-- DROP TABLE transferredpoints CASCADE;
-- DROP TABLE verter CASCADE;
-- DROP TABLE xp CASCADE;