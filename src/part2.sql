------------------------------------------------------------------------------------------------------
--                                            TASK 1                                                --
------------------------------------------------------------------------------------------------------

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

------------------------------------------------------------------------------------------------------
--                                            TASK 2                                                --
------------------------------------------------------------------------------------------------------

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
    ORDER BY p.Time DESC
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

-- CREATE OR REPLACE FUNCTION update_transferred_points()
-- RETURNS TRIGGER AS $$
-- BEGIN
--     -- Only act on 'Start' records
--     IF NEW.State = 'Start'::Review_status THEN
--         -- Check if record already exists
--         IF EXISTS (
--             SELECT 1 FROM TransferredPoints 
--             WHERE CheckingPeer = NEW.CheckingPeer 
--             AND CheckedPeer = (
--                 SELECT Peer FROM Checks WHERE ID = NEW.Checkslot
--             )
--         ) THEN
--             -- Update existing record
--             UPDATE TransferredPoints
--             SET PointsAmount = PointsAmount + 1
--             WHERE CheckingPeer = NEW.CheckingPeer
--             AND CheckedPeer = (SELECT Peer FROM Checks WHERE ID = NEW.Checkslot);
--         ELSE
--             -- Insert new record
--             INSERT INTO TransferredPoints (CheckingPeer, CheckedPeer, PointsAmount)
--             SELECT NEW.CheckingPeer, c.Peer, 1
--             FROM Checks c
--             WHERE c.ID = NEW.Checkslot;
--         END IF;
--     END IF;
    
--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE TRIGGER trg_p2p_transferred_points
-- AFTER INSERT ON P2P
-- FOR EACH ROW
-- EXECUTE FUNCTION update_transferred_points();

-- -- DROP TRIGGER check_time_trigger ON timetracking

-- CALL p2p_check ('qeunlyykzb', 'mvazvelhwy', 'C5', '1', '06:39:35')

-- CALL add_verter_check ('qeunlyykzb', 'C5', '1', '06:47:35');

-- SELECT * FROM p2p

-- DROP PROCEDURE p2p_check(
--     checked_peer VARCHAR,
--     checking_peer VARCHAR,
--     task_name VARCHAR,
--     p2p_status VARCHAR,
--     check_time DATE
-- )

-- SELECT * FROM P2P
-- LEFT JOIN Verter
-- ON P2P.Checkslot = Verter.Checkslot
-- WHERE P2P.State = '1' AND P2P.Checkslot = 11861
