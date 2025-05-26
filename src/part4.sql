------------------------------------------------------------------------------------------------------
--                                                                                                  --
--                                                                                                  --
--                                         CREATE DATABASE                                          --
--                                                                                                  --
--                                                                                                  --
------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------
--                                            TABLES                                                --
------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS "TableName1";
CREATE TABLE "TableName1" (
	Col1 BIGINT,
	Col2 VARCHAR,
	Col3 TEXT
);

INSERT INTO "TableName1" VALUES (122345, 'SomeInfo', 'SomeDetails'),
							(54321, 'SomeMoreInfo', 'SomeMoreDetails'),
							(1225345, 'SomeOtherInfo', 'SomeOtherDetails');

-- SELECT * FROM "TableName1";
-- DROP TABLE "TableName1";

DROP TABLE IF EXISTS NotSuitableTable;
CREATE TABLE NotSuitableTable (
	Col1 BIGINT,
	Col2 VARCHAR,
	Col3 TEXT
);

INSERT INTO NotSuitableTable VALUES (122345, 'SomeInfo', 'SomeDetails'),
							(54321, 'SomeMoreInfo', 'SomeMoreDetails');
							
-- SELECT * FROM NotSuitableTable;
-- DROP TABLE NotSuitableTable;


DROP TABLE IF EXISTS "TableNameTwo";
CREATE TABLE "TableNameTwo" (
	Col1 BIGINT,
	Col2 VARCHAR,
	Col3 TEXT
);

INSERT INTO "TableNameTwo" VALUES (122345, 'SomeInfo', 'SomeDetails'),
							(54321, 'SomeMoreInfo', 'SomeMoreDetails'),
							(1225345, 'SomeOtherInfo', 'SomeOtherDetails');

-- SELECT * FROM "TableNameTwo";
-- DROP TABLE "TableNameTwo";


DROP TABLE IF EXISTS AnotherNotSuitableTable;
CREATE TABLE AnotherNotSuitableTable (
	Col1 BIGINT,
	Col2 VARCHAR,
	Col3 TEXT
);

INSERT INTO AnotherNotSuitableTable VALUES (122345, 'SomeInfo', 'SomeDetails'),
							(54321, 'SomeMoreInfo', 'SomeMoreDetails');
							
-- SELECT * FROM AnotherNotSuitableTable;
-- DROP TABLE AnotherNotSuitableTable;


------------------------------------------------------------------------------------------------------
--                                           FUNCTIONS                                              --
------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION Scalar_n_param(N INTEGER)
RETURNS INTEGER
AS $$
DECLARE 
	col INTEGER;
BEGIN
	SELECT INTO col COUNT(*) FROM NotSuitableTable;
	RETURN col + N;
END;
$$ LANGUAGE plpgsql;

-- SELECT Scalar_n_param(4);
-- DROP FUNCTION Scalar_n_param(N INTEGER);

CREATE OR REPLACE FUNCTION Scalar_noo_param()
RETURNS INTEGER
AS $$
DECLARE 
	col INTEGER;
BEGIN
	SELECT INTO col COUNT(*) FROM NotSuitableTable;
	RETURN col + 1;
END;
$$ LANGUAGE plpgsql;

-- SELECT Scalar_noo_param();
-- DROP FUNCTION Scalar_noo_param();


CREATE OR REPLACE FUNCTION Scalar_n_param_2(N INTEGER, NN INTEGER)
RETURNS INTEGER
AS $$
DECLARE 
	col INTEGER;
BEGIN
	SELECT INTO col COUNT(*) FROM NotSuitableTable;
	RETURN col + N - NN;
END;
$$ LANGUAGE plpgsql;

-- SELECT Scalar_n_param_2(4, 1);
-- DROP FUNCTION Scalar_n_param_2(N INTEGER, NN INTEGER);

CREATE OR REPLACE FUNCTION Table_param(N INTEGER)
RETURNS TABLE (
	Col1_1 BIGINT,
	Col1_2 BIGINT
)
AS $$
BEGIN
	RETURN QUERY
	SELECT nots.Col1, a.Col1
	FROM NotSuitableTable AS nots
	JOIN AnotherNotSuitableTable AS a
	ON nots.Col1 = a.Col1
	WHERE nots.Col1 > N;
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM Table_param(76543);
-- DROP FUNCTION Table_param(N INTEGER);

