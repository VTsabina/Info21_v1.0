------------------------------------------------------------------------------------------------------
--                                            TASK 1                                                --
------------------------------------------------------------------------------------------------------

-- 1) Напиши функцию, возвращающую таблицу TransferredPoints в более человекочитаемом виде

-- Ник пира 1, ник пира 2, количество переданных пир-поинтов. \
-- Количество отрицательное, если пир 2 получил от пира 1 больше поинтов.

-- Пример вывода:
-- | Peer1  | Peer2  | PointsAmount |
-- |--------|--------|--------------|
-- | Aboba  | Amogus | 5            |
-- | Amogus | Sus    | -2           |
-- | Sus    | Aboba  | 0            |

CREATE OR REPLACE FUNCTION print_points()
RETURNS TABLE (
	"Peer1" VARCHAR,
	"Peer2" VARCHAR,
	"PointsAmount" INTEGER
) AS $$
BEGIN
	RETURN QUERY
	SELECT checkingpeer,
		   checkedpeer,
		   pointsamount
	FROM Transferred_Points;	   
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM print_points();


------------------------------------------------------------------------------------------------------
--                                            TASK 2                                                --
------------------------------------------------------------------------------------------------------

-- 2) Напиши функцию, которая возвращает таблицу вида: ник пользователя, название проверенного задания, кол-во полученного XP

-- В таблицу включи только задания, успешно прошедшие проверку (определять по таблице Checks). \
-- Одна задача может быть успешно выполнена несколько раз. В таком случае в таблицу включи все успешные проверки.

-- Пример вывода:
-- | Peer   | Task | XP  |
-- |--------|------|-----|
-- | Aboba  | C8   | 800 |
-- | Aboba  | CPP3 | 750 |
-- | Amogus | DO5  | 175 |
-- | Sus    | A4   | 325 |

CREATE OR REPLACE FUNCTION xp_per_task()
RETURNS TABLE (
	"Peer" VARCHAR,
	"Task" VARCHAR,
	"XP" INTEGER
) AS $$
BEGIN
	RETURN QUERY
	SELECT txp.peer, txp.task, txp.xpammount
	FROM (SELECT checks.id, checks.peer, checks.task, xp.xpammount
	FROM Checks
	JOIN XP
	ON Checks.ID = XP.Checkslot) as txp
	JOIN
	(SELECT p2p.Checkslot 
	FROM P2P
	LEFT JOIN Verter
	ON P2P.Checkslot = Verter.Checkslot
	WHERE P2P.State ='1' AND (Verter.State = '1' OR Verter.State IS NULL)) as sr
	ON txp.id = sr.Checkslot;
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM xp_per_task()


------------------------------------------------------------------------------------------------------
--                                            TASK 3                                                --
------------------------------------------------------------------------------------------------------

-- 3) Напиши функцию, определяющую пиров, которые не выходили из кампуса в течение всего дня

-- Параметры функции: день, например, 12.05.2022. \
-- Функция возвращает только список пиров.

CREATE OR REPLACE FUNCTION no_exits(day_date DATE)
RETURNS TABLE (
	"Peer" VARCHAR
)
AS $$
BEGIN
	RETURN QUERY
	SELECT Peer
	FROM Time_Tracking
	WHERE Date = day_date
	GROUP BY Peer, Date
	HAVING COUNT(*) <= 2;
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM no_exits('01/01/2024')

-- INSERT INTO TimeTracking VALUES ((SELECT COALESCE(MAX(ID), 0) + 1 FROM TimeTracking), 'gttngqbwgs', '01/01/2024', '11:34:46', '1');
-- INSERT INTO TimeTracking VALUES ((SELECT COALESCE(MAX(ID), 0) + 1 FROM TimeTracking), 'gttngqbwgs', '01/01/2024', '11:34:46', '2');
-- SELECT * FROM TimeTracking WHERE Date = '01/01/2024'


------------------------------------------------------------------------------------------------------
--                                            TASK 4                                                --
------------------------------------------------------------------------------------------------------

-- 4) Посчитай изменение в количестве пир-поинтов каждого пира по таблице TransferredPoints

-- Результат выведи отсортированным по изменению числа поинтов. \
-- Формат вывода: ник пира, изменение в количество пир-поинтов.

