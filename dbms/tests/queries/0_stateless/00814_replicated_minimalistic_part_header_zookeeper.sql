DROP TABLE IF EXISTS test.part_header_r1;
DROP TABLE IF EXISTS test.part_header_r2;

CREATE TABLE test.part_header_r1(x UInt32, y UInt32)
    ENGINE ReplicatedMergeTree('/clickhouse/tables/test/part_header', '1') ORDER BY x
    SETTINGS use_minimalistic_part_header_in_zookeeper = 0,
             old_parts_lifetime = 1,
             cleanup_delay_period = 0,
             cleanup_delay_period_random_add = 0;
CREATE TABLE test.part_header_r2(x UInt32, y UInt32)
    ENGINE ReplicatedMergeTree('/clickhouse/tables/test/part_header', '2') ORDER BY x
    SETTINGS use_minimalistic_part_header_in_zookeeper = 1,
             old_parts_lifetime = 1,
             cleanup_delay_period = 0,
             cleanup_delay_period_random_add = 0;

SELECT '*** Test fetches ***';
INSERT INTO test.part_header_r1 VALUES (1, 1);
INSERT INTO test.part_header_r2 VALUES (2, 2);
SYSTEM SYNC REPLICA test.part_header_r1;
SYSTEM SYNC REPLICA test.part_header_r2;
SELECT '*** replica 1 ***';
SELECT x, y FROM test.part_header_r1 ORDER BY x;
SELECT '*** replica 2 ***';
SELECT x, y FROM test.part_header_r2 ORDER BY x;

SELECT '*** Test merges ***';
OPTIMIZE TABLE test.part_header_r1;
SYSTEM SYNC REPLICA test.part_header_r2;
SELECT '*** replica 1 ***';
SELECT _part, x FROM test.part_header_r1 ORDER BY x;
SELECT '*** replica 2 ***';
SELECT _part, x FROM test.part_header_r2 ORDER BY x;

SELECT sleep(2) FORMAT Null;

SELECT '*** Test part removal ***';
SELECT '*** replica 1 ***';
SELECT name FROM system.parts WHERE database = 'test' AND table = 'part_header_r1';
SELECT name FROM system.zookeeper WHERE path = '/clickhouse/tables/test/part_header/replicas/1/parts';
SELECT '*** replica 2 ***';
SELECT name FROM system.parts WHERE database = 'test' AND table = 'part_header_r2';
SELECT name FROM system.zookeeper WHERE path = '/clickhouse/tables/test/part_header/replicas/1/parts';

SELECT '*** Test ALTER ***';
ALTER TABLE test.part_header_r1 MODIFY COLUMN y String;
SELECT '*** replica 1 ***';
SELECT x, length(y) FROM test.part_header_r1 ORDER BY x;
SELECT '*** replica 2 ***';
SELECT x, length(y) FROM test.part_header_r2 ORDER BY x;

SELECT '*** Test CLEAR COLUMN ***';
SET replication_alter_partitions_sync = 2;
ALTER TABLE test.part_header_r1 CLEAR COLUMN y IN PARTITION tuple();
SELECT '*** replica 1 ***';
SELECT x, length(y) FROM test.part_header_r1 ORDER BY x;
SELECT '*** replica 2 ***';
SELECT x, length(y) FROM test.part_header_r2 ORDER BY x;

DROP TABLE test.part_header_r1;
DROP TABLE test.part_header_r2;