CREATE OR REPLACE FUNCTION Table_no_param()
RETURNS TABLE (
	Col1_1 BIGINT,
	Col1_2 BIGINT
)
AS $$
BEGIN
	RETURN QUERY
	SELECT nots.Col1, a.Col1
	FROM NotSuitableTable AS nots
	JOIN AnotherNotSuitableTable AS a
	ON nots.Col1 = a.Col1
	WHERE nots.Col1 > 76543;
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM Table_no_param();
-- DROP FUNCTION Table_no_param();


------------------------------------------------------------------------------------------------------
--                                           TRIGGERS                                               --
------------------------------------------------------------------------------------------------------

--DML-Trigger
CREATE FUNCTION DML_trigger_func()
RETURNS TRIGGER
AS $$
BEGIN
	IF NEW.Col1 < 0 THEN
		RAISE EXCEPTION 'Col1 must be >0!';
	END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- DROP FUNCTION DML_trigger_func();

CREATE TRIGGER DML_trigger 
BEFORE INSERT OR UPDATE ON NotSuitableTable
FOR EACH ROW EXECUTE FUNCTION DML_trigger_func();

-- DROP TRIGGER DML_trigger ON NotSuitableTable;

--DML-Trigger
CREATE FUNCTION DML_trigger_func_2()
RETURNS TRIGGER
AS $$
BEGIN
	IF NEW.Col1 < 0 THEN
		RAISE EXCEPTION 'Col1 must be >0!';
	END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- DROP FUNCTION DML_trigger_func_2();

CREATE TRIGGER DML_trigger_2
BEFORE INSERT OR UPDATE ON AnotherNotSuitableTable
FOR EACH ROW EXECUTE FUNCTION DML_trigger_func_2();

-- DROP TRIGGER DML_trigger ON NotSuitableTable;

-- DDL-Trigger
CREATE OR REPLACE FUNCTION ddl_drop_trigger()
RETURNS event_trigger AS $$
BEGIN
    RAISE NOTICE 'DROP NOTICED: %', tg_tag;
END;
$$ LANGUAGE plpgsql;

-- DROP FUNCTION ddl_drop_trigger();

CREATE EVENT TRIGGER trg_ddl_drop
ON sql_drop
EXECUTE FUNCTION ddl_drop_trigger();

-- DROP EVENT TRIGGER trg_ddl_drop;


------------------------------------------------------------------------------------------------------
--                                                                                                  --
--                                                                                                  --
--                                              TASK                                                --
--                                                                                                  --
--                                                                                                  --
------------------------------------------------------------------------------------------------------

-- Для данной части задания тебе нужно создать отдельную базу данных, в которую занести таблицы, 
-- функции, процедуры и триггеры, необходимые для тестирования процедур.


------------------------------------------------------------------------------------------------------
--                                            TASK 1                                                --
------------------------------------------------------------------------------------------------------

-- 1) Создай хранимую процедуру, которая, не уничтожая базу данных, 
-- уничтожает все те таблицы текущей базы данных, 
-- имена которых начинаются с фразы 'TableName'.

-- SELECT * FROM pg_tables WHERE tablename LIKE 'TableName%'
-- SELECT * FROM pg_tables

CREATE OR REPLACE PROCEDURE delete_pattern() AS $$
DECLARE
	rec RECORD;
BEGIN
	FOR rec in (SELECT tablename FROM pg_tables WHERE tablename LIKE 'TableName%')
	LOOP
		EXECUTE format('DROP TABLE IF EXISTS %I CASCADE', rec.tablename);
	END LOOP;
END;
$$ LANGUAGE plpgsql;

-- CALL delete_pattern();
-- DROP PROCEDURE delete_pattern();


------------------------------------------------------------------------------------------------------
--                                            TASK 2                                                --
------------------------------------------------------------------------------------------------------

-- 2) Создай хранимую процедуру с выходным параметром, которая выводит список имен и параметров 
-- всех скалярных SQL-функций пользователя в текущей базе данных. 
-- Имена функций без параметров выводить не нужно. 
-- Имена и список параметров должны выводиться в одну строку. 
-- Выходной параметр возвращает количество найденных функций.