-- Пример вывода:
-- | Peer   | PointsChange |
-- |--------|--------------|
-- | Aboba  | 8            |
-- | Amogus | 1            |
-- | Sus    | -3           |

CREATE OR REPLACE FUNCTION point_change()
RETURNS TABLE (
	"Peer" VARCHAR,
	"PointsChange" BIGINT
) AS $$
BEGIN
	RETURN QUERY
	SELECT checkingpeer AS "Peer", 
		   SUM(pointsamount) AS "PointsChange"
	FROM Transferred_Points
	GROUP BY checkingpeer
	ORDER BY 2 DESC;
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM point_change();


------------------------------------------------------------------------------------------------------
--                                            TASK 5                                                --
------------------------------------------------------------------------------------------------------

-- 5) Посчитай изменение в количестве пир-поинтов каждого пира по таблице, 
-- возвращаемой [первой функцией из Part 3](#1-напиши-функцию-возвращающую-таблицу-transferredpoints-в-более-человекочитаемом-виде)

-- Результат выведи отсортированным по изменению числа поинтов. \
-- Формат вывода: ник пира, изменение в количество пир-поинтов.

-- Пример вывода:
-- | Peer   | PointsChange |
-- |--------|--------------|
-- | Aboba  | 8            |
-- | Amogus | 1            |
-- | Sus    | -3           |

CREATE OR REPLACE FUNCTION point_change_2()
RETURNS TABLE (
	"Peer" VARCHAR,
	"PointsChange" BIGINT
) AS $$
BEGIN
	RETURN QUERY
	SELECT "Peer1" AS "Peer", 
		   SUM("PointsAmount") AS "PointsChange"
	FROM print_points()
	GROUP BY "Peer1"
	ORDER BY 2 DESC;
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM point_change_2();


------------------------------------------------------------------------------------------------------
--                                            TASK 6                                                --
------------------------------------------------------------------------------------------------------

-- 6) Определи самое часто проверяемое задание за каждый день

-- При одинаковом количестве проверок каких-то заданий в определенный день выведи их все. \
-- Формат вывода: день, название задания.

-- Пример вывода:
-- | Day        | Task |
-- |------------|------|
-- | 12.05.2022 | A1   |
-- | 17.04.2022 | CPP3 |
-- | 23.12.2021 | C5   |

CREATE OR REPLACE FUNCTION max_checked_tasks()
RETURNS TABLE (
	"Day" DATE, --Change format from YYYY-MM-DD to DD-MM-YYYY
	"Task" VARCHAR
) AS $$
BEGIN
	RETURN QUERY
	SELECT date, task
	FROM (SELECT date, task,
	        COUNT(task) AS num,
	        MAX(COUNT(task)) OVER (PARTITION BY date) AS max_num
	    FROM Checks
	    GROUP BY date, task
	)
	WHERE num = max_num;
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM max_checked_tasks();


------------------------------------------------------------------------------------------------------
--                                            TASK 7                                                --
------------------------------------------------------------------------------------------------------

-- 7) Найди всех пиров, выполнивших весь заданный блок задач и дату завершения последнего задания

-- Параметры процедуры: название блока, например, «CPP». \
-- Результат выведи отсортированным по дате завершения. \
-- Формат вывода: ник пира, дата завершения блока (т. е. последнего выполненного задания из этого блока).

-- Пример вывода:
-- | Peer   | Day        |
-- |--------|------------|
-- | Sus    | 23.06.2022 |
-- | Amogus | 17.05.2022 |
-- | Aboba  | 12.05.2022 |

CREATE OR REPLACE FUNCTION get_successful_checks()
RETURNS TABLE (
	slot BIGINT
)
AS $$
BEGIN
RETURN QUERY
	SELECT p2p.Checkslot 
	FROM P2P
	LEFT JOIN Verter
	ON P2P.Checkslot = Verter.Checkslot
	WHERE P2P.State ='1' AND (Verter.State = '1' OR Verter.State IS NULL);
END;
$$LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_finished_block_strict(block VARCHAR) 
RETURNS TABLE (
	"Peer" VARCHAR,
	"Day" Date)
