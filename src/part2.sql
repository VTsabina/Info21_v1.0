------------------------------------------------------------------------------------------------------
--                                            TASK 1                                                --
------------------------------------------------------------------------------------------------------

-- 1) Напиши процедуру добавления P2P-проверки

-- Параметры: ник проверяемого, ник проверяющего, название задания, [статус P2P-проверки](#статус-проверки), время. \
-- Если задан статус «начало», добавь запись в таблицу Checks (в качестве даты используй сегодняшнюю). \
-- Добавь запись в таблицу P2P. \
-- Если задан статус «начало», в качестве проверки укажи только что добавленную запись, если же нет, то укажи проверку с незавершенным P2P-этапом.

CREATE OR REPLACE PROCEDURE p2p_check(
    checked_peer VARCHAR,
    checking_peer VARCHAR,
    task_name VARCHAR,
    p2p_status VARCHAR,
    check_time TIME
)
AS $$
DECLARE
    new_check_id INTEGER;
    existing_check_id INTEGER;
	new_p2p_id INTEGER;
	new_id INTEGER;
BEGIN
    -- Validate input parameters
    IF p2p_status NOT IN ('0', '1', '2') THEN
        RAISE EXCEPTION 'Invalid P2P status: %. Must be 0 - Start, 1 - Success or 2 - Failure', p2p_status;
    END IF;
    
    -- For 'Start' status - create new check
    IF p2p_status = '0' THEN
        -- Insert into Checks table
		SELECT COALESCE(MAX(ID), 0) + 1 INTO new_id FROM Checks;
        INSERT INTO Checks (id, Peer, Task, Date)
        VALUES (new_id, checked_peer, task_name, CURRENT_DATE)
        RETURNING ID INTO new_check_id;
        
        -- Insert into P2P table
		SELECT COALESCE(MAX(ID), 0) + 1 INTO new_p2p_id FROM P2P;
        INSERT INTO P2P (id, Checkslot, CheckingPeer, State, Time)
        VALUES (new_p2p_id, new_check_id, checking_peer, '0'::Review_status, check_time);
    ELSE
        -- Find the latest unfinished P2P check for this peer and task
        SELECT c.ID INTO existing_check_id
        FROM Checks c
        JOIN P2P p ON c.ID = p.Checkslot
        WHERE c.Peer = checked_peer
          AND c.Task = task_name
          AND p.CheckingPeer = checking_peer
          AND p.State = '0'::Review_status
        ORDER BY p.Time DESC
        LIMIT 1;
        
        IF existing_check_id IS NULL THEN
            RAISE EXCEPTION 'No unfinished P2P check found for peer %, task % with checking peer %', 
                checked_peer, task_name, checking_peer;
        END IF;
        
        -- Insert completion record into P2P
		SELECT COALESCE(MAX(ID), 0) + 1 INTO new_id FROM P2P;
        INSERT INTO P2P (id, Checkslot, CheckingPeer, State, Time)
        VALUES (new_id, existing_check_id, checking_peer, 
               CASE WHEN p2p_status = '1' THEN '1'::Review_status 
                    ELSE '2'::Review_status END, 
               check_time);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- CALL p2p_check ('qeunlyykzb', 'mvazvelhwy', 'C5', '0', '06:39:35');
-- CALL p2p_check ('qeunlyykzb', 'mvazvelhwy', 'C5', '1', '06:39:35');

-- DROP PROCEDURE p2p_check(
--     checked_peer VARCHAR,
--     checking_peer VARCHAR,
--     task_name VARCHAR,
--     p2p_status VARCHAR,
--     check_time DATE
-- );


------------------------------------------------------------------------------------------------------
--                                            TASK 2                                                --
------------------------------------------------------------------------------------------------------

-- 2) Напиши процедуру добавления проверки Verter'ом

-- Параметры: ник проверяемого, название задания, [статус проверки Verter'ом](#статус-проверки), время. \
-- Добавь запись в таблицу Verter (в качестве проверки укажи проверку соответствующего задания с самым поздним (по времени) успешным P2P-этапом).

CREATE OR REPLACE PROCEDURE add_verter_check(
    checked_peer VARCHAR,
    task_name VARCHAR,
    verter_status VARCHAR,
    check_time TIME
)
AS $$
DECLARE
    successful_check_id INTEGER;
	new_id INTEGER;
BEGIN
    -- Validate input parameters
    IF verter_status NOT IN ('0', '1', '2') THEN
        RAISE EXCEPTION 'Invalid Verter status: %. Must be 0 - Start, 1 - Success or 2 - Failure', verter_status;
    END IF;
    
    -- Find the latest successful P2P check for this peer and task
    SELECT c.ID INTO successful_check_id
    FROM Checks c
    JOIN P2P p ON c.ID = p.Checkslot
    WHERE c.Peer = checked_peer
      AND c.Task = task_name
      AND p.State = '1'::Review_status
      AND NOT EXISTS (
          SELECT 1 FROM P2P p2 
          WHERE p2.Checkslot = p.Checkslot 
          AND p2.State = '2'::Review_status
      )
    ORDER BY c.Date DESC
    LIMIT 1;
    
    IF successful_check_id IS NULL THEN
        RAISE EXCEPTION 'No successful P2P check found for peer % and task %', checked_peer, task_name;
    END IF;
    
    -- Insert into Verter table
	SELECT COALESCE(MAX(ID), 0) + 1 INTO new_id FROM Verter;
    INSERT INTO Verter (id, Checkslot, State, Time)
    VALUES (new_id, successful_check_id, 
           CASE WHEN verter_status = '0' THEN '0'::Review_status
                WHEN verter_status = '1' THEN '1'::Review_status
                ELSE '2'::Review_status END,
           check_time);
END;
$$ LANGUAGE plpgsql;

-- CALL add_verter_check ('qeunlyykzb', 'C5', '0', '06:47:35');
-- CALL add_verter_check ('qeunlyykzb', 'C5', '1', '06:47:35');


-- DROP PROCEDURE add_verter_check(
--     checked_peer VARCHAR,
--     task_name VARCHAR,
--     verter_status VARCHAR,
--     check_time TIME
-- );

------------------------------------------------------------------------------------------------------
--                                            TASK 3                                                --
------------------------------------------------------------------------------------------------------

-- 3) Напиши триггер: после добавления записи со статусом «начало» в таблицу P2P изменяется соответствующая запись в таблице TransferredPoints