-- SELECT * FROM pg_proc WHERE proname LIKE 'scalar%';
-- SELECT * FROM pg_namespace;

CREATE OR REPLACE PROCEDURE list_scalar_functions()
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
    result TEXT := '';
    separator TEXT := '';
BEGIN
    FOR rec IN
        SELECT 
            n.nspname AS schema_name,
            p.proname AS function_name,
            pg_get_function_arguments(p.oid) AS arguments,
            pg_get_function_result(p.oid) AS return_type
        FROM 
            pg_proc p
        JOIN 
            pg_namespace n ON p.pronamespace = n.oid
        WHERE 
            n.nspname NOT IN ('pg_catalog', 'information_schema')
            AND p.prokind = 'f'
            AND pg_get_function_arguments(p.oid) <> ''
            AND pg_get_function_result(p.oid) NOT LIKE 'SETOF %'
            AND pg_get_function_result(p.oid) NOT LIKE 'TABLE(%'
    LOOP
        result := result || separator || format('%s.%s(%s)', rec.schema_name, rec.function_name, rec.arguments);
        separator := ', ';
    END LOOP;

    RAISE NOTICE '%', result;
END;
$$;


-- CALL list_scalar_functions();
-- DROP PROCEDURE list_scalar_functions();
	

------------------------------------------------------------------------------------------------------
--                                            TASK 3                                                --
------------------------------------------------------------------------------------------------------

-- 3) Создай хранимую процедуру с выходным параметром, которая уничтожает все SQL DML триггеры в текущей базе данных.
-- Выходной параметр возвращает количество уничтоженных триггеров.

-- SELECT * FROM pg_trigger;

CREATE OR REPLACE PROCEDURE destroy_triggers(OUT deleted_count INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    rec RECORD;
    count INTEGER := 0;
BEGIN
    FOR rec IN 
        SELECT tgname, relname 
        FROM pg_trigger t 
        JOIN pg_class c ON t.tgrelid = c.oid 
        WHERE NOT t.tgisinternal
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I;', rec.tgname, rec.relname);
        count := count + 1;
    END LOOP;
    deleted_count := count;
END;
$$;

-- DO $$
-- DECLARE
--     deleted_count INTEGER; 
-- BEGIN
--     CALL destroy_triggers(deleted_count);
--     RAISE NOTICE 'OUT: %', deleted_count;
-- END;
-- $$ LANGUAGE plpgsql;

-- DROP PROCEDURE destroy_triggers(OUT deleted_count INTEGER);


------------------------------------------------------------------------------------------------------
--                                            TASK 4                                                --
------------------------------------------------------------------------------------------------------

-- 4) Создай хранимую процедуру с входным параметром, которая выводит имена и описания типа объектов 
-- (только хранимых процедур и скалярных функций), в тексте которых на языке SQL встречается строка, 
-- задаваемая параметром процедуры.

-- SELECT * FROM pg_proc;

CREATE OR REPLACE PROCEDURE descriptions(pattern TEXT)
AS $$
DECLARE
	rec RECORD;
	func_def TEXT;
BEGIN
	FOR rec IN
		SELECT proname, obj_description(p.oid), p.oid
		FROM pg_proc p
		JOIN pg_namespace n ON p.pronamespace = n.oid
		WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
		  AND (p.prokind = 'f' OR p.prokind = 'p')
		  AND ((pg_get_function_result(p.oid) NOT LIKE 'SETOF %'
          AND pg_get_function_result(p.oid) NOT LIKE 'TABLE(%'
		  AND pg_get_function_result(p.oid) NOT LIKE '%trigger%')
		  OR pg_get_function_result(p.oid) IS NULL)
	LOOP
		SELECT pg_get_functiondef(rec.oid) INTO func_def;
		IF func_def LIKE '%' || pattern || '%' THEN
			RAISE NOTICE 'Name: %, Description: %', rec.proname, obj_description(rec.oid);
		END IF;
	END LOOP;
END;
$$ LANGUAGE plpgsql;

-- CALL descriptions('CREATE');
-- DROP PROCEDURE descriptions(pattern TEXT);