AS $$
BEGIN
	RETURN QUERY
	SELECT scss.peer, MAX(scss.date) AS Day
	FROM (SELECT * FROM Checks
		JOIN  get_successful_checks() as tmp
	ON Checks.id = tmp.slot) as scss
	JOIN 
	    (SELECT * FROM Tasks WHERE title ~ ('^' || block || '[0-9]+$')) as tm 
	ON scss.task = tm.title
	GROUP BY scss.peer
	HAVING 
	    COUNT(DISTINCT scss.task) = (SELECT COUNT(*) FROM (SELECT * FROM Tasks WHERE title ~ ('^' || block || '[0-9]+$')))
	ORDER BY Day;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_finished_block(block VARCHAR)
RETURNS TABLE(
	"Peer" VARCHAR, 
	"Day" DATE
) 
AS $$
BEGIN
	RETURN QUERY
	SELECT Checks.peer, Checks.date
	FROM Checks
	JOIN XP ON XP.Checkslot = Checks.ID
	WHERE task IN ( SELECT MAX(title) from Tasks
					WHERE title ~ ('^' || block || '[0-9]+$'))
	ORDER BY Checks.date;
END;
$$ LANGUAGE plpgsql;


-- SELECT * FROM check_finished_block('SQL');
-- SELECT * FROM check_finished_block_strict('SQL');

-- DROP FUNCTION check_finished_block(block VARCHAR);
-- DROP FUNCTION check_finished_block_strict(block VARCHAR);


------------------------------------------------------------------------------------------------------
--                                            TASK 8                                                --
------------------------------------------------------------------------------------------------------

-- 8) Определи, к какому пиру стоит идти на проверку каждому обучающемуся

-- Определять нужно, исходя из рекомендаций друзей пира, т. е. нужно найти пира, проверяться у которого рекомендует наибольшее число друзей. \
-- Формат вывода: ник пира, ник найденного проверяющего.

-- Пример вывода:
-- | Peer   | RecommendedPeer  |
-- |--------|-----------------|
-- | Aboba  | Sus             |
-- | Amogus | Aboba           |
-- | Sus    | Aboba           |

CREATE OR REPLACE FUNCTION get_recommended()
RETURNS TABLE (
	"Peer" VARCHAR,
	"RecommendedPeer" VARCHAR
)
AS $$
BEGIN
	RETURN QUERY
	WITH all_friends AS (
		SELECT peer1 as peer, peer2  as friend FROM friends
		UNION ALL
		SELECT peer2 as peer, peer1 as friend FROM friends),
	count_rec AS (
		SELECT p.nickname, recommendedpeer, COUNT(recommendedpeer)
		FROM peers p
		JOIN all_friends af ON p.nickname = af.peer
		JOIN recommendations r ON r.peer = af.friend
		WHERE p.nickname != r.recommendedpeer
		GROUP BY 1,2),
	max_rec AS (
		SELECT nickname, recommendedpeer, 
		ROW_NUMBER() OVER (PARTITION BY nickname ORDER BY count DESC) AS rn
		FROM count_rec)
	SELECT nickname, recommendedpeer FROM max_rec
	WHERE rn = 1;
END;
$$ LANGUAGE plpgsql;


-- INSERT INTO peers (nickname,  birthday)
-- VALUES ('sharaya', '21.06.2000'),
-- ('reteslah', '14.10.2000'),
-- ('garalaya', '02.01.1997'),
-- ('futooma', '11.08.1999'),
-- ('torontu', '03.05.2002'),
-- ('holorah', '15.04.1995');

-- INSERT INTO friends (id, peer1, peer2)
-- VALUES ((SELECT MAX(id) + 1 from friends),'sharaya', 'garalaya'),
-- ((SELECT MAX(id) + 2 from friends),'sharaya', 'reteslah'),
-- ((SELECT MAX(id) + 3 from friends),'sharaya', 'futooma'),
-- ((SELECT MAX(id) + 4 from friends),'torontu', 'garalaya'),
-- ((SELECT MAX(id) + 5 from friends),'torontu', 'sharaya'),
-- ((SELECT MAX(id) + 6 from friends),'torontu', 'reteslah'),
-- ((SELECT MAX(id) + 7 from friends),'torontu', 'holorah'),
-- ((SELECT MAX(id) + 8 from friends),'reteslah', 'futooma');