CREATE OR REPLACE FUNCTION update_transferred_points()
RETURNS TRIGGER AS $$
DECLARE 
	new_id INTEGER;
BEGIN
    -- Only act on 'Start' records
    IF NEW.State = '0'::Review_status THEN
        -- Check if record already exists
        IF EXISTS (
            SELECT 1 FROM Transferred_Points 
            WHERE CheckingPeer = NEW.CheckingPeer 
            AND CheckedPeer = (
                SELECT Peer FROM Checks WHERE ID = NEW.Checkslot
            )
        ) THEN
            -- Update existing record
            UPDATE Transferred_Points
            SET PointsAmount = PointsAmount + 1
            WHERE CheckingPeer = NEW.CheckingPeer
            AND CheckedPeer = (SELECT Peer FROM Checks WHERE ID = NEW.Checkslot);
        ELSE
            -- Insert new record
			SELECT COALESCE(MAX(ID), 0) + 1 INTO new_id FROM Transferred_Points;
            INSERT INTO Transferred_Points (id, CheckingPeer, CheckedPeer, PointsAmount)
            SELECT new_id, NEW.CheckingPeer, c.Peer, 1
            FROM Checks c
            WHERE c.ID = NEW.Checkslot;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_p2p_transferred_points
AFTER INSERT ON P2P
FOR EACH ROW
EXECUTE FUNCTION update_transferred_points();

-- CALL p2p_check ('iosfiypdje', 'mvazvelhwy', 'A3', '0', '17:23:30');
-- CALL p2p_check ('iosfiypdje', 'mvazvelhwy', 'A3', '1', '17:23:30');

-- CALL p2p_check ('wsiwgwornx', 'prbedzugjq', 'A3', '0', '17:23:30');
-- CALL p2p_check ('wsiwgwornx', 'prbedzugjq', 'A3', '1', '17:23:30');

-- CALL p2p_check ('gdlzzcthpd', 'thyrtwnsgs', 'A3', '0', '17:23:30');
-- CALL p2p_check ('gdlzzcthpd', 'thyrtwnsgs', 'A3', '1', '17:23:30');

-- SELECT * FROM transferred_points
-- ORDER BY 1;

-- DROP TRIGGER trg_p2p_transferred_points ON P2P;


------------------------------------------------------------------------------------------------------
--                                            TASK 4                                                --
------------------------------------------------------------------------------------------------------

-- 4) Напиши триггер: перед добавлением записи в таблицу XP проверяется корректность добавляемой записи

-- Запись считается корректной, если:
-- - Количество XP не превышает максимальное доступное для проверяемой задачи.
-- - Поле Check ссылается на успешную проверку.
-- Если запись не прошла проверку, не добавляй её в таблицу.

CREATE OR REPLACE FUNCTION validate_xp()
RETURNS TRIGGER AS $$
DECLARE
    max_xp INTEGER;
    check_status VARCHAR;
BEGIN
    -- Get max XP for the task and check if the check was successful
    SELECT t.MaxXP, 
           CASE WHEN EXISTS (
               SELECT 1 FROM P2P p 
               WHERE p.Checkslot = NEW.Checkslot 
               AND p.State = '1'::Review_status
               AND NOT EXISTS (
                   SELECT 1 FROM P2P p2 
                   WHERE p2.Checkslot = p.Checkslot 
                   AND p2.State = '2'::Review_status
               )
               AND NOT EXISTS (
                   SELECT 1 FROM Verter v 
                   WHERE v.Checkslot = p.Checkslot 
                   AND v.State = '2'::Review_status
               )
           ) AND NOT EXISTS (
               SELECT 1 FROM Verter v 
               WHERE v.Checkslot = NEW.Checkslot 
               AND v.State = '2'::Review_status
           ) THEN '1' ELSE '2' END
    INTO max_xp, check_status
    FROM Checks c
    JOIN Tasks t ON c.Task = t.Title
    WHERE c.ID = NEW.Checkslot;
    
    -- Validate XP amount
    IF NEW.XPAmmount > max_xp THEN
        RAISE EXCEPTION 'XP amount % exceeds maximum % for this task', NEW.XPAmmount, max_xp;
    END IF;
    
    -- Validate check status
    IF check_status != '1' THEN
        RAISE EXCEPTION 'Cannot add XP for unsuccessful check (ID: %)', NEW.Checkslot;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_xp
BEFORE INSERT ON XP
FOR EACH ROW
EXECUTE FUNCTION validate_xp();

-- INSERT INTO XP VALUES(2451, 13932, 400); -- Too much XP
-- CALL p2p_check ('dnafdfodeq', 'wbbmjueeye', 'A1', '0', '18:23:30');
-- CALL p2p_check ('dnafdfodeq', 'wbbmjueeye', 'A1', '2', '20:23:30');
-- INSERT INTO XP VALUES(2452, 13933, 400); -- Failed check