-- INSERT INTO recommendations (id, peer, recommendedpeer)
-- VALUES ((SELECT MAX(id) + 1 from recommendations),'sharaya', 'garalaya'),
-- ((SELECT MAX(id) + 2 from recommendations),'garalaya', 'sharaya'),
-- ((SELECT MAX(id) + 3 from recommendations),'sharaya', 'futooma'),
-- ((SELECT MAX(id) + 4 from recommendations),'torontu', 'garalaya'),
-- ((SELECT MAX(id) + 5 from recommendations),'garalaya', 'torontu'),
-- ((SELECT MAX(id) + 6 from recommendations),'reteslah', 'torontu'),
-- ((SELECT MAX(id) + 7 from recommendations),'holorah', 'torontu'),
-- ((SELECT MAX(id) + 8 from recommendations),'reteslah', 'futooma'),
-- ((SELECT MAX(id) + 9 from recommendations),'garalaya', 'futooma');

-- SELECT * FROM get_recommended();
-- DROP FUNCTION get_recommended();


------------------------------------------------------------------------------------------------------
--                                            TASK 9                                                --
------------------------------------------------------------------------------------------------------

-- 9) Определи процент пиров, которые:

-- - Приступили только к блоку 1;
-- - Приступили только к блоку 2;
-- - Приступили к обоим;
-- - Не приступили ни к одному.

-- Пир считается приступившим к блоку, если он проходил хоть одну проверку любого задания из этого блока (по таблице Checks).

-- Параметры процедуры: название блока 1, например, SQL, название блока 2, например, A. \
-- Формат вывода: процент приступивших только к первому блоку, процент приступивших только ко второму блоку, процент приступивших к обоим, процент не приступивших ни к одному.

-- Пример вывода:
-- | StartedBlock1 | StartedBlock2 | StartedBothBlocks | DidntStartAnyBlock |
-- |---------------|---------------|-------------------|--------------------|
-- | 20            | 20            | 5                 | 55                 |

CREATE OR REPLACE FUNCTION estimate_progress(block1 VARCHAR, block2 VARCHAR)
RETURNS TABLE (
	"StartedBlock1" INTEGER,
	"StartedBlock2" INTEGER,
	"StartedBothBlocks" INTEGER,
	"DidntStartAnyBlock" INTEGER
)
AS $$
BEGIN
	RETURN QUERY
	WITH first_block AS (
	SELECT peer FROM Checks
	JOIN Peers
	ON Peers.Nickname = Checks.peer
	WHERE task ~ ('^' || block1 || '[0-9]+$')),
	second_block AS (
	SELECT peer FROM Checks
	JOIN Peers
	ON Peers.Nickname = Checks.peer
	WHERE task ~ ('^' || block2 || '[0-9]+$')),
	both_blocks AS (
	SELECT peer FROM first_block
	INTERSECT
	SELECT peer FROM second_block),
	only_first AS (
	SELECT peer FROM first_block
	EXCEPT
	SELECT peer FROM second_block),
	only_second AS (
	SELECT peer FROM second_block
	EXCEPT
	SELECT peer FROM first_block),
	numbers AS ( SELECT 
	(SELECT COUNT(*) FROM only_first) AS first_num,
	(SELECT COUNT(*) FROM only_second) AS second_num,
	(SELECT COUNT(*) FROM both_blocks) AS both_num,
	(SELECT COUNT(*) FROM (SELECT DISTINCT peer FROM Checks)) AS all_checks
	)
	SELECT ROUND(numbers.first_num::numeric / numbers.all_checks * 100)::INT AS "StartedBlock1",
		   ROUND(numbers.second_num::numeric / numbers.all_checks * 100)::INT AS "StartedBlock2",
		   ROUND(numbers.both_num::numeric / numbers.all_checks * 100)::INT AS "StartedBothBlocks",
		   100 - (ROUND(numbers.first_num::numeric / numbers.all_checks * 100)::INT +
		   		  ROUND(numbers.second_num::numeric / numbers.all_checks * 100)::INT +
				  ROUND(numbers.both_num::numeric / numbers.all_checks * 100)::INT) AS "DidntStartAnyBlock"
	FROM numbers;
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM estimate_progress('C', 'CPP');
-- DROP FUNCTION estimate_progress(block1 VARCHAR, block2 VARCHAR);


------------------------------------------------------------------------------------------------------
--                                           TASK 10                                                --
------------------------------------------------------------------------------------------------------

-- 10) Определи процент пиров, которые когда-либо успешно проходили проверку в свой день рождения

-- Также определи процент пиров, которые хоть раз проваливали проверку в свой день рождения. \
-- Формат вывода: процент пиров, успешно прошедших проверку в день рождения, процент пиров, проваливших проверку в день рождения.

-- Пример вывода:
-- | SuccessfulChecks | UnsuccessfulChecks |
-- |------------------|--------------------|
-- | 60               | 40                 |

CREATE OR REPLACE FUNCTION birthday_luck()
RETURNS TABLE (
	"SuccessfulChecks" INTEGER,
	"UnsuccessfulChecks" INTEGER
)
AS $$
BEGIN
	RETURN QUERY
	WITH lucky AS(
	SELECT COUNT (*) FROM (SELECT DISTINCT Checks.peer
	FROM Checks
	JOIN P2P ON p2p.Checkslot = Checks.id
	JOIN Verter ON Verter.Checkslot = Checks.id
	JOIN Peers on Peers.nickname = Checks.peer
	WHERE EXTRACT(DAY FROM Peers.birthday) = EXTRACT(DAY FROM Checks.date)
	AND EXTRACT(MONTH FROM Peers.birthday) = EXTRACT(MONTH FROM Checks.date) AND P2P.State = '1' AND (Verter.state = '1' OR Verter.state IS NULL))),
	all_counts AS(
	SELECT COUNT (*) FROM (SELECT DISTINCT Checks.peer
	FROM Checks
	JOIN P2P ON p2p.Checkslot = Checks.id
	JOIN Verter ON Verter.Checkslot = Checks.id
	JOIN Peers on Peers.nickname = Checks.peer
	WHERE EXTRACT(DAY FROM Peers.birthday) = EXTRACT(DAY FROM Checks.date)
	AND EXTRACT(MONTH FROM Peers.birthday) = EXTRACT(MONTH FROM Checks.date) AND P2P.State != '0'))
	SELECT ROUND((SELECT count FROM lucky)::numeric / (SELECT count FROM all_counts) * 100)::INT AS "SuccessfulChecks",
	ROUND(100 - (SELECT count FROM lucky)::numeric / (SELECT count FROM all_counts) * 100)::INT AS "UnsuccessfulChecks";
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM birthday_luck();
-- DROP FUNCTION birthday_luck();


------------------------------------------------------------------------------------------------------
--                                           TASK 11                                                --
------------------------------------------------------------------------------------------------------

-- 11) Определи всех пиров, которые сдали заданные задания 1 и 2, но не сдали задание 3

-- Параметры процедуры: названия заданий 1, 2 и 3. \
-- Формат вывода: список пиров.

CREATE OR REPLACE FUNCTION no_third_task(task1 VARCHAR, task2 VARCHAR, task3 VARCHAR)
RETURNS TABLE (
	"Peer" VARCHAR
)
AS $$
BEGIN
	RETURN QUERY
	WITH frame AS(
	SELECT peer, task, p2p.state AS p2p, verter.state AS verter
	FROM Peers
	JOIN Checks
	ON Peers.Nickname = Checks.peer
	JOIN P2P
	ON Checks.ID = P2P.Checkslot
	JOIN Verter
	ON Checks.ID = Verter.Checkslot),
	success AS (
	SELECT peer
	FROM frame
	WHERE (task = task1 OR task = task2) AND p2p = '1' AND (verter = '1' OR verter IS NULL)),
	third AS (
	SELECT peer
	FROM frame
	WHERE task = task3 AND p2p = '1' AND (verter = '1' OR verter IS NULL))
	SELECT DISTINCT success.peer
	FROM success
	LEFT JOIN third
	ON success.peer = third.peer
	WHERE third.peer IS NULL;
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM no_third_task('AP1', 'AP2', 'AP3');
-- DROP FUNCTION no_third_task(task1 VARCHAR, task2 VARCHAR, task3 VARCHAR);


------------------------------------------------------------------------------------------------------
--                                           TASK 12                                                --
------------------------------------------------------------------------------------------------------

-- 12) Используя рекурсивное обобщенное табличное выражение, для каждой задачи выведи кол-во предшествующих ей задач

-- То есть сколько задач нужно выполнить, исходя из условий входа, чтобы получить доступ к текущей. \
-- Формат вывода: название задачи, количество предшествующих.

-- Пример вывода:
-- | Task | PrevCount |
-- |------|-----------|
-- | CPP3 | 7         |
-- | A1   | 9         |
-- | C5   | 1         |

CREATE OR REPLACE FUNCTION prev_tasks()
RETURNS TABLE (
	"Task" VARCHAR,
	"PrevCount" INTEGER
)
AS $$
BEGIN
	RETURN QUERY
	WITH RECURSIVE TaskDependencies AS (
    SELECT
        Title,
        0 AS DependenciesCount
    FROM Tasks
    WHERE ParentTask = 'None'

    UNION ALL

    SELECT
        t.Title,
        td.DependenciesCount + 1
    FROM Tasks t
    JOIN TaskDependencies td ON t.ParentTask = td.Title
)
SELECT
    t.Title,
    MAX(td.DependenciesCount) - 1 AS TotalDependencies
FROM Tasks t
LEFT JOIN TaskDependencies td ON t.Title = td.Title
GROUP BY t.Title;
	
END;
$$ LANGUAGE plpgsql;


-- SELECT * FROM prev_tasks();
-- DROP FUNCTION prev_tasks();


------------------------------------------------------------------------------------------------------
--                                           TASK 13                                                --
------------------------------------------------------------------------------------------------------

-- 13) Найди «удачные» для проверок дни. День считается «удачным», если в нем есть хотя бы *N* идущих подряд успешных проверки

-- Параметры процедуры: количество идущих подряд успешных проверок *N*. \
-- Временем проверки считай время начала P2P-этапа. \
-- Под идущими подряд успешными проверками подразумеваются успешные проверки, между которыми нет неуспешных. \
-- При этом кол-во опыта за каждую из этих проверок должно быть не меньше 80% от максимального. \
-- Формат вывода: список дней.

CREATE OR REPLACE FUNCTION success_for_lucky_days()
RETURNS TABLE (
	check_id BIGINT,
	check_date DATE
)
AS $$
BEGIN
	RETURN QUERY
	SELECT Checks.ID, Checks.date
	FROM XP
	JOIN Checks
	ON XP.Checkslot = Checks.ID
	JOIN Tasks
	ON Checks.task = Tasks.title
	WHERE XP.XPAmmount >= 0.80 * Tasks.MAXXP;

END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM success_for_lucky_days();

CREATE OR REPLACE FUNCTION lucky_days(N INTEGER)
RETURNS TABLE (
	"Days" Date
)
AS $$
BEGIN
	RETURN QUERY
	WITH all_checks AS(
	SELECT checkslot
	FROM P2P
	WHERE state = '0'
	)
	SELECT check_date FROM(
	SELECT check_date, COUNT(check_id) as count
	FROM all_checks 
	FULL OUTER JOIN success_for_lucky_days() AS s
	ON all_checks.Checkslot = s.check_id
	WHERE check_date IS NOT NULL
	GROUP BY check_date)
	WHERE count >= N
	ORDER BY check_date;
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM lucky_days(2);
-- DROP FUNCTION lucky_days(N INTEGER);


------------------------------------------------------------------------------------------------------
--                                           TASK 14                                                --
------------------------------------------------------------------------------------------------------

-- 14) Определи пира с наибольшим количеством XP

-- Формат вывода: ник пира, количество XP.

-- Пример вывода:
-- | Peer   | XP    |
-- |--------|-------|
-- | Amogus | 15000 |

CREATE OR REPLACE FUNCTION max_xp_peer()
RETURNS TABLE (
	"Peer" VARCHAR,
	"XP" BIGINT
)
AS $$
BEGIN
	RETURN QUERY
	SELECT nickname, SUM(XPAmmount) AS xp 
	FROM Peers
	JOIN Checks
	ON Peers.Nickname = Checks.peer
	JOIN XP
	ON Checks.ID = XP.Checkslot
	GROUP BY nickname
	ORDER BY 2 DESC
	LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM max_xp_peer();
-- DROP FUNCTION max_xp_peer();


------------------------------------------------------------------------------------------------------
--                                           TASK 15                                                --
------------------------------------------------------------------------------------------------------

-- 15) Определи пиров, приходивших раньше заданного времени не менее *N* раз за всё время

-- Параметры процедуры: время, количество раз *N*. \
-- Формат вывода: список пиров.

CREATE OR REPLACE FUNCTION before_time(timeline TIME, N INTEGER)
RETURNS TABLE (
	"Peer" VARCHAR
)
AS $$
BEGIN
	RETURN QUERY
	SELECT peer 
	FROM (SELECT peer, 
		  COUNT(time) 
		  FROM Time_Tracking
		  WHERE time < timeline
		  GROUP BY peer)
	WHERE count >= N;
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM before_time('23:36:04', 2);
-- DROP FUNCTION before_time(timeline TIME, N INTEGER);


------------------------------------------------------------------------------------------------------
--                                           TASK 16                                                --
------------------------------------------------------------------------------------------------------

-- 16) Определи пиров, выходивших за последние *N* дней из кампуса больше *M* раз

-- Параметры процедуры: количество дней *N*, количество раз *M*. \
-- Формат вывода: список пиров.

CREATE OR REPLACE FUNCTION more_exits(N INTEGER, M INTEGER)
RETURNS TABLE (
	"Peer" VARCHAR
)
AS $$
BEGIN
	RETURN QUERY
	SELECT peer 
	FROM (SELECT peer, 
		  COUNT(time) 
		  FROM Time_Tracking
		  WHERE date > current_date - N AND state = 2
		  GROUP BY peer)
	WHERE count >= M;
END;
$$ LANGUAGE plpgsql;

-- INSERT INTO time_tracking VALUES (20613, 'bgorlgxque', '17/05/2025', '23:25:42', 2),
-- 									(20614, 'bgorlgxque', '17/05/2025', '23:46:29', 1),
-- 									(20615, 'bgorlgxque', '17/05/2025', '23:52:48', 2),
-- 									(20616, 'esufrfmyqs', '18/05/2025', '03:41:24', 1),
-- 									(20617, 'esufrfmyqs', '18/05/2025', '14:18:24', 2),
-- 									(20618, 'pgxntxjwge', '19/05/2025', '04:55:34', 1),
-- 									(20619, 'pgxntxjwge', '19/05/2025', '15:48:44', 2);

-- SELECT * FROM more_exits(7, 1);
-- DROP FUNCTION more_exits(N INTEGER, M INTEGER);


------------------------------------------------------------------------------------------------------
--                                           TASK 17                                                --
------------------------------------------------------------------------------------------------------

-- 17) Определи для каждого месяца процент ранних входов

-- Для каждого месяца посчитай, сколько раз люди, родившиеся в этом месяце, приходили в кампус за всё время (будем называть это общим числом входов). \
-- Для каждого месяца посчитай, сколько раз люди, родившиеся в этом месяце, приходили в кампус раньше 12:00 за всё время (будем называть это числом ранних входов). \
-- Для каждого месяца посчитай процент ранних входов в кампус относительно общего числа входов. \
-- Формат вывода: месяц, процент ранних входов.

-- Пример вывода:
-- | Month    | EarlyEntries |  
-- | -------- | -------------- |
-- | January  | 15           |
-- | February | 35           |
-- | March    | 45           |

CREATE OR REPLACE FUNCTION early_entries() -- Ready but need to be ordered
RETURNS TABLE (
	"Month" VARCHAR,
	"EarlyEntries" INTEGER
)
AS $$
BEGIN
	RETURN QUERY
	WITH all_entries AS (
	SELECT id, time, TO_CHAR(Birthday, 'Month') as "month"
	FROM Peers ps
	RIGHT JOIN Time_Tracking tt on
	ps.Nickname = tt.Peer
	WHERE tt.State = '1'),
	early_entries AS(
	SELECT COUNT(*), "month"
	FROM all_entries
	WHERE time < '12:00:00'
	GROUP BY "month"
	),
	all_counted AS (
	SELECT COUNT(*) AS entries, "month"
	FROM all_entries 
	GROUP BY "month")
	SELECT all_counted."month"::VARCHAR,  ROUND(count::numeric / entries * 100)::INT AS "EarlyEntries"
	FROM all_counted
	JOIN early_entries 
	ON all_counted."month" = early_entries."month";
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM early_entries();
-- DROP FUNCTION early_entries();